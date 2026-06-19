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

:: Iniciar NVIDIA Router em background (invisivel, sem janela)
set "ROUTER_RUNNING=0"
tasklist /fi "imagename eq pythonw.exe" /fo csv /nh 2>nul | findstr /i "nvidia_router" >nul 2>&1 && set "ROUTER_RUNNING=1"
tasklist /fi "imagename eq python.exe" /fo csv /nh 2>nul | findstr /i "nvidia_router" >nul 2>&1 && set "ROUTER_RUNNING=1"
if "%ROUTER_RUNNING%"=="0" (
    start "" pythonw "%OPENCODE_HOME%scripts\nvidia_router.py"
)

:: Chamar o orquestrador principal em PowerShell repassando todos os parâmetros
powershell -NoProfile -ExecutionPolicy Bypass -File "%OPENCODE_HOME%opencode.ps1" %*

exit /b %errorlevel%
