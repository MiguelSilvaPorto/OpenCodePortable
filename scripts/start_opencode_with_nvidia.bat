@echo off
echo =============================================
echo   Iniciando NVIDIA Router + OpenCode
echo =============================================
echo.

:: Check API key
if "%NVIDIA_API_KEY%"=="" (
    echo [ERROR] NVIDIA_API_KEY not set!
    echo.
    echo Set it first:
    echo   PowerShell: $env:NVIDIA_API_KEY = 'nvapi-...'
    echo   CMD:        set NVIDIA_API_KEY=nvapi-...
    echo.
    pause
    exit /b 1
)

:: Start router in background
echo Starting NVIDIA Router on port 9393...
start /min python "%~dp0nvidia_router.py"
timeout /t 3 /nobreak >nul
echo Router started!

:: Start opencode
echo Starting OpenCode...
python -m opencode

:: Cleanup on exit
echo.
echo Stopping NVIDIA Router...
taskkill /f /fi "WINDOWTITLE eq nvidia_router*" >nul 2>&1
