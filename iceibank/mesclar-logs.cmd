@echo off
rem Linha do tempo causal (Parte D). Uso: mesclar-logs.cmd  ou  mesclar-logs.cmd 4 9
cd /d "%~dp0agencia-java"
java -Dsun.stdout.encoding=UTF-8 -cp target\agencia-1.0.0.jar -Dloader.main=com.iceibank.agencia.MesclarLogs org.springframework.boot.loader.launch.PropertiesLauncher %*
