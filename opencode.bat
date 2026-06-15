@echo off
setlocal enabledelayedexpansion

:: Wrapper portátil: delega toda a inicializacao e execução robusta para o PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0opencode.ps1" %*
exit /b !errorlevel!
