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

:: Configurar diretorio de logs
set "LOG_DIR=%OPENCODE_DATA%\logs"
set "LOG_FILE=%LOG_DIR%\launcher.jsonl"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: Disparar o monitor de logs exclusivo em background de forma transparente se o PowerShell estiver disponivel
where powershell >nul 2>&1
if %errorlevel% == 0 (
    start /b powershell -NoProfile -ExecutionPolicy Bypass -File "%OPENCODE_HOME%scripts\opencode-monitor.ps1" -LogDir "%LOG_DIR%" -OpenCodeHome "%OPENCODE_HOME%" >nul 2>&1
)

:: Capturar PID do processo atual para os logs (metodo mais robusto)
set "_PID=%RANDOM%"
for /f "tokens=2 delims=," %%p in ('wmic process where "name='cmd.exe' and commandline like '%%opencode.bat%%'" get processid /format:csv 2^>nul ^| findstr /r "[0-9]"') do (
    set "_PID=%%p"
)
if not defined _PID set "_PID=%RANDOM%"

:: Registrar inicio no log JSONL
call :write_log "SYSTEM" "START" "launcher=bat"


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
    echo [INFO] opencode.exe nao encontrado. Consultando versao mais recente...
    set "INITIAL_VERSION=1.17.7"
    for /f "usebackq tokens=*" %%r in (`powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { $r = Invoke-WebRequest -Uri 'https://api.github.com/repos/anomalyco/opencode/releases/latest' -UseBasicParsing -TimeoutSec 10; ($r.Content | ConvertFrom-Json).tag_name -replace '^v','' } catch { '1.17.7' }"`) do set "INITIAL_VERSION=%%r"
    echo [INFO] Baixando o pacote oficial da versao v!INITIAL_VERSION!...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/anomalyco/opencode/releases/download/v!INITIAL_VERSION!/opencode-windows-x64.zip' -OutFile '%OPENCODE_BIN%\opencode.zip'"

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
    echo [OK] opencode.exe v!INITIAL_VERSION! instalado com sucesso.
    call :write_log "DOWNLOAD" "COMPLETED" "version=!INITIAL_VERSION!"
)

:: Verificar atualizacao disponivel (roda sempre que o exe existe)
if exist "%OPENCODE_BIN%\opencode.exe" (
    :: Verificar se o executavel e valido (executa --version)
    set "LOCAL_VER="
    for /f "usebackq tokens=*" %%v in (`"%OPENCODE_BIN%\opencode.exe" --version 2^>nul`) do set "LOCAL_VER=%%v"
    :: Extrair apenas numeros de versao (ex: 1.17.7)
    for /f "tokens=1 delims= " %%a in ("!LOCAL_VER!") do set "LOCAL_VER=%%a"
    :: Remover prefixo v se houver
    set "LOCAL_VER=!LOCAL_VER:v=!"

    :: Buscar ultima versao via GitHub API
    set "LATEST_VER="
    for /f "usebackq delims=" %%r in (`powershell -NoProfile -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $r = Invoke-RestMethod -Uri 'https://api.github.com/repos/anomalyco/opencode/releases/latest' -TimeoutSec 10; $r.tag_name -replace '^v','' } catch { '' }" 2^>nul`) do set "LATEST_VER=%%r"

    if defined LATEST_VER if not "!LATEST_VER!"=="" if not "!LATEST_VER!"=="!LOCAL_VER!" (
        echo(
        echo ============================================
        echo   Nova versao disponivel!
        echo ============================================
        echo   Instalada:  v!LOCAL_VER!
        echo   Disponivel: v!LATEST_VER!
        echo(
        call :write_log "UPDATE" "AVAILABLE" "local=!LOCAL_VER!,latest=!LATEST_VER!"
        set /p UPDATE_CHOICE="  Deseja atualizar agora? (S/N): "
        if /i "!UPDATE_CHOICE!"=="S" (
            echo [INFO] Atualizando para v!LATEST_VER!...
            del "%OPENCODE_BIN%\opencode.exe"
            powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/anomalyco/opencode/releases/download/v!LATEST_VER!/opencode-windows-x64.zip' -OutFile '%OPENCODE_BIN%\opencode.zip'"
            if !errorlevel! neq 0 (
                echo [ERRO] Falha ao baixar a atualizacao.
                call :write_log "UPDATE" "FAILED" "target=!LATEST_VER!"
            ) else (
                powershell -Command "Expand-Archive -Path '%OPENCODE_BIN%\opencode.zip' -DestinationPath '%OPENCODE_BIN%' -Force"
                del "%OPENCODE_BIN%\opencode.zip"
                echo [OK] Atualizado com sucesso! v!LOCAL_VER! -^> v!LATEST_VER!
                call :write_log "UPDATE" "SUCCESS" "from=!LOCAL_VER!,to=!LATEST_VER!"
            )
        ) else (
            echo   Continuando com v!LOCAL_VER!...
            call :write_log "UPDATE" "DECLINED" "local=!LOCAL_VER!,latest=!LATEST_VER!"
        )
        echo(
    ) else (
        if defined LATEST_VER if not "!LATEST_VER!"=="" (
            echo [OK] Versao v!LOCAL_VER! esta atualizada.
            call :write_log "UPDATE" "UP_TO_DATE" "version=!LOCAL_VER!"
        )
    )
)

:: Sincronizar plugins npm com versao do binario
set "SYNC_VER="
if exist "%OPENCODE_BIN%\opencode.exe" (
    for /f "usebackq tokens=*" %%v in (`"%OPENCODE_BIN%\opencode.exe" --version 2^>nul`) do set "SYNC_VER=%%v"
)
echo [Z1] SYNC_VER=!SYNC_VER!
if defined SYNC_VER (
    for /f "tokens=1 delims= " %%a in ("!SYNC_VER!") do set "SYNC_VER=%%a"
    echo [Z2] SYNC_VER=!SYNC_VER!
    set "SYNC_VER=!SYNC_VER:v=!"
    echo [Z3] SYNC_VER=!SYNC_VER!
    call :sync_npm_plugins "!SYNC_VER!"
    echo [Z4] returned
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

:: Verificar se os plugins npm estao desatualizados, senao forca o setup a rodar
if exist "%OPENCODE_DATA%\.plugin-version" (
    set /p _PLUGIN_VER=<"%OPENCODE_DATA%\.plugin-version"
    if exist "%OPENCODE_BIN%\opencode.exe" (
        set "_BIN_VER="
        for /f "usebackq tokens=*" %%v in (`"%OPENCODE_BIN%\opencode.exe" --version 2^>nul`) do set "_BIN_VER=%%v"
        for /f "tokens=1 delims= " %%a in ("!_BIN_VER!") do set "_BIN_VER=%%a"
        set "_BIN_VER=!_BIN_VER:v=!"
        if not "!_PLUGIN_VER!"=="!_BIN_VER!" (
            echo [INFO] Plugins desatualizados (plugin v!_PLUGIN_VER!, binario v!_BIN_VER!).
            if exist "%FIRST_RUN%" del "%FIRST_RUN%"
        )
    )
)

if exist "%FIRST_RUN%" goto :start

echo(
echo ============================================
echo   Configuracao Inicial
echo ============================================
echo(

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

:: Instalar dependencias avancadas do Office MCP
echo       Instalando dependencias avancadas do Office MCP...
if exist "%OPENCODE_HOME%scripts\install-office-deps.bat" (
    call "%OPENCODE_HOME%scripts\install-office-deps.bat"
) else (
    echo       [WARN] install-office-deps.bat nao encontrado, pulando dependencias avancadas.
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

:: Configurar opencode.jsonc completo se nao existir ou estiver sem MCP
findstr /i "office-mcp" "%OPENCODE_CONFIG%" >nul 2>&1
if %errorlevel% neq 0 (
    echo Configurando opencode.jsonc com plugins e servidores MCP...
    set "MCP_OFFICE=%OPENCODE_HOME%scripts\office_mcp.py"
    set "MCP_PROJECT=%OPENCODE_HOME%scripts\project_generator.py"
    :: Converter barras para JSON (forward slashes)
    set "MCP_OFFICE=!MCP_OFFICE:\=/!"
    set "MCP_PROJECT=!MCP_PROJECT:\=/!"
    
    :: Detectar Groq ou Ollama para normalizacao de voz
    set "VOICE_ENDPOINT=http://localhost:11434/v1"
    set "VOICE_MODEL=llama3.2"
    set "VOICE_API_KEY="
    if defined GROQ_API_KEY (
        set "VOICE_ENDPOINT=https://api.groq.com/openai/v1"
        set "VOICE_MODEL=llama-3.3-70b-versatile"
        set "VOICE_API_KEY=1"
        call :write_log "SETUP" "GROQ_DETECTED" "model=!VOICE_MODEL!"
    ) else (
        call :write_log "SETUP" "OLLAMA_FALLBACK" "model=!VOICE_MODEL!"
    )
    
    if defined VOICE_API_KEY (
        (
            echo {
            echo   "$schema": "https://opencode.ai/config.json",
            echo   "plugin": [
            echo     ["@renjfk/opencode-voice", {
            echo       "endpoint": "!VOICE_ENDPOINT!",
            echo       "model": "!VOICE_MODEL!",
            echo       "apiKeyEnv": "GROQ_API_KEY"
            echo     }]
            echo   ],
            echo   "mcp": {
            echo     "office-mcp": {
            echo       "type": "local",
            echo       "command": ["python", "!MCP_OFFICE!"],
            echo       "enabled": true
            echo     },
            echo     "project-mcp": {
            echo       "type": "local",
            echo       "command": ["python", "!MCP_PROJECT!"],
            echo       "enabled": true
            echo     }
            echo   }
            echo }
        ) > "%OPENCODE_CONFIG%"
    ) else (
        (
            echo {
            echo   "$schema": "https://opencode.ai/config.json",
            echo   "plugin": [
            echo     ["@renjfk/opencode-voice", {
            echo       "endpoint": "!VOICE_ENDPOINT!",
            echo       "model": "!VOICE_MODEL!"
            echo     }]
            echo   ],
            echo   "mcp": {
            echo     "office-mcp": {
            echo       "type": "local",
            echo       "command": ["python", "!MCP_OFFICE!"],
            echo       "enabled": true
            echo     },
            echo     "project-mcp": {
            echo       "type": "local",
            echo       "command": ["python", "!MCP_PROJECT!"],
            echo       "enabled": true
            echo     }
            echo   }
            echo }
        ) > "%OPENCODE_CONFIG%"
    )
    echo Configuracao completa atualizada!
)

if "!SETUP_OK!"=="1" (
    type nul > "%FIRST_RUN%"
)

echo(
echo ============================================
echo   Pronto!
echo ============================================
echo   Para usar microfone: ollama serve ^& Ctrl+R
echo(

if "%~1"=="" pause

:start
:: ============================================
:: Correcao dinamica de caminhos MCP (roda SEMPRE, mesmo pulando setup)
:: Garante portabilidade: se mover a pasta, os caminhos se corrigem sozinhos
:: ============================================
set "EXPECTED_MCP=%OPENCODE_HOME%scripts\office_mcp.py"
set "EXPECTED_MCP_FWD=!EXPECTED_MCP:\=/!"
findstr /c:"!EXPECTED_MCP_FWD!" "%OPENCODE_CONFIG%" >nul 2>&1
if !errorlevel! neq 0 (
    echo [INFO] Caminhos MCP desatualizados. Corrigindo para diretorio atual...
    set "MCP_OFFICE=!EXPECTED_MCP_FWD!"
    set "MCP_PROJECT=%OPENCODE_HOME%scripts\project_generator.py"
    set "MCP_PROJECT=!MCP_PROJECT:\=/!"
    
    :: Detectar Groq ou Ollama para normalizacao de voz
    set "VOICE_ENDPOINT=http://localhost:11434/v1"
    set "VOICE_MODEL=llama3.2"
    set "VOICE_API_KEY="
    if defined GROQ_API_KEY (
        set "VOICE_ENDPOINT=https://api.groq.com/openai/v1"
        set "VOICE_MODEL=llama-3.3-70b-versatile"
        set "VOICE_API_KEY=1"
        call :write_log "SETUP" "GROQ_DETECTED" "model=!VOICE_MODEL!"
    ) else (
        call :write_log "SETUP" "OLLAMA_FALLBACK" "model=!VOICE_MODEL!"
    )
    
    if defined VOICE_API_KEY (
        (
            echo {
            echo   "$schema": "https://opencode.ai/config.json",
            echo   "plugin": [
            echo     ["@renjfk/opencode-voice", {
            echo       "endpoint": "!VOICE_ENDPOINT!",
            echo       "model": "!VOICE_MODEL!",
            echo       "apiKeyEnv": "GROQ_API_KEY"
            echo     }]
            echo   ],
            echo   "mcp": {
            echo     "office-mcp": {
            echo       "type": "local",
            echo       "command": ["python", "!MCP_OFFICE!"],
            echo       "enabled": true
            echo     },
            echo     "project-mcp": {
            echo       "type": "local",
            echo       "command": ["python", "!MCP_PROJECT!"],
            echo       "enabled": true
            echo     }
            echo   }
            echo }
        ) > "%OPENCODE_CONFIG%"
    ) else (
        (
            echo {
            echo   "$schema": "https://opencode.ai/config.json",
            echo   "plugin": [
            echo     ["@renjfk/opencode-voice", {
            echo       "endpoint": "!VOICE_ENDPOINT!",
            echo       "model": "!VOICE_MODEL!"
            echo     }]
            echo   ],
            echo   "mcp": {
            echo     "office-mcp": {
            echo       "type": "local",
            echo       "command": ["python", "!MCP_OFFICE!"],
            echo       "enabled": true
            echo     },
            echo     "project-mcp": {
            echo       "type": "local",
            echo       "command": ["python", "!MCP_PROJECT!"],
            echo       "enabled": true
            echo     }
            echo   }
            echo }
        ) > "%OPENCODE_CONFIG%"
    )
    echo [OK] Caminhos MCP corrigidos para: %OPENCODE_HOME%
    call :write_log "CONFIG" "PATH_FIX" "home=!EXPECTED_MCP_FWD!"
)

:: Garantir que multitask-worktrees seja uma juncao limpa apontando para a pasta TEMP para evitar erro de recursao do multitask agent
if exist "multitask-worktrees" rmdir /s /q "multitask-worktrees"
if not exist "%TEMP%\opencode-worktrees" mkdir "%TEMP%\opencode-worktrees"
mklink /j "multitask-worktrees" "%TEMP%\opencode-worktrees" >nul 2>&1
set "OPENCODE_DISABLE_PROJECT_CONFIG=1"

:: Gerar log de inicializacao em formato Markdown
call :write_init_log

call :write_log "LAUNCH" "START" "exe=opencode.exe"
echo [INFO] Iniciando opencode.exe...
if "%~1"=="" (
    "%OPENCODE_BIN%\opencode.exe" "%OPENCODE_HOME:~0,-1%"
) else (
    "%OPENCODE_BIN%\opencode.exe" %*
)
echo(
set "EXIT_CODE=%errorlevel%"
call :write_log "SYSTEM" "END" "exit_code=!EXIT_CODE!"
echo [INFO] O OpenCode encerrou com o codigo de retorno: !EXIT_CODE!
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

:: ============================================
:: Sub-rotina: Escrever log JSONL
:: Uso: call :write_log "STAGE" "EVENT" "key=value"
:: ============================================
:write_log
if not defined LOG_FILE goto :eof
set "_STAGE=%~1"
set "_EVENT=%~2"
set "_CTX=%~3"
for /f "tokens=*" %%t in ('powershell -NoProfile -Command "(Get-Date).ToString('o')"') do set "_TS=%%t"
set "_LEVEL=INFO"
echo !_EVENT! | findstr /i "FAILED ERROR ABORTED FATAL" >nul 2>&1 && set "_LEVEL=ERROR"
echo !_EVENT! | findstr /i "SUCCESS COMPLETED OK DONE" >nul 2>&1 && set "_LEVEL=SUCCESS"
echo !_EVENT! | findstr /i "WARN FALLBACK RETRY SKIP" >nul 2>&1 && set "_LEVEL=WARN"
>> "%LOG_FILE%" echo {"ts":"!_TS!","level":"!_LEVEL!","stage":"!_STAGE!","event":"!_EVENT!","context":{"!_CTX!"},"pid":%_PID%}
goto :eof

:: ============================================
:: Sub-rotina: Escrever log de inicializacao em Markdown
:: ============================================
:write_init_log
set "INIT_LOG=%LOG_DIR%\init-log.md"
for /f "tokens=*" %%t in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')"') do set "_INIT_DATE=%%t"

:: Obter versao do OpenCode
set "_OC_VERSION=Desconhecida"
if exist "%OPENCODE_BIN%\opencode.exe" (
    for /f "tokens=*" %%v in ('"%OPENCODE_BIN%\opencode.exe" --version 2^>^&1') do set "_OC_VERSION=%%v"
)

:: Verificar plugins instalados
set "_PLUGINS=Nenhum"
if exist "%OPENCODE_CONFIG%" (
    findstr /i "plugin" "%OPENCODE_CONFIG%" >nul 2>&1 && set "_PLUGINS=Configurados"
)

:: Verificar se Groq esta configurado
set "_GROQ_STATUS=Nao detectado"
if defined GROQ_API_KEY set "_GROQ_STATUS=Detectado"

:: Verificar componentes
set "_PYTHON_STATUS=Nao encontrado"
where python >nul 2>&1 && set "_PYTHON_STATUS=Instalado"

set "_WHISPER_STATUS=Nao encontrado"
where whisper-cli >nul 2>&1 && set "_WHISPER_STATUS=Instalado"

set "_AZURE_STATUS=Nao encontrado"
where az >nul 2>&1 && set "_AZURE_STATUS=Instalado"

:: Criar log de inicializacao em Markdown
echo # Log de Inicializacao - OpenCode Portable > "%INIT_LOG%"
echo( >> "%INIT_LOG%"
echo **Data/Hora:** %_INIT_DATE% >> "%INIT_LOG%"
echo **Versao:** %_OC_VERSION% >> "%INIT_LOG%"
echo **Diretorio:** %OPENCODE_HOME% >> "%INIT_LOG%"
echo( >> "%INIT_LOG%"
echo ## Configuracao Detectada >> "%INIT_LOG%"
echo( >> "%INIT_LOG%"
echo ^| Componente ^| Status ^| >> "%INIT_LOG%"
echo ^|------------^|--------^| >> "%INIT_LOG%"
echo ^| Python ^| %_PYTHON_STATUS% ^| >> "%INIT_LOG%"
echo ^| Whisper ^| %_WHISPER_STATUS% ^| >> "%INIT_LOG%"
echo ^| Azure CLI ^| %_AZURE_STATUS% ^| >> "%INIT_LOG%"
echo ^| Groq API ^| %_GROQ_STATUS% ^| >> "%INIT_LOG%"
echo ^| Plugins ^| %_PLUGINS% ^| >> "%INIT_LOG%"
echo( >> "%INIT_LOG%"
echo ## Variaveis de Ambiente >> "%INIT_LOG%"
echo( >> "%INIT_LOG%"
echo - OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS: %OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS% >> "%INIT_LOG%"
echo - OPENCODE_EXPERIMENTAL_PLAN_MODE: %OPENCODE_EXPERIMENTAL_PLAN_MODE% >> "%INIT_LOG%"
echo( >> "%INIT_LOG%"
echo --- >> "%INIT_LOG%"
echo *Este log foi gerado automaticamente na inicializacao do OpenCode.* >> "%INIT_LOG%"
goto :eof

:: ============================================
:: Sub-rotina: Sincronizar plugins npm com versao do binario
:: Uso: call :sync_npm_plugins VERSION
:: ============================================
:sync_npm_plugins
echo [S1]
set "_TARGET_VER=%~1"
echo [S2] target=!_TARGET_VER!
set "_PKG_JSON=%OPENCODE_CONFIG_DIR%\package.json"
set "_PKG_LOCK=%OPENCODE_CONFIG_DIR%\package-lock.json"
set "_PLUGIN_MARKER=%OPENCODE_DATA%\.plugin-version"

:: Verificar se npm esta disponivel
where npm >nul 2>&1
if %errorlevel% neq 0 (
    echo       [WARN] npm nao encontrado. Pulando sincronizacao de plugins.
    call :write_log "NPM_SYNC" "SKIP" "reason=NPM_NOT_FOUND"
    goto :eof
)

:: Ler versao instalada do marker
set "_INSTALLED_VER="
if exist "%_PLUGIN_MARKER%" (
    set /p _INSTALLED_VER=<"%_PLUGIN_MARKER%"
)

:: Se marker nao existe, tentar ler do package-lock.json
if not defined _INSTALLED_VER (
    if exist "%_PKG_LOCK%" (
        for /f "tokens=2 delims=:," %%a in ('findstr /c:"@opencode-ai/plugin" "%_PKG_LOCK%"') do (
            if not defined _INSTALLED_VER set "_INSTALLED_VER=%%~a"
        )
    )
)
:: Limpar espacos e aspas do resultado
if defined _INSTALLED_VER (
    set _INSTALLED_VER=!_INSTALLED_VER: =!
    set _INSTALLED_VER=!_INSTALLED_VER:"=!
)

:: Comparar versoes
if defined _INSTALLED_VER if "!_INSTALLED_VER!"=="!_TARGET_VER!" (
    echo       [OK] Plugins sincronizados (v!_TARGET_VER!).
    call :write_log "NPM_SYNC" "UP_TO_DATE" "plugin=!_INSTALLED_VER!,binary=!_TARGET_VER!"
    goto :eof
)

if defined _INSTALLED_VER (
    echo       [INFO] Plugin desatualizado: v!_INSTALLED_VER! -^> v!_TARGET_VER!
) else (
    echo       [INFO] Instalando plugins v!_TARGET_VER!...
)
call :write_log "NPM_SYNC" "MISMATCH" "installed=!_INSTALLED_VER!,target=!_TARGET_VER!"

:: Criar package.json
if not exist "%OPENCODE_CONFIG_DIR%" mkdir "%OPENCODE_CONFIG_DIR%"
(
    echo {
    echo   "dependencies": {
    echo     "@opencode-ai/plugin": "!_TARGET_VER!"
    echo   }
    echo }
) > "%_PKG_JSON"
call :write_log "NPM_SYNC" "PACKAGE_JSON_WRITTEN" "version=!_TARGET_VER!"

:: Executar npm install (com retry)
set "_NPM_MAX=3"
set "_NPM_ATTEMPT=1"
:npm_retry_loop
echo       Executando npm install (tentativa !_NPM_ATTEMPT!/!_NPM_MAX!)...
cd /d "%OPENCODE_CONFIG_DIR%"
npm install >nul 2>&1
if %errorlevel% equ 0 (
    echo !_TARGET_VER!> "%_PLUGIN_MARKER%"
    echo       [OK] Plugins atualizados para v!_TARGET_VER!.
    call :write_log "NPM_SYNC" "SUCCESS" "version=!_TARGET_VER!,attempt=!_NPM_ATTEMPT!"
    cd /d "%OPENCODE_HOME%"
    goto :eof
)
set /a _NPM_ATTEMPT+=1
if !_NPM_ATTEMPT! leq !_NPM_MAX! (
    echo       [WARN] npm install falhou, tentando novamente...
    timeout /t 3 /nobreak >nul 2>&1
    goto :npm_retry_loop
)

echo       [ERRO] Falha ao instalar plugins apos !_NPM_MAX! tentativas.
call :write_log "NPM_SYNC" "ABORTED" "reason=MAX_RETRIES_EXCEEDED,target=!_TARGET_VER!"
cd /d "%OPENCODE_HOME%"
goto :eof
