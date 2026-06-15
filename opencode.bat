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

:: Capturar PID do processo atual para os logs
for /f "tokens=2" %%p in ('tasklist /fi "IMAGENAME eq cmd.exe" /fo list /nh 2^>nul ^| findstr /i "PID:"') do (
    set "_PID=%%p"
)
if not defined _PID set "_PID=0"

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
    echo [INFO] opencode.exe nao encontrado. Baixando o pacote oficial da versao 1.17.7...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/anomalyco/opencode/releases/download/v1.17.7/opencode-windows-x64.zip' -OutFile '%OPENCODE_BIN%\opencode.zip'"

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
    call :write_log "DOWNLOAD" "COMPLETED" "version=1.17.7"
)

:: Verificar atualizacao disponivel (roda sempre que o exe existe)
if exist "%OPENCODE_BIN%\opencode.exe" (
    echo [INFO] Verificando atualizacoes...
    for /f "tokens=*" %%v in ('"%OPENCODE_BIN%\opencode.exe" --version 2^>^&1') do set "LOCAL_VER=%%v"
    :: Extrair apenas numeros de versao (ex: 1.17.7)
    for /f "tokens=1 delims= " %%a in ("!LOCAL_VER!") do set "LOCAL_VER=%%a"
    :: Remover prefixo v se houver
    set "LOCAL_VER=!LOCAL_VER:v=!"

    :: Buscar ultima versao via GitHub API
    for /f "delims=" %%r in ('powershell -NoProfile -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $r = Invoke-RestMethod -Uri 'https://api.github.com/repos/anomalyco/opencode/releases/latest' -TimeoutSec 10; $r.tag_name -replace '^v','' } catch { '' }" 2^>nul') do set "LATEST_VER=%%r"

    if defined LATEST_VER if not "!LATEST_VER!"=="" if not "!LATEST_VER!"=="!LOCAL_VER!" (
        echo.
        echo ============================================
        echo   Nova versao disponivel!
        echo ============================================
        echo   Instalada:  v!LOCAL_VER!
        echo   Disponivel: v!LATEST_VER!
        echo.
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
        echo.
    ) else (
        if defined LATEST_VER if not "!LATEST_VER!"=="" (
            echo [OK] Versao v!LOCAL_VER! esta atualizada.
            call :write_log "UPDATE" "UP_TO_DATE" "version=!LOCAL_VER!"
        )
    )
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

:: SEMPRE executar health check (verificar dependencias)
call :health_check

:: Se marker nao existe, mostrar setup inicial completo
if not exist "%FIRST_RUN%" goto :setup_initial
goto :start

:setup_initial

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

:: Configurar opencode.jsonc completo se nao existir ou estiver sem MCP
findstr /i "office-mcp" "%OPENCODE_CONFIG%" >nul 2>&1
if %errorlevel% neq 0 (
    echo Configurando opencode.jsonc com plugins e servidores MCP...
    set "MCP_OFFICE=%OPENCODE_HOME%scripts\office_mcp.py"
    set "MCP_PROJECT=%OPENCODE_HOME%scripts\project_generator.py"
    :: Converter barras para JSON (forward slashes)
    set "MCP_OFFICE=!MCP_OFFICE:\=/!"
    set "MCP_PROJECT=!MCP_PROJECT:\=/!"
    (
        echo {
        echo   "$schema": "https://opencode.ai/config.json",
        echo   "plugin": [
        echo     ["@renjfk/opencode-voice", {
        echo       "endpoint": "http://localhost:11434/v1",
        echo       "model": "llama3.2"
        echo     }],
        echo     "multitask",
        echo     "multitask-tui.tsx",
        echo     "workspace-tui.tsx",
        echo     "auto-switch-mode.ts"
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
    echo Configuracao completa atualizada!
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
    (
        echo {
        echo   "$schema": "https://opencode.ai/config.json",
        echo   "plugin": [
        echo     ["@renjfk/opencode-voice", {
        echo       "endpoint": "http://localhost:11434/v1",
        echo       "model": "llama3.2"
        echo     }],
        echo     "multitask",
        echo     "multitask-tui.tsx",
        echo     "workspace-tui.tsx",
        echo     "auto-switch-mode.ts"
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
    echo [OK] Caminhos MCP corrigidos para: %OPENCODE_HOME%
    call :write_log "CONFIG" "PATH_FIX" "home=!EXPECTED_MCP_FWD!"
)

:: Garantir que multitask-worktrees seja uma juncao limpa apontando para a pasta TEMP para evitar erro de recursao do multitask agent
if exist "multitask-worktrees" rmdir /s /q "multitask-worktrees"
if not exist "%TEMP%\opencode-worktrees" mkdir "%TEMP%\opencode-worktrees"
mklink /j "multitask-worktrees" "%TEMP%\opencode-worktrees" >nul 2>&1
set "OPENCODE_DISABLE_PROJECT_CONFIG=1"
call :write_log "LAUNCH" "START" "exe=opencode.exe"
echo [INFO] Iniciando opencode.exe...
if "%~1"=="" (
    "%OPENCODE_BIN%\opencode.exe" "%OPENCODE_HOME:~0,-1%"
) else (
    "%OPENCODE_BIN%\opencode.exe" %*
)
echo.
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
:: Sub-rotina: Health Check de Dependencias
:: Verifica e instala automaticamente o que faltar
:: Roda SEMPRE que o opencode.bat e executado
:: ============================================
:health_check
set "HEALTH_OK=1"

:: 1. Scoop
where scoop >nul 2>&1
if %errorlevel% neq 0 (
    echo [HEALTH] Scoop nao encontrado. Instalando...
    powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
    if !errorlevel! neq 0 (
        echo [HEALTH] ERRO: Falha ao instalar Scoop
        set "HEALTH_OK=0"
    ) else (
        set "PATH=%USERPROFILE%\scoop\shims;%PATH%"
        echo [HEALTH] OK: Scoop instalado
    )
)

:: 2. whisper-cpp
where whisper-cli >nul 2>&1
if %errorlevel% neq 0 (
    echo [HEALTH] whisper-cli nao encontrado. Instalando...
    call scoop install whisper-cpp
    if !errorlevel! neq 0 (
        echo [HEALTH] ERRO: Falha ao instalar whisper-cpp
        set "HEALTH_OK=0"
    ) else (
        echo [HEALTH] OK: whisper-cpp instalado
    )
)

:: 3. sox
where sox >nul 2>&1
if %errorlevel% neq 0 (
    echo [HEALTH] sox nao encontrado. Instalando...
    call scoop install sox
    if !errorlevel! neq 0 (
        echo [HEALTH] ERRO: Falha ao instalar sox
        set "HEALTH_OK=0"
    ) else (
        echo [HEALTH] OK: sox instalado
    )
)

:: 4. Modelo Whisper
if not exist "%MODELS_DIR%\ggml-base.bin" (
    echo [HEALTH] Modelo Whisper nao encontrado. Baixando...
    if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%"
    curl -L -o "%MODELS_DIR%\ggml-base.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
    if !errorlevel! neq 0 (
        echo [HEALTH] ERRO: Falha ao baixar modelo
        set "HEALTH_OK=0"
    ) else (
        echo [HEALTH] OK: Modelo Whisper baixado
    )
)

:: 5. Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [HEALTH] Python nao encontrado. Instalando...
    call scoop install python
    if !errorlevel! neq 0 (
        echo [HEALTH] ERRO: Falha ao instalar Python
        set "HEALTH_OK=0"
    ) else (
        echo [HEALTH] OK: Python instalado
    )
)

:: 6. Bibliotecas Python
python -c "import openpyxl, docx, pptx, mcp, win32com.client, psutil, formulas, msal, pdf2image, lxml" >nul 2>&1
if %errorlevel% neq 0 (
    echo [HEALTH] Bibliotecas Python incompletas. Instalando...
    python -m pip install --upgrade pip >nul 2>&1
    python -m pip install openpyxl python-docx python-pptx pywin32 mcp psutil formulas msal pdf2image lxml >nul 2>&1
    python -c "import openpyxl, docx, pptx, mcp, win32com.client, psutil, formulas, msal, pdf2image, lxml" >nul 2>&1
    if !errorlevel! neq 0 (
        echo [HEALTH] ERRO: Falha ao instalar bibliotecas
        set "HEALTH_OK=0"
    ) else (
        echo [HEALTH] OK: Bibliotecas Python instaladas
    )
)

:: 7. Azure CLI (opcional)
where az >nul 2>&1
if %errorlevel% neq 0 (
    echo [HEALTH] Azure CLI nao encontrado. Instalando...
    call scoop install azure-cli
    if !errorlevel! neq 0 (
        echo [HEALTH] AVISO: Falha ao instalar Azure CLI (opcional)
    ) else (
        echo [HEALTH] OK: Azure CLI instalado
    )
)

:: 8. Verificar Ollama (apenas informativo)
where ollama >nul 2>&1
if %errorlevel% neq 0 (
    echo [HEALTH] AVISO: Ollama nao encontrado (necessario para voz)
) else (
    echo [HEALTH] OK: Ollama
)

goto :eof
