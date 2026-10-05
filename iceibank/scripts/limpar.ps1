# Apaga os logs de eventos das agencias (agencia-java\data\*.jsonl), para comecar uma
# rodada de experimentos do zero (ex.: antes dos prints da linha do tempo causal).
#   .\limpar.cmd
#
# So limpa com as agencias paradas: os vetores delas continuam em memoria, e um log
# novo comecando no meio da execucao misturaria a contagem.

$raiz = Split-Path -Parent $PSScriptRoot
$pastaDados = Join-Path $raiz 'agencia-java\data'
$PORTA_BASE = 4006

$rodando = 0..2 | Where-Object {
    Get-NetTCPConnection -LocalPort ($PORTA_BASE + $_) -State Listen -ErrorAction SilentlyContinue
}
if ($rodando) {
    Write-Host "Agencia(s) $($rodando -join ', ') ainda rodando. Rode .\parar.cmd antes de limpar." -ForegroundColor Yellow
    exit 1
}

$arquivos = Get-ChildItem (Join-Path $pastaDados '*.jsonl') -ErrorAction SilentlyContinue
if (-not $arquivos) {
    Write-Host "Nenhum log para apagar em $pastaDados."
    exit 0
}
$arquivos | Remove-Item
Write-Host "Logs apagados: $($arquivos.Name -join ', ')" -ForegroundColor Green
