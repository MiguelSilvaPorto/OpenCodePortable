@echo off
setlocal

set "OPENCODE_HOME=%~dp0"

:: Verificar se PowerShell está disponível
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] PowerShell nao foi encontrado no sistema.
    pause
    exit /b 1
)

:: Chamar o launcher Electron em PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File "%OPENCODE_HOME%opencode-electron.ps1" %*

exit /b %errorlevel%
