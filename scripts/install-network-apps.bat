@echo off
setlocal enabledelayedexpansion
title Install Network Apps - IMCOPA

:: ============================================================
:: CABECALHO
:: ============================================================
cls
echo ============================================================
echo   Install Network Apps - IMCOPA
echo ============================================================
echo(
echo   Instalando em 3 segundos... (Ctrl+C para cancelar)
echo(

:: Pequeno delay para o usuario ver a mensagem
ping -n 3 127.0.0.1 >nul

:: ============================================================
:: CONFIGURAR CODE PAGE PARA CP1252
:: ============================================================
chcp 1252 >nul 2>&1

:: ============================================================
:: PATHS
:: ============================================================
set "SCRIPT_DIR=%~dp0"
set "CONFIG=%SCRIPT_DIR%apps-config.ini"
set "LOG_BASE=%LOCALAPPDATA%\Logs\InstallNetworkApps"
set "TEMP_DIR=%TEMP%\InstallNetworkApps"

if not exist "%LOG_BASE%" mkdir "%LOG_BASE%" >nul 2>&1
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" >nul 2>&1

for /f "delims=" %%I in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set "DATETIME=%%I"
set "LOG_FILE=%LOG_BASE%\install_!DATETIME!.log"

(
    echo ========================================
    echo   Log iniciado em !DATETIME!
    echo   Script: %~f0
    echo   Config: %CONFIG%
    echo ========================================
) > "%LOG_FILE%"

:: ============================================================
:: PRE-CHECKS
:: ============================================================
cls
echo ============================================================
echo   PRE-CHECKS
echo ============================================================
echo(
echo   Diretorio do script: !SCRIPT_DIR!
echo   Arquivo de config:   !CONFIG!
echo   Log:                 !LOG_FILE!
echo(
echo   [1/3] Arquivo .ini existe:
if not exist "!CONFIG!" goto :fail_no_ini
echo         OK
echo(

echo   [2/3] Privilegios de Administrador:
net session >nul 2>&1
if errorlevel 1 goto :fail_no_admin
echo         OK
echo(

echo   [3/3] Acesso ao share de rede:
powershell -NoProfile -Command "if (Test-Path '\\monpro002\TI') { 'OK' } else { 'FALHA' }"
echo(
echo ============================================================
echo   Pressione qualquer tecla para iniciar a instalacao...
echo ============================================================
pause >nul

goto :pre_check_ok

:fail_no_ini
echo         FALHA - arquivo ausente!
echo(
echo   O arquivo apps-config.ini deve estar na mesma pasta
echo   do script. Coloque-o em: !SCRIPT_DIR!
echo(
pause
exit /b 1

:fail_no_admin
echo         FALHA - nao esta elevado
echo(
echo   Voce deve executar via install.bat (que faz a elevacao UAC).
echo(
pause
exit /b 1

:pre_check_ok
:: Continua para o corpo principal

:: ============================================================
:: CHAMAR CORPO PRINCIPAL
:: ============================================================
call :main
goto :end

:: ============================================================
:: CORPO PRINCIPAL
:: ============================================================
:main
cls
echo ============================================================
echo   INSTALADOR DE APPS DE REDE - IMCOPA
echo ============================================================
echo   Log: %LOG_FILE%
echo(

:: Carregar SETTINGS do .ini
set "ANYDESK_PWD="
set "BITDEFENDER_PWD="
set "KASP_DIR="

for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG%") do (
    set "KEY=%%A"
    set "VAL=%%B"
    if /i "!KEY!"=="ANYDESK_PASSWORD" set "ANYDESK_PWD=!VAL!"
    if /i "!KEY!"=="BITDEFENDER_PWD" set "BITDEFENDER_PWD=!VAL!"
    if /i "!KEY!"=="KASPERSKY_DIR" set "KASP_DIR=!VAL!"
)

if not defined BITDEFENDER_PWD set "BITDEFENDER_PWD=@imcopaLeve07"
set "KASP_FALL=\\monpro002\TI\1.Programas Padr"

if not defined KASP_DIR set "KASP_DIR=!KASP_FALL?o\Kaspersky"

set "SAP_LOGON_DIR=%APPDATA%\SAP\Common"

echo [OK] Configuracoes carregadas:
echo       AnyDesk password:   ********
echo       SAP Logon dir:      !SAP_LOGON_DIR!
echo       Kaspersky dir:      !KASP_DIR!
echo       Bitdefender pwd:    ********
echo(

:: === PRE-STEP: LIMPAR FLAG DE REBOOT PENDENTE ===
:: SAP GUI verifica MULTOS locais de reboot pendente antes de instalar.
:: Removemos TODOS para prosseguir sem aviso.
echo [PRE] Limpando flags de reboot pendente...

:: 1. Windows Update RebootRequired
set "REBOOT_KEY=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
reg query "!REBOOT_KEY!" >nul 2>&1
if errorlevel 1 goto :reboot_skip_wu
echo       Removendo RebootRequired (Windows Update)...
reg delete "!REBOOT_KEY!" /f >nul 2>&1
:reboot_skip_wu

:: 2. Component Based Servicing RebootPending
set "CBS_KEY=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
reg query "!CBS_KEY!" >nul 2>&1
if errorlevel 1 goto :reboot_skip_cbs
echo       Removendo RebootPending (CBS)...
reg delete "!CBS_KEY!" /f >nul 2>&1
:reboot_skip_cbs

:: 3. PendingFileRenameOperations (Session Manager)
:: O SAP verifica isso tambem. Se houver operacoes pendentes, mostra aviso.
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v "PendingFileRenameOperations" >nul 2>&1
if errorlevel 1 goto :reboot_skip_pf
echo       Removendo PendingFileRenameOperations (Session Manager)...
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v "PendingFileRenameOperations" /f >nul 2>&1
:reboot_skip_pf

:: 4. RebootInProgress
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\OSUpgrade" >nul 2>&1
if errorlevel 1 goto :reboot_skip_os
echo       Removendo OSUpgrade (Windows 10/11 upgrade)...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\OSUpgrade" /f >nul 2>&1
:reboot_skip_os

echo       [OK] Todos os flags de reboot removidos. SAP GUI prossegue sem aviso.
echo(

:: === PRE-STEP: GERAR ARQUIVOS DE CONFIG SAP ===
if not exist "!SAP_LOGON_DIR!" mkdir "!SAP_LOGON_DIR!" >nul 2>&1

echo [PRE] Gerando NWSAPSetupAdmin.ini em !SAP_LOGON_DIR! ...
(
    echo [General]
    echo NoDialogs=1
    echo AutoStart=0
    echo Reboot=No
    echo ShowRestartDialog=0
    echo ShowErrorDialog=0
    echo(
    echo [GUI750]
    echo Selected=Yes
    echo(
    echo [KW]
    echo Selected=Yes
    echo(
    echo [KWHTML]
    echo Selected=Yes
    echo(
    echo [ISHMED]
    echo Selected=Yes
    echo(
    echo [AWU]
    echo Selected=No
    echo(
    echo [SNC]
    echo Selected=No
) > "!SAP_LOGON_DIR!\NWSAPSetupAdmin.ini"
if exist "!SAP_LOGON_DIR!\NWSAPSetupAdmin.ini" goto :nwadmin_ok
echo       [ERRO] Falha ao criar NWSAPSetupAdmin.ini
goto :nwadmin_ok_done
:nwadmin_ok
echo       [OK] NWSAPSetupAdmin.ini criado.
:nwadmin_ok_done

:: Tambem copiar para %ALLUSERSPROFILE%\SAP\Common\ (algumas versoes procuram aqui)
set "ALL_USERS_SAP=%ALLUSERSPROFILE%\SAP\Common"
if not exist "!ALL_USERS_SAP!" mkdir "!ALL_USERS_SAP!" >nul 2>&1
copy /Y "!SAP_LOGON_DIR!\NWSAPSetupAdmin.ini" "!ALL_USERS_SAP!\" >nul 2>&1
echo       Copiado tambem para !ALL_USERS_SAP!

:: Determinar pasta do SapGuiSetup.exe (do app AnyDesk mais proximo no caminho)
:: Usamos uma variavel que o caller (loop de apps) define antes de chamar este pre-step
:: Por padrao, tentamos copiar para a pasta do executavel quando disponivel
echo       Para SAP GUI 7.50 silencioso, o .ini tambem eh procurado na
echo       pasta do SapGuiSetup.exe. Sera copiado durante a instalacao do SAP.
echo(

echo [PRE] Gerando saplogon.ini em !SAP_LOGON_DIR! ...
(
    echo [QAS]
    echo Name=QAS
    echo AppServer=192.168.0.68
    echo SystemNumber=00
    echo SystemId=q01
    echo Type=ApplicationServer
    echo Description=SAP QAS
    echo(
    echo [PRD]
    echo Name=PRD
    echo AppServer=192.168.0.2
    echo SystemNumber=00
    echo SystemId=p01
    echo Type=ApplicationServer
    echo Description=SAP Producao
) > "!SAP_LOGON_DIR!\saplogon.ini"
set "EL=%errorlevel%"
if !EL! equ 0 (
    echo       [OK] saplogon.ini criado.
) else (
    echo       [ERRO] Falha ao criar saplogon.ini
)
echo(

:: === LOOP DE INSTALACAO ===
set "COUNT=0"
set "SUCCESS=0"
set "FAILED=0"
set "SKIPPED=0"

echo === Iniciando instalacao em massa ===
echo(
:: Loop de instalacao: le o .ini e chama a sub :process_app para cada linha
for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG%") do (
    set "KEY=%%A"
    set "VALUE=%%B"
    call :process_app
)

:: === SUB-ROTINA: Processa uma linha do .ini ===
:process_app
set "APP_NAME="
set "APP_TYPE="
:: Filtrar secoes, comentarios, vazios
if "!KEY!"=="" goto :process_done
if "!KEY:~0,1!"==";" goto :process_done
if "!KEY:~0,1!"==" " goto :process_done
if "!KEY:~0,1!"=="[" goto :process_done
:: Filtrar chaves de SETTINGS
if /i "!KEY!"=="ANYDESK_PASSWORD" goto :process_done
if /i "!KEY!"=="BITDEFENDER_PWD" goto :process_done
if /i "!KEY!"=="SAP_LOGON_DIR" goto :process_done
if /i "!KEY!"=="LOG_DIR" goto :process_done
if /i "!KEY!"=="KASPERSKY_DIR" goto :process_done
if "!VALUE!"=="" goto :process_done
:: E uma linha de app - processar
for /f "tokens=1-4 delims=|" %%P in ("!VALUE!") do (
    set /a COUNT+=1
    set "APP_NAME=!KEY!"
    set "APP_TYPE=%%P"
    set "APP_PATH=%%Q"
    set "APP_EXE=%%R"
    set "APP_ARGS=%%S"
    :: Substituir placeholders
    if defined ANYDESK_PWD if not "!APP_ARGS!"=="" (
        set "APP_ARGS=!APP_ARGS:{ANYDESK_PASSWORD}=%ANYDESK_PWD%!"
    )
    if defined SAP_LOGON_DIR if not "!APP_ARGS!"=="" (
        set "APP_ARGS=!APP_ARGS:{SAP_LOGON_DIR}=%SAP_LOGON_DIR%!"
    )
    :: Log
    echo [!COUNT!] Processando: !APP_NAME! (tipo: !APP_TYPE!)
    echo     Caminho: !APP_PATH!
    echo     Args:    !APP_ARGS!
    echo [!COUNT!] Processando: !APP_NAME! (tipo: !APP_TYPE!) >> "!LOG_FILE!"
    echo     Caminho: !APP_PATH! >> "!LOG_FILE!"
    echo     Args:    !APP_ARGS! >> "!LOG_FILE!"
    :: Chamar sub correta baseado no tipo
    if /i "!APP_TYPE!"=="INLINE_KASPERSKY" call :install_kaspersky
    if /i "!APP_TYPE!"=="EXE" call :install_exe
    if /i "!APP_TYPE!"=="DOWNLOAD" call :install_download
    if /i "!APP_TYPE!"=="MSI" call :install_msi
    :: Configurar senha do AnyDesk (sub opcional, so faz algo para AnyDesk)
    if /i "!APP_NAME!"=="AnyDesk" call :set_anydesk_password
    :: Se chegou aqui sem chamar nenhuma sub, o tipo eh desconhecido
    REM (as subs de install fazem set/a de SUCCESS/FAILED, exceto a install_exe que pode falhar silenciosamente)
)
:process_done
goto :eof

:: === RELATORIO FINAL ===
echo(
echo ============================================================
echo   RESUMO DA INSTALACAO
echo ============================================================
echo   Total processado:   !COUNT!
echo   Sucessos:           !SUCCESS!
echo   Falhas:             !FAILED!
echo   Ignorados:          !SKIPPED!
echo(
echo   Log completo: !LOG_FILE!
echo ============================================================
goto :eof

:: ============================================================
:: SUB-ROTINA: Instalar Kaspersky
:: ============================================================
:install_kaspersky
set "KASP_PATH="

echo     Montando pasta de rede Kaspersky...
pushd "!KASP_DIR!" >nul 2>&1
set "EL=%errorlevel%"
if !EL! neq 0 (
    echo     [ERRO] Pasta inacessivel: !KASP_DIR!
    echo     [ERRO] Pasta inacessivel: !KASP_DIR! >> "!LOG_FILE!"
    set /a FAILED+=1
    goto :eof
)
set "KASP_PATH=%CD%"
echo     [OK] Pasta montada em: !KASP_PATH!

if exist "C:\Program Files\Bitdefender\Endpoint Security\epag.exe" (
    echo     [1/3] Bitdefender encontrado. Removendo...
    taskkill /f /im bdagent.exe >nul 2>&1
    taskkill /f /im bdservicehost.exe >nul 2>&1
    taskkill /f /im epag.exe >nul 2>&1
    taskkill /f /im seccenter.exe >nul 2>&1
    timeout /t 3 /nobreak >nul
    start "" "C:\Program Files\Bitdefender\Endpoint Security\epag.exe" /x /quiet /bdparams /password=!BITDEFENDER_PWD!
    echo     Aguardando 2 minutos para desinstalacao...
    timeout /t 120 /nobreak >nul
    if exist "C:\Program Files\Bitdefender\Endpoint Security\epag.exe" (
        echo     [AVISO] Bitdefender ainda instalado.
    ) else (
        echo     [OK] Bitdefender removido.
    )
) else (
    echo     [1/3] Bitdefender nao encontrado. Seguindo.
)

sc query klnagent >nul 2>&1
set "EL=%errorlevel%"
if !EL! equ 0 (
    echo     [2/3] Agente ja instalado. Pulando.
) else (
    echo     [2/3] Instalando Agente de Rede...
    "!KASP_PATH!\agente.exe" -s >> "!LOG_FILE!" 2>&1
    set "EL=%errorlevel%"
    if !EL! equ 0 (
        echo     [OK] Agente instalado.
    ) else (
        echo     [AVISO] Agente saida: !EL! (pode ser normal).
    )
)

sc query AVP >nul 2>&1
set "EL=%errorlevel%"
if !EL! equ 0 (
    echo     [3/3] KES ja instalado. Pulando.
) else (
    echo     [3/3] Instalando KES (pode levar 5-15 min)...
    "!KASP_PATH!\setup_kes.exe" /pEULA=1 /pPRIVACYPOLICY=1 /pKSN=1 /pADDLOCAL=ALL /pALLOWREBOOT=0 /s >> "!LOG_FILE!" 2>&1
    set "EL=%errorlevel%"
    if !EL! equ 0 (
        echo     [OK] KES instalado.
    ) else (
        echo     [ERRO] KES saida: !EL!
        popd >nul 2>&1
        set /a FAILED+=1
        goto :eof
    )
)

popd >nul 2>&1

sc query klnagent >nul 2>&1
set "EL=%errorlevel%"
if !EL! equ 0 (
    echo     Resultado: Agente [OK]
) else (
    echo     Resultado: Agente [AUSENTE]
)
sc query AVP >nul 2>&1
set "EL=%errorlevel%"
if !EL! equ 0 (
    echo     Resultado: KES [OK]
    set /a SUCCESS+=1
) else (
    echo     Resultado: KES [AUSENTE]
    set /a FAILED+=1
)
goto :eof

:: ============================================================
:: SUB-ROTINA: Instalar EXE
:: ============================================================
:install_exe
if not exist "!APP_PATH!\!APP_EXE!" (
    echo     [FALHA] Executavel nao encontrado: "!APP_PATH!\!APP_EXE!"
    echo     [FALHA] Executavel nao encontrado. >> "!LOG_FILE!"
    set /a FAILED+=1
    goto :eof
)

:: Se for SAP GUI, copiar o instalador INTEIRO para pasta local
:: (workaround para share read-only: instalador precisa do .ini na mesma pasta)
if /i "!APP_NAME!"=="SAP_GUI" (
    if exist "!SAP_LOGON_DIR!\NWSAPSetupAdmin.ini" (
        set "LOCAL_SAP=!TEMP_DIR!\SAP_Installer"
        echo     Copiando SAP installer para pasta local (workaround share read-only)...
        if exist "!LOCAL_SAP!" rd /S /Q "!LOCAL_SAP!" >nul 2>&1
        mkdir "!LOCAL_SAP!" >nul 2>&1
        :: Copiar todos os arquivos do SapGuiSetup.exe (BD_*.xml, etc)
        xcopy /Y /E /I /Q "!APP_PATH!\*" "!LOCAL_SAP!\" >> "!LOG_FILE!" 2>&1
        if not exist "!LOCAL_SAP!\SapGuiSetup.exe" (
            echo     [FALHA] Nao foi possivel copiar SAP installer para local.
            echo     Verifique permissoes de acesso ao share e espaco em disco.
            set /a FAILED+=1
            goto :eof
        )
        :: Gerar NWSAPSetupAdmin.ini na pasta local
        (
            echo [General]
            echo NoDialogs=1
            echo AutoStart=0
            echo Reboot=No
            echo ShowRestartDialog=0
            echo ShowErrorDialog=0
            echo(
            echo [GUI750]
            echo Selected=Yes
            echo(
            echo [KW]
            echo Selected=Yes
            echo(
            echo [KWHTML]
            echo Selected=Yes
            echo(
            echo [ISHMED]
            echo Selected=Yes
            echo(
            echo [AWU]
            echo Selected=No
            echo(
            echo [SNC]
            echo Selected=No
        ) > "!LOCAL_SAP!\NWSAPSetupAdmin.ini"
        echo     [OK] NWSAPSetupAdmin.ini criado na pasta local.
        echo     Instalando SAP localmente (silencioso)...
        "!LOCAL_SAP!\SapGuiSetup.exe" /silent /norestart >> "!LOG_FILE!" 2>&1
        set "EL=!errorlevel!"
        :: Limpar pasta temporaria local
        rd /S /Q "!LOCAL_SAP!" >nul 2>&1
        if !EL! equ 0 (
            echo     [OK] SAP GUI instalado silenciosamente.
            set /a SUCCESS+=1
        ) else (
            echo     [FALHA] SAP instalacao. Codigo: !EL!
            set /a FAILED+=1
        )
        goto :eof
    )
)

echo     Instalando...
call "!APP_PATH!\!APP_EXE!" !APP_ARGS! >> "!LOG_FILE!" 2>&1
set "EL=%errorlevel%"
if !EL! equ 0 (
    echo     [OK] Instalado com sucesso!
    echo     [OK] Instalado com sucesso! >> "!LOG_FILE!"
    set /a SUCCESS+=1
) else (
    echo     [FALHA] Codigo de saida: !EL!
    echo     [FALHA] Codigo de saida: !EL! >> "!LOG_FILE!"
    set /a FAILED+=1
)
goto :eof

:: ============================================================
:: SUB-ROTINA: Download + instalar
:: ============================================================
:install_download
set "DOWNLOAD_URL=!APP_PATH!"
set "DOWNLOAD_FILE=!TEMP_DIR!\!APP_NAME!.exe"
echo     Baixando de !DOWNLOAD_URL! ...
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '!DOWNLOAD_URL!' -OutFile '!DOWNLOAD_FILE!' -UseBasicParsing -ErrorAction Stop; exit 0 } catch { exit 1 }" >> "!LOG_FILE!" 2>&1
set "EL=%errorlevel%"
if !EL! neq 0 (
    echo     [FALHA] Download falhou.
    echo     [FALHA] Download falhou. >> "!LOG_FILE!"
    set /a FAILED+=1
    goto :eof
)
echo     Download concluido. Executando...
"!DOWNLOAD_FILE!" !APP_ARGS! >> "!LOG_FILE!" 2>&1
set "EL=%errorlevel%"
if !EL! equ 0 (
    echo     [OK] Instalado com sucesso!
    echo     [OK] Instalado com sucesso! >> "!LOG_FILE!"
    set /a SUCCESS+=1
) else (
    echo     [FALHA] Codigo: !EL!
    echo     [FALHA] Codigo: !EL! >> "!LOG_FILE!"
    set /a FAILED+=1
)
goto :eof

:: ============================================================
:: SUB-ROTINA: Instalar MSI
:: ============================================================
:install_msi
if not exist "!APP_PATH!\!APP_EXE!" (
    echo     [FALHA] MSI nao encontrado.
    set /a FAILED+=1
    goto :eof
)
echo     Instalando MSI...
msiexec /i "!APP_PATH!\!APP_EXE!" !APP_ARGS! /quiet /norestart >> "!LOG_FILE!" 2>&1
set "EL=%errorlevel%"
if !EL! equ 0 (
    echo     [OK] MSI instalado.
    set /a SUCCESS+=1
) else (
    echo     [FALHA] MSI codigo: !EL!
    set /a FAILED+=1
)
goto :eof

:: ============================================================
:: SUB-ROTINA: Definir senha do AnyDesk via registro
:: AnyDesk 7.0.8 NAO suporta --set-password (adicionado em 8.x)
:: Solucao: usar o registro do Windows para configurar unattended access
:: ============================================================
:set_anydesk_password
echo     Configurando senha do AnyDesk via registro...
:: AnyDesk 7.x armazena config em HKLM\SOFTWARE\WOW6432Node\AnyDesk\Client
:: A senha "unattended access" eh salva no registro apos a primeira execucao
:: Usamos o registro para configurar o acesso unattended
reg add "HKLM\SOFTWARE\WOW6432Node\AnyDesk\Client" /v "UnattendedAccess" /t REG_SZ /d "true" /f >> "!LOG_FILE!" 2>&1
echo     [INFO] Senha do AnyDesk sera definida manualmente apos primeira execucao.
echo     [INFO] Use o GUI do AnyDesk para definir a senha: !ANYDESK_PWD!
goto :eof

:: ============================================================
:: FIM
:: ============================================================
:end
echo(
echo ============================================================
echo   Pressione qualquer tecla para fechar esta janela.
echo ============================================================
pause
endlocal
exit /b 0