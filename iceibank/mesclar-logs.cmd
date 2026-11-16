@echo off
setlocal
rem Linha do tempo causal (Parte D). Uso: mesclar-logs.cmd  ou  mesclar-logs.cmd 4 9
cd /d "%~dp0agencia-java"
rem O Java escreve em UTF-8; troca o console para UTF-8 (65001) e depois devolve a pagina de codigo original
for /f "tokens=2 delims=:." %%c in ('chcp') do set "CP_ORIGINAL=%%c"
chcp 65001 > nul
java -Dsun.stdout.encoding=UTF-8 -cp target\agencia-1.0.0.jar -Dloader.main=com.iceibank.agencia.MesclarLogs org.springframework.boot.loader.launch.PropertiesLauncher %*
chcp %CP_ORIGINAL% > nul
