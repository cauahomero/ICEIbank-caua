# Sobe o ambiente do ICEIBank: RabbitMQ (Docker), 3 agencias, monitor de alertas e frontend.
# Cada processo abre na sua propria janela, para dar para ver os logs (e derrubar uma agencia).
#
# Exemplos:
#   .\iniciar.cmd                     sobe tudo
#   .\iniciar.cmd -Limpar             apaga os logs de eventos antes (bom para os experimentos)
#   .\iniciar.cmd -Agencias 1         sobe so a agencia 1 (ex.: depois de derruba-la no teste de resiliencia)
#   .\iniciar.cmd -CdbSegundos 20     CDB rende a cada 20s em vez de 5 min
#   .\iniciar.cmd -Build              forca recompilar o jar
param(
    [int[]]$Agencias = @(0, 1, 2),
    [switch]$Limpar,
    [switch]$Build,
    [int]$CdbSegundos = 0,
    [switch]$SemFrontend,
    [switch]$SemMonitor
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$pastaAgencia = Join-Path $raiz 'agencia-java'
$pastaFrontend = Join-Path $raiz 'frontend'
$jar = Join-Path $pastaAgencia 'target\agencia-1.0.0.jar'
$PORTA_BASE = 4006
$somenteAlgumas = $PSBoundParameters.ContainsKey('Agencias')

function Passo($texto) { Write-Host "`n==> $texto" -ForegroundColor Cyan }

function PortaAberta($porta) {
    $cliente = New-Object System.Net.Sockets.TcpClient
    try { $cliente.Connect('localhost', $porta); return $true } catch { return $false } finally { $cliente.Close() }
}

function EsperarPorta($porta, $segundos, $nome) {
    for ($i = 0; $i -lt $segundos; $i++) {
        if (PortaAberta $porta) { return }
        Start-Sleep -Seconds 1
    }
    throw "$nome nao respondeu na porta $porta depois de $segundos s."
}

function NovaJanela($titulo, $pasta, $comando) {
    $script = "`$host.UI.RawUI.WindowTitle = '$titulo'; chcp 65001 > `$null; [Console]::OutputEncoding = [Text.Encoding]::UTF8; $comando"
    Start-Process powershell -WorkingDirectory $pasta -ArgumentList '-NoExit', '-NoProfile', '-Command', $script | Out-Null
}

# 1. RabbitMQ: so sobe o Docker se nao houver RABBITMQ_URL apontando para outro lugar (ex.: CloudAMQP)
if ($env:RABBITMQ_URL -and $env:RABBITMQ_URL -notmatch 'localhost|127\.0\.0\.1') {
    Passo "Usando o RabbitMQ de RABBITMQ_URL (nao vou subir o Docker)"
} else {
    Passo "Subindo o RabbitMQ no Docker"
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    $dockerExe = if ($docker) { $docker.Source } else { 'C:\Program Files\Docker\Docker\resources\bin\docker.exe' }
    if (-not (Test-Path $dockerExe)) { throw "Docker nao encontrado. Instale o Docker Desktop ou defina RABBITMQ_URL." }
    & $dockerExe compose -f (Join-Path $raiz 'docker-compose.yml') up -d
    if ($LASTEXITCODE -ne 0) { throw "docker compose falhou. O Docker Desktop esta aberto (Engine running)?" }
    EsperarPorta 5672 60 'RabbitMQ'
    Write-Host "RabbitMQ no ar. Painel: http://localhost:15672 (iceibank / iceibank)"
}

# 2. Para as agencias que ja estiverem rodando nas portas que vamos usar
Passo "Encerrando agencias antigas nas portas usadas"
foreach ($id in $Agencias) {
    $conexoes = Get-NetTCPConnection -LocalPort ($PORTA_BASE + $id) -State Listen -ErrorAction SilentlyContinue
    foreach ($c in $conexoes) {
        Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
        Write-Host "Agencia $id (porta $($PORTA_BASE + $id)) antiga encerrada."
    }
}

# 3. Compila se o jar nao existe, se pediram, ou se algum fonte e mais novo que ele
$fonteMaisNovo = Get-ChildItem (Join-Path $pastaAgencia 'src'), (Join-Path $pastaAgencia 'pom.xml') -Recurse -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($Build -or -not (Test-Path $jar) -or $fonteMaisNovo.LastWriteTime -gt (Get-Item $jar).LastWriteTime) {
    Passo "Compilando o backend (mvn package)"
    Push-Location $pastaAgencia
    try {
        mvn -q -DskipTests package
        if ($LASTEXITCODE -ne 0) { throw "mvn package falhou." }
    } finally { Pop-Location }
}

if ($Limpar) {
    Passo "Apagando os logs de eventos (agencia-java\data)"
    Remove-Item (Join-Path $pastaAgencia 'data\*.jsonl') -ErrorAction SilentlyContinue
}

# 4. Agencias
Passo "Subindo as agencias $($Agencias -join ', ')"
$argsCdb = if ($CdbSegundos -gt 0) { " --cdb.intervalo-ms=$($CdbSegundos * 1000)" } else { '' }
foreach ($id in $Agencias) {
    NovaJanela "Agencia $id (porta $($PORTA_BASE + $id))" $pastaAgencia `
        "`$env:AGENCIA_ID = '$id'; java -Dsun.stdout.encoding=UTF-8 -jar target\agencia-1.0.0.jar$argsCdb"
}

# 5. Monitor de alertas (funcionalidade adicional) - so na subida completa
if (-not $SemMonitor -and -not $somenteAlgumas) {
    Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" |
        Where-Object { $_.CommandLine -like '*MonitorAlertas*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    NovaJanela "Monitor de alertas" $pastaAgencia `
        "java -Dsun.stdout.encoding=UTF-8 -cp target\agencia-1.0.0.jar -Dloader.main=com.iceibank.agencia.MonitorAlertas org.springframework.boot.loader.launch.PropertiesLauncher"
}

# 6. Frontend - so na subida completa e se ainda nao estiver rodando
if (-not $SemFrontend -and -not $somenteAlgumas) {
    if (PortaAberta 5173) {
        Passo "Frontend ja esta rodando em http://localhost:5173"
    } else {
        Passo "Subindo o frontend"
        if (-not (Test-Path (Join-Path $pastaFrontend 'node_modules'))) {
            Push-Location $pastaFrontend
            try { npm install } finally { Pop-Location }
        }
        NovaJanela "Frontend (5173)" $pastaFrontend "npm run dev"
    }
}

Passo "Esperando as agencias responderem"
foreach ($id in $Agencias) {
    EsperarPorta ($PORTA_BASE + $id) 90 "Agencia $id"
    Write-Host "Agencia $id pronta em http://localhost:$($PORTA_BASE + $id)"
}

if (-not $SemFrontend -and -not $somenteAlgumas) {
    EsperarPorta 5173 60 'Frontend'
    Start-Process 'http://localhost:5173'
}

Write-Host "`nTudo pronto. Login: operador / senha123. Para encerrar: .\parar.cmd" -ForegroundColor Green
