@echo off
echo =============================================
echo   NVIDIA Model Router
echo   Port: 9393
echo =============================================
echo.

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

echo Starting NVIDIA Router on http://localhost:9393
echo Models: nemotron-3-nano-omni, gemma-4, mistral-medium, llama-3.3, deepseek-v4-flash
echo.
python "%~dp0nvidia_router.py"
