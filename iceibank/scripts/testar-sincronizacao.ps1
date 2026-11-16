# Parte E do Sprint 3: mostra a deteccao de conflito do POST /contas/{id}/sincronizar.
#   1. cria a conta e consulta o saldo (a resposta traz o vetorAtual)
#   2. guarda esse vetor e faz um deposito direto ("enquanto o app estava offline")
#   3. sincroniza um saque com o vetor antigo -> 409
#   4. sincroniza de novo com o vetorAtual devolvido no 409 -> 200
# Uso (com as agencias no ar):  .\testar-sincronizacao.cmd [-Conta 300]
param(
    [int]$Conta = 300
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$agencia = $Conta % 3
$base = "http://localhost:$(4006 + $agencia)"

function Passo($texto) { Write-Host "`n==> $texto" -ForegroundColor Cyan }

function Chamar($metodo, $caminho, $corpo) {
    $params = @{ Uri = "$base$caminho"; Method = $metodo; Headers = $script:cabecalhos; UseBasicParsing = $true }
    if ($corpo) {
        $json = $corpo | ConvertTo-Json -Compress
        Write-Host "    $metodo $caminho $json" -ForegroundColor DarkGray
        $params.ContentType = 'application/json; charset=utf-8'
        $params.Body = [Text.Encoding]::UTF8.GetBytes($json)
    } else {
        Write-Host "    $metodo $caminho" -ForegroundColor DarkGray
    }
    try {
        $r = Invoke-WebRequest @params
        $status = [int]$r.StatusCode
        $texto = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
    } catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if (-not $resp) { throw "Agencia $agencia ($base) nao respondeu. Suba as agencias com .\iniciar.cmd" }
        $status = [int]$resp.StatusCode
        $texto = (New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)).ReadToEnd()
    }
    $cor = if ($status -lt 300) { 'Green' } elseif ($status -eq 409) { 'Yellow' } else { 'Red' }
    $obj = $texto | ConvertFrom-Json
    Write-Host "    HTTP $status" -ForegroundColor $cor
    # Um campo por linha, com valores compactos (vetores e conta numa linha so)
    foreach ($p in $obj.PSObject.Properties) {
        Write-Host ("      {0}: {1}" -f $p.Name, (ConvertTo-Json $p.Value -Compress -Depth 5))
    }
    [pscustomobject]@{ Status = $status; Corpo = $obj }
}

$login = Invoke-RestMethod "$base/auth/login" -Method Post -ContentType 'application/json' -Body '{"usuario":"operador","senha":"senha123"}'
$script:cabecalhos = @{ Authorization = "Bearer $($login.token)" }
Write-Host "Conta $Conta -> agencia $agencia ($base)  $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"

Passo "1. Cria a conta $Conta (se ja existir, segue com ela) e consulta o saldo"
Chamar Post '/contas' @{ id = $Conta; nomeAluno = 'Teste offline'; saldoInicial = 500 } | Out-Null
$leitura = Chamar Get "/contas/$Conta"
$vetorConhecido = $leitura.Corpo.vetorAtual
Write-Host "    vetor guardado pelo 'app': [$($vetorConhecido -join ',')]" -ForegroundColor Magenta

Passo "2. Deposito direto na agencia, enquanto o 'app' esta offline"
Chamar Post "/contas/$Conta/depositar" @{ valor = 100 } | Out-Null

Passo "3. App volta e sincroniza um saque de 50 com o vetor antigo [$($vetorConhecido -join ',')]"
$conflito = Chamar Post "/contas/$Conta/sincronizar" @{ tipo = 'SAQUE'; valor = 50; vetorConhecido = $vetorConhecido }
if ($conflito.Status -ne 409) { Write-Host "    Esperava 409!" -ForegroundColor Red; exit 1 }

$vetorNovo = $conflito.Corpo.vetorAtual
Passo "4. Sincroniza de novo com o vetorAtual do 409 [$($vetorNovo -join ',')]"
$ok = Chamar Post "/contas/$Conta/sincronizar" @{ tipo = 'SAQUE'; valor = 50; vetorConhecido = $vetorNovo }
if ($ok.Status -ne 200) { Write-Host "    Esperava 200!" -ForegroundColor Red; exit 1 }

Write-Host "`nConflito detectado com o vetor antigo e operacao aplicada com o vetor atualizado." -ForegroundColor Green
