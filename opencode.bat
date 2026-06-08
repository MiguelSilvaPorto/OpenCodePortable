@echo off
setlocal enabledelayedexpansion

set "OPENCODE_HOME=%~dp0"
set "OPENCODE_BIN=%OPENCODE_HOME%bin"
set "OPENCODE_CONFIG_DIR=%OPENCODE_HOME%config"
set "OPENCODE_DATA=%OPENCODE_HOME%data"
set "OPENCODE_CONFIG=%OPENCODE_CONFIG_DIR%\opencode.jsonc"
set "MODELS_DIR=%OPENCODE_DATA%\whisper-models"
set "FIRST_RUN=%OPENCODE_DATA%\.voice-setup-done"

set "PATH=%OPENCODE_BIN%;%PATH%"

:: Adicionar shims do Scoop ao PATH (necessario para whisper-cli, sox, etc.)
if defined USERPROFILE (
    set "SCOOP_SHIMS=%USERPROFILE%\scoop\shims"
    if exist "%SCOOP_SHIMS%" set "PATH=%SCOOP_SHIMS%;%PATH%"
)

if not exist "%OPENCODE_BIN%\opencode.exe" (
    echo [ERRO] opencode.exe nao encontrado
    pause
    exit /b 1
)

if not exist "%OPENCODE_DATA%" mkdir "%OPENCODE_DATA%"
if not exist "%OPENCODE_CONFIG_DIR%" mkdir "%OPENCODE_CONFIG_DIR%"

if exist "%FIRST_RUN%" goto :start

echo.
echo ============================================
echo   Configuracao Inicial
echo ============================================
echo.

set "SETUP_OK=1"

echo [1/5] Scoop...
where scoop >nul 2>&1
if %errorlevel% neq 0 (
    echo       Nao encontrado - Execute: scripts\install-voice.bat
    set "SETUP_OK=0"
) else (
    echo       OK

    echo [2/5] whisper-cpp...
    where whisper-cli >nul 2>&1
    if %errorlevel% neq 0 (
        echo       Instalando...
        call scoop install whisper-cpp
        if !errorlevel! neq 0 (
            echo       [ERRO] Falha ao instalar whisper-cpp
            set "SETUP_OK=0"
        )
    ) else (
        echo       OK
    )

    echo [3/5] sox...
    where sox >nul 2>&1
    if %errorlevel% neq 0 (
        echo       Instalando...
        call scoop install sox
        if !errorlevel! neq 0 (
            echo       [ERRO] Falha ao instalar sox
            set "SETUP_OK=0"
        )
    ) else (
        echo       OK
    )
)

echo [4/5] Modelo whisper...
if exist "%MODELS_DIR%\ggml-base.bin" (
    echo       OK
) else (
    echo       Baixando...
    if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%"
    curl -L -o "%MODELS_DIR%\ggml-base.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
    if !errorlevel! neq 0 (
        echo       [ERRO] Falha ao baixar modelo
        set "SETUP_OK=0"
    )
)

echo [5/5] Ollama...
where ollama >nul 2>&1
if %errorlevel% neq 0 (
    echo       Nao encontrado - https://ollama.com
) else (
    echo       OK
)

if not exist "%OPENCODE_CONFIG%" (
    >"%OPENCODE_CONFIG%" (
        echo {
        echo   "$schema": "https://opencode.ai/config.json",
        echo   "plugin": [
        echo     ["@renjfk/opencode-voice", {
        echo       "endpoint": "http://localhost:11434/v1",
        echo       "model": "llama3.2"
        echo     }]
        echo   ]
        echo }
    )
    echo Configuracao criada
)

type nul > "%FIRST_RUN%"

echo.
echo ============================================
echo   Pronto!
echo ============================================
echo   Para usar microfone: ollama serve ^& Ctrl+R
echo.

if "%~1"=="" pause

:start
set "OPENCODE_DISABLE_PROJECT_CONFIG=1"
"%OPENCODE_BIN%\opencode.exe" %*
