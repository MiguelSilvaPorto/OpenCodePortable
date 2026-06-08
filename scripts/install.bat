@echo off
setlocal enabledelayedexpansion

:: Opencode Portable - Script de Instalação
:: Este script configura o pacote portátil para uso

echo ========================================
echo   Instalador Opencode Portable
echo ========================================
echo.

:: Configurar diretório de trabalho (subir um nível pois estamos em scripts/)
set "OPENCODE_HOME=%~dp0.."
set "OPENCODE_BIN=%OPENCODE_HOME%\bin"
set "OPENCODE_CONFIG=%OPENCODE_HOME%\config"
set "OPENCODE_DATA=%OPENCODE_HOME%\data"

:: Verificar se o executável existe
if not exist "%OPENCODE_BIN%\opencode.exe" (
    echo ERRO: opencode.exe nao encontrado em %OPENCODE_BIN%
    echo Por favor, copie o executável para o diretorio bin.
    pause
    exit /b 1
)

:: Criar diretórios necessários
echo Criando estrutura de diretorios...
if not exist "%OPENCODE_CONFIG%" mkdir "%OPENCODE_CONFIG%"
if not exist "%OPENCODE_DATA%" mkdir "%OPENCODE_DATA%"

:: Criar arquivo de configuração padrão se não existir
if not exist "%OPENCODE_CONFIG%\opencode.jsonc" (
    echo Criando arquivo de configuracao padrao...
    echo { > "%OPENCODE_CONFIG%\opencode.jsonc"
    echo   "$schema": "https://opencode.ai/config.json" >> "%OPENCODE_CONFIG%\opencode.jsonc"
    echo } >> "%OPENCODE_CONFIG%\opencode.jsonc"
)

:: Criar atalho na área de trabalho (opcional)
set /p CREATE_SHORTCUT="Deseja criar um atalho na area de trabalho? (S/N): "
if /i "%CREATE_SHORTCUT%"=="S" (
    echo Criando atalho na area de trabalho...
    powershell -Command "$ws = New-Object -ComObject WScript.Shell; $shortcut = $ws.CreateShortcut('%USERPROFILE%\Desktop\Opencode Portable.lnk'); $shortcut.TargetPath = '%OPENCODE_HOME%\opencode.bat'; $shortcut.WorkingDirectory = '%OPENCODE_HOME%'; $shortcut.Save()"
)

echo.
echo ========================================
echo   Instalacao concluida!
echo ========================================
echo.
echo Para usar o Opencode Portable:
echo 1. Navegue ate o diretorio: %OPENCODE_HOME%
echo 2. Execute: opencode.bat
echo.
echo Ou crie um atalho na area de trabalho.
echo.
pause