@echo off
setlocal enabledelayedexpansion

:: Opencode Portable - Script de Empacotamento
:: Este script cria um arquivo ZIP com o pacote portátil

echo ========================================
echo   Empacotar Opencode Portable
echo ========================================
echo.

:: Configurar diretório de trabalho (subir um nível pois estamos em scripts/)
set "OPENCODE_HOME=%~dp0.."

set "OUTPUT_FILE=%OPENCODE_HOME%\opencode-portable.zip"

:: Verificar se o PowerShell está disponível
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERRO: PowerShell nao encontrado!
    pause
    exit /b 1
)

:: Criar arquivo ZIP
echo Criando arquivo ZIP...
powershell -Command "Compress-Archive -Path '%OPENCODE_HOME%\bin', '%OPENCODE_HOME%\config', '%OPENCODE_HOME%\scripts', '%OPENCODE_HOME%\tests', '%OPENCODE_HOME%\opencode.bat', '%OPENCODE_HOME%\opencode.ps1', '%OPENCODE_HOME%\README.md' -DestinationPath '%OUTPUT_FILE%' -Force"

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================
    echo   Arquivo ZIP criado com sucesso!
    echo ========================================
    echo.
    echo Arquivo: %OUTPUT_FILE%
    echo.
    echo Para distribuir:
    echo 1. Copie o arquivo ZIP para o destino
    echo 2. Extraia o conteudo
    echo 3. Execute: scripts\install.bat
    echo.
) else (
    echo ERRO: Falha ao criar arquivo ZIP!
)

pause