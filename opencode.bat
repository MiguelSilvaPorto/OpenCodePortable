@echo off
setlocal

set "OPENCODE_HOME=%~dp0"

:: Verificar se PowerShell está disponível no sistema
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] PowerShell nao foi encontrado no sistema.
    echo        O OpenCode Portable necessita do PowerShell para rodar a suite de setup e execucao.
    pause
    exit /b 1
)

:: Chamar o orquestrador principal em PowerShell repassando todos os parâmetros
powershell -NoProfile -ExecutionPolicy Bypass -File "%OPENCODE_HOME%opencode.ps1" %*

if %errorlevel% neq 0 (
    echo.
    echo [ERRO] O OpenCode falhou ao iniciar - Codigo: %errorlevel%
    pause
)

exit /b %errorlevel%
