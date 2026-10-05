# Encerra o ambiente do ICEIBank.
#   .\parar.cmd                 encerra agencias, monitor e frontend (o RabbitMQ continua, com as filas)
#   .\parar.cmd -Agencias 1     derruba so a agencia 1 (teste de resiliencia)
#   .\parar.cmd -Broker         tambem para o container do RabbitMQ
param(
    [int[]]$Agencias = @(0, 1, 2),
    [switch]$Broker
)

$raiz = Split-Path -Parent $PSScriptRoot
$PORTA_BASE = 4006
$somenteAlgumas = $PSBoundParameters.ContainsKey('Agencias')

function EncerrarPorta($porta, $nome) {
    $conexoes = Get-NetTCPConnection -LocalPort $porta -State Listen -ErrorAction SilentlyContinue
    if (-not $conexoes) { Write-Host "$nome nao estava rodando."; return }
    foreach ($c in $conexoes) { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue }
    Write-Host "$nome encerrada."
}

foreach ($id in $Agencias) { EncerrarPorta ($PORTA_BASE + $id) "Agencia $id" }

if (-not $somenteAlgumas) {
    Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" |
        Where-Object { $_.CommandLine -like '*MonitorAlertas*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; Write-Host "Monitor de alertas encerrado." }
    EncerrarPorta 5173 'Frontend'
}

if ($Broker) {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    $dockerExe = if ($docker) { $docker.Source } else { 'C:\Program Files\Docker\Docker\resources\bin\docker.exe' }
    & $dockerExe compose -f (Join-Path $raiz 'docker-compose.yml') stop
}
