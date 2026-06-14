@echo off
setlocal enabledelayedexpansion

set "OPENCODE_HOME=%~dp0"
set "OPENCODE_BIN=%OPENCODE_HOME%bin"
set "OPENCODE_CONFIG_DIR=%OPENCODE_HOME%config"
set "OPENCODE_DATA=%OPENCODE_HOME%data"
set "OPENCODE_CONFIG=%OPENCODE_CONFIG_DIR%\opencode.jsonc"
set "MODELS_DIR=%OPENCODE_DATA%\whisper-models"
set "FIRST_RUN=%OPENCODE_DATA%\.voice-setup-done"
set "OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true"
set "OPENCODE_EXPERIMENTAL_PLAN_MODE=true"

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
    python -c "import openpyxl, docx, pptx, mcp, win32com.client, psutil, formulas, msal, pdf2image, lxml" >nul 2>&1
    if !errorlevel! neq 0 (
        if exist "%FIRST_RUN%" del "%FIRST_RUN%"
    )
) else (
    if exist "%FIRST_RUN%" del "%FIRST_RUN%"
)

:: Verificar se o Azure CLI esta instalado, senao forca o setup a rodar
where az >nul 2>&1
if errorlevel 1 (
    if exist "%FIRST_RUN%" del "%FIRST_RUN%"
)

if exist "%FIRST_RUN%" goto :start

echo.
echo ============================================
echo   Configuracao Inicial
echo ============================================
echo.

set "SETUP_OK=1"

echo [1/7] Scoop...
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

if not "!SETUP_OK!"=="1" goto :setup_done

echo [2/7] Adicionando bucket 'extras' no Scoop...
call scoop bucket list | findstr /i "extras" >nul 2>&1
if errorlevel 1 (
    echo       Adicionando extras bucket...
    call scoop bucket add extras
    if errorlevel 1 (
        echo       [ERRO] Falha ao adicionar bucket extras.
        set "SETUP_OK=0"
    )
) else (
    echo       OK
)

if not "!SETUP_OK!"=="1" goto :setup_done

echo [3/7] whisper-cpp...
where whisper-cli >nul 2>&1
if errorlevel 1 (
    echo       Instalando whisper-cpp...
    call scoop install whisper-cpp
    if errorlevel 1 (
        echo       [ERRO] Falha ao instalar whisper-cpp.
        set "SETUP_OK=0"
    )
) else (
    echo       OK
)

if not "!SETUP_OK!"=="1" goto :setup_done

echo [4/7] sox...
where sox >nul 2>&1
if errorlevel 1 (
    echo       Instalando sox...
    call scoop install sox
    if errorlevel 1 (
        echo       [ERRO] Falha ao instalar sox.
        set "SETUP_OK=0"
    )
) else (
    echo       OK
)

if not "!SETUP_OK!"=="1" goto :setup_done

echo [5/7] Modelo whisper...
if exist "%MODELS_DIR%\ggml-base.bin" (
    echo       OK
) else (
    echo       Baixando...
    if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%"
    curl -L -o "%MODELS_DIR%\ggml-base.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
    if errorlevel 1 (
        echo       [ERRO] Falha ao baixar modelo
        set "SETUP_OK=0"
    )
)

if not "!SETUP_OK!"=="1" goto :setup_done

echo [6/7] Dependencias Office MCP (Python)...
where python >nul 2>&1
if errorlevel 1 (
    echo       Instalando Python via Scoop...
    call scoop install python
    if errorlevel 1 (
        echo       [ERRO] Falha ao instalar Python.
        set "SETUP_OK=0"
    )
) else (
    echo       Python OK
)

if not "!SETUP_OK!"=="1" goto :setup_done

echo       Instalando bibliotecas do Office...
python -m pip install --upgrade pip >nul 2>&1
python -m pip install openpyxl python-docx python-pptx pywin32 mcp psutil formulas msal pdf2image lxml >nul 2>&1
python -c "import openpyxl, docx, pptx, mcp, win32com.client, psutil, formulas, msal, pdf2image, lxml" >nul 2>&1
if errorlevel 1 (
    echo       [ERRO] Falha ao instalar dependencias do Python.
    set "SETUP_OK=0"
) else (
    echo       OK
)

if not "!SETUP_OK!"=="1" goto :setup_done

echo [7/7] Azure CLI...
where az >nul 2>&1
if errorlevel 1 (
    echo       Instalando Azure CLI via Scoop...
    call scoop install azure-cli
    if errorlevel 1 (
        echo       [ERRO] Falha ao instalar Azure CLI.
        set "SETUP_OK=0"
    ) else (
        echo       [OK] Azure CLI instalado com sucesso.
    )
) else (
    echo       Azure CLI OK
)

if not "!SETUP_OK!"=="1" goto :setup_done

:: Verificacao de autenticacao Azure (fora de blocos if para set /p funcionar)
call :check_az_login

:setup_done

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
:: Garantir que multitask-worktrees seja uma juncao limpa apontando para a pasta TEMP para evitar erro de recursao do multitask agent
if exist "multitask-worktrees" rmdir /s /q "multitask-worktrees"
if not exist "%TEMP%\opencode-worktrees" mkdir "%TEMP%\opencode-worktrees"
mklink /j "multitask-worktrees" "%TEMP%\opencode-worktrees" >nul 2>&1
set "OPENCODE_DISABLE_PROJECT_CONFIG=1"
echo [INFO] Iniciando opencode.exe...
if "%~1"=="" (
    "%OPENCODE_BIN%\opencode.exe" "%OPENCODE_HOME:~0,-1%"
) else (
    "%OPENCODE_BIN%\opencode.exe" %*
)
echo.
echo [INFO] O OpenCode encerrou com o codigo de retorno: %errorlevel%
pause
goto :eof

:: ============================================
:: Sub-rotina: Verificar autenticacao Azure CLI
:: ============================================
:check_az_login
where az >nul 2>&1
if errorlevel 1 goto :eof
call az account show >nul 2>&1
if not errorlevel 1 (
    echo       Azure CLI ja autenticado.
    goto :eof
)
echo       Voce nao esta autenticado no Azure.
set /p AZ_LOGIN_NOW="      Deseja realizar o 'az login' agora? (S/N): "
if /i "!AZ_LOGIN_NOW!"=="S" (
    echo       Iniciando az login...
    call az login
)
goto :eof

