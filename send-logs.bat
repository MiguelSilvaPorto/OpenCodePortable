@echo off
setlocal

set "OPENCODE_HOME=%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%OPENCODE_HOME%scripts\send_logs.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [ERRO] O script de envio de logs falhou com o codigo: %errorlevel%
    pause
)

exit /b %errorlevel%
