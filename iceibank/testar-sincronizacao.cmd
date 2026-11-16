@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\testar-sincronizacao.ps1" %*
