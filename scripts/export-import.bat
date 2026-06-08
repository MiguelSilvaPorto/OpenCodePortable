@echo off
setlocal enabledelayedexpansion

:: Opencode Portable - Script de Exportação/Importação
:: Este script permite exportar e importar configurações

echo ========================================
echo   Exportar/Importar Configuracoes
echo ========================================
echo.

:: Configurar diretório de trabalho (subir um nível pois estamos em scripts/)
set "OPENCODE_HOME=%~dp0.."
set "OPENCODE_CONFIG=%OPENCODE_HOME%\config"
set "OPENCODE_DATA=%OPENCODE_HOME%\data"

:: Menu de opções
echo 1. Exportar configuracoes
echo 2. Importar configuracoes
echo 3. Sair
echo.
set /p OPTION="Selecione uma opcao (1-3): "

if "%OPTION%"=="1" goto EXPORT
if "%OPTION%"=="2" goto IMPORT
if "%OPTION%"=="3" goto EXIT
echo Opcao invalida!
pause
goto :eof

:EXPORT
echo.
echo Exportando configuracoes...
set "EXPORT_DIR=%OPENCODE_HOME%\export_%date:~-4%%date:~-7,2%%date:~-10,2%"
mkdir "%EXPORT_DIR%" 2>nul

:: Copiar configurações
xcopy "%OPENCODE_CONFIG%" "%EXPORT_DIR%\config" /E /I /Q /Y >nul

:: Copiar dados importantes
if exist "%OPENCODE_DATA%\storage\session_diff" (
    xcopy "%OPENCODE_DATA%\storage\session_diff" "%EXPORT_DIR%\session_diff" /E /I /Q /Y >nul
)

:: Criar arquivo de manifesto
echo { > "%EXPORT_DIR%\manifest.json"
echo   "export_date": "%date% %time%", >> "%EXPORT_DIR%\manifest.json"
echo   "version": "1.0" >> "%EXPORT_DIR%\manifest.json"
echo } >> "%EXPORT_DIR%\manifest.json"

echo.
echo Configuracoes exportadas para: %EXPORT_DIR%
echo.
pause
goto :eof

:IMPORT
echo.
echo Importando configuracoes...
set /p IMPORT_DIR="Digite o caminho do diretorio de importacao: "

if not exist "%IMPORT_DIR%" (
    echo ERRO: Diretorio nao encontrado!
    pause
    goto :eof
)

:: Fazer backup das configurações atuais
echo Criando backup das configuracoes atuais...
set "BACKUP_DIR=%OPENCODE_HOME%\backup_%date:~-4%%date:~-7,2%%date:~-10,2%"
mkdir "%BACKUP_DIR%" 2>nul
xcopy "%OPENCODE_CONFIG%" "%BACKUP_DIR%\config" /E /I /Q /Y >nul

:: Importar configurações
echo Importando novas configuracoes...
xcopy "%IMPORT_DIR%\config" "%OPENCODE_CONFIG%" /E /I /Q /Y >nul

:: Importar dados se existirem
if exist "%IMPORT_DIR%\session_diff" (
    if not exist "%OPENCODE_DATA%\storage\session_diff" mkdir "%OPENCODE_DATA%\storage\session_diff"
    xcopy "%IMPORT_DIR%\session_diff" "%OPENCODE_DATA%\storage\session_diff" /E /I /Q /Y >nul
)

echo.
echo Configuracoes importadas com sucesso!
echo Backup salvo em: %BACKUP_DIR%
echo.
pause
goto :eof

:EXIT
exit /b 0