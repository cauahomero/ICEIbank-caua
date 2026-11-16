@echo off
setlocal
rem Linha do tempo de liderancas do Bully (Sprint 3, Parte C). Uso: historico-lideranca.cmd
cd /d "%~dp0agencia-java"
rem O Java escreve em UTF-8; troca o console para UTF-8 (65001) e depois devolve a pagina de codigo original
for /f "tokens=2 delims=:." %%c in ('chcp') do set "CP_ORIGINAL=%%c"
chcp 65001 > nul
java -Dsun.stdout.encoding=UTF-8 -cp target\agencia-1.0.0.jar -Dloader.main=com.iceibank.agencia.HistoricoLideranca org.springframework.boot.loader.launch.PropertiesLauncher %*
chcp %CP_ORIGINAL% > nul
