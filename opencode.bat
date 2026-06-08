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

if not exist "%OPENCODE_BIN%" mkdir "%OPENCODE_BIN%"
if exist "%OPENCODE_BIN%\opencode.exe" (
    for %%I in ("%OPENCODE_BIN%\opencode.exe") do set "FILE_SIZE=%%~zI"
    if !FILE_SIZE! lss 10000000 (
        echo [WARN] opencode.exe esta corrompido ou incompleto, tamanho: !FILE_SIZE! bytes.
        echo        Apagando e baixando novamente...
        del "%OPENCODE_BIN%\opencode.exe"
    )
)
if not exist "%OPENCODE_BIN%\opencode.exe" (
    echo [INFO] opencode.exe nao encontrado. Baixando o pacote oficial da versao 1.16.2...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/anomalyco/opencode/releases/download/v1.16.2/opencode-windows-x64.zip' -OutFile '%OPENCODE_BIN%\opencode.zip'"
    if !errorlevel! neq 0 (
        echo [ERRO] Falha ao baixar o arquivo zip do opencode.
        pause
        exit /b 1
    )
    echo [INFO] Extraindo executavel...
    powershell -Command "Expand-Archive -Path '%OPENCODE_BIN%\opencode.zip' -DestinationPath '%OPENCODE_BIN%' -Force"
    del "%OPENCODE_BIN%\opencode.zip"
    if not exist "%OPENCODE_BIN%\opencode.exe" (
        echo [ERRO] opencode.exe nao foi encontrado apos extrair o ZIP.
        pause
        exit /b 1
    )
    echo [OK] opencode.exe instalado com sucesso.
)

if not exist "%OPENCODE_DATA%" mkdir "%OPENCODE_DATA%"
if not exist "%OPENCODE_CONFIG_DIR%" mkdir "%OPENCODE_CONFIG_DIR%"

:: Verificar se as dependencias do Office estao instaladas, senao forca o setup a rodar
where python >nul 2>&1
if %errorlevel% == 0 (
    python -c "import openpyxl, docx, pptx, mcp, win32com.client" >nul 2>&1
    if !errorlevel! neq 0 (
        if exist "%FIRST_RUN%" del "%FIRST_RUN%"
    )
) else (
    if exist "%FIRST_RUN%" del "%FIRST_RUN%"
)

if exist "%FIRST_RUN%" goto :start

echo.
echo ============================================
echo   Configuracao Inicial
echo ============================================
echo.

set "SETUP_OK=1"

echo [1/6] Scoop...
where scoop >nul 2>&1
if %errorlevel% neq 0 (
    echo       Nao encontrado. Instalando Scoop automaticamente...
    powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
    if !errorlevel! neq 0 (
        echo       [ERRO] Falha ao instalar o Scoop.
        set "SETUP_OK=0"
    ) else (
        echo       [OK] Scoop instalado com sucesso.
        set "PATH=%USERPROFILE%\scoop\shims;%PATH%"
    )
) else (
    echo       OK
)

if "!SETUP_OK!"=="1" (
    echo [2/6] Adicionando bucket 'extras' no Scoop...
    call scoop bucket list | findstr /i "extras" >nul 2>&1
    if !errorlevel! neq 0 (
        echo       Adicionando extras bucket...
        call scoop bucket add extras
        if !errorlevel! neq 0 (
            echo       [ERRO] Falha ao adicionar bucket extras.
            set "SETUP_OK=0"
        )
    ) else (
        echo       OK
    )
)

if "!SETUP_OK!"=="1" (
    echo [3/6] whisper-cpp...
    where whisper-cli >nul 2>&1
    if !errorlevel! neq 0 (
        echo       Instalando whisper-cpp...
        call scoop install whisper-cpp
        if !errorlevel! neq 0 (
            echo       [ERRO] Falha ao instalar whisper-cpp.
            set "SETUP_OK=0"
        )
    ) else (
        echo       OK
    )
)

if "!SETUP_OK!"=="1" (
    echo [4/6] sox...
    where sox >nul 2>&1
    if !errorlevel! neq 0 (
        echo       Instalando sox...
        call scoop install sox
        if !errorlevel! neq 0 (
            echo       [ERRO] Falha ao instalar sox.
            set "SETUP_OK=0"
        )
    ) else (
        echo       OK
    )
)

echo [5/6] Modelo whisper...
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

if "!SETUP_OK!"=="1" (
    echo [6/6] Dependencias Office MCP (Python)...
    where python >nul 2>&1
    if !errorlevel! neq 0 (
        echo       Instalando Python via Scoop...
        call scoop install python
        if !errorlevel! neq 0 (
            echo       [ERRO] Falha ao instalar Python.
            set "SETUP_OK=0"
        )
    ) else (
        echo       Python OK
    )
    if "!SETUP_OK!"=="1" (
        echo       Instalando bibliotecas do Office...
        python -m pip install --upgrade pip >nul 2>&1
        python -m pip install openpyxl python-docx python-pptx pywin32 mcp >nul 2>&1
        :: Nao falha o setup caso ocorra apenas warnings de conflito se os pacotes funcionarem
        python -c "import openpyxl, docx, pptx, mcp, win32com.client" >nul 2>&1
        if !errorlevel! neq 0 (
            echo       [ERRO] Falha ao instalar dependencias do Python.
            set "SETUP_OK=0"
        ) else (
            echo       OK
        )
    )
)

echo [Opcional] Ollama...
where ollama >nul 2>&1
if %errorlevel% neq 0 (
    echo       Nao encontrado - https://ollama.com
) else (
    echo       OK
)

:: Configurar o plugin de voz em opencode.jsonc se nao estiver configurado
findstr /i "@renjfk/opencode-voice" "%OPENCODE_CONFIG%" >nul 2>&1
if %errorlevel% neq 0 (
    echo Configurando plugin de voz em opencode.jsonc...
    (
        echo {
        echo   "$schema": "https://opencode.ai/config.json",
        echo   "plugin": [
        echo     ["@renjfk/opencode-voice", {
        echo       "endpoint": "http://localhost:11434/v1",
        echo       "model": "llama3.2"
        echo     }]
        echo   ]
        echo }
    ) > "%OPENCODE_CONFIG%"
    echo Configuracao atualizada!
)

if "!SETUP_OK!"=="1" (
    type nul > "%FIRST_RUN%"
)

echo.
echo ============================================
echo   Pronto!
echo ============================================
echo   Para usar microfone: ollama serve ^& Ctrl+R
echo.

if "%~1"=="" pause

:start
set "OPENCODE_DISABLE_PROJECT_CONFIG=1"
echo [INFO] Iniciando opencode.exe...
"%OPENCODE_BIN%\opencode.exe" %*
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] O OpenCode encerrou com o codigo de erro: %errorlevel%
    pause
)
