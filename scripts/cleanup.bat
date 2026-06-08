@echo off
setlocal enabledelayedexpansion

:: Opencode Portable - Script de Limpeza
:: Este script limpa dados temporários e cache

echo ========================================
echo   Limpeza Opencode Portable
echo ========================================
echo.

:: Configurar diretório de trabalho (subir um nível pois estamos em scripts/)
set "OPENCODE_HOME=%~dp0.."
set "OPENCODE_DATA=%OPENCODE_HOME%\data"

echo Diretorio de dados: %OPENCODE_DATA%
echo.

:: Perguntar se deseja limpar
set /p CLEAN_CONFIRM="Deseja limpar todos os dados temporarios? (S/N): "
if /i not "%CLEAN_CONFIRM%"=="S" (
    echo Operacao cancelada.
    pause
    exit /b 0
)

:: Criar backup dos dados importantes
echo Criando backup dos dados importantes...
if exist "%OPENCODE_DATA%\storage\session_diff" (
    if not exist "%OPENCODE_DATA%\backup" mkdir "%OPENCODE_DATA%\backup"
    xcopy "%OPENCODE_DATA%\storage\session_diff" "%OPENCODE_DATA%\backup\session_diff_%date:~-4%%date:~-7,2%%date:~-10,2%" /E /I /Q /Y >nul
)

:: Limpar cache
echo Limpando cache...
if exist "%OPENCODE_DATA%\cache" rd /s /q "%OPENCODE_DATA%\cache"
if exist "%OPENCODE_DATA%\tmp" rd /s /q "%OPENCODE_DATA%\tmp"

:: Limpar logs antigos
echo Limpando logs antigos...
if exist "%OPENCODE_DATA%\log" (
    forfiles /p "%OPENCODE_DATA%\log" /s /m *.log /d -30 /c "cmd /c del @path" 2>nul
)

:: Criar diretórios necessários
echo Recriando estrutura de diretorios...
if not exist "%OPENCODE_DATA%\storage\session_diff" mkdir "%OPENCODE_DATA%\storage\session_diff"
if not exist "%OPENCODE_DATA%\cache" mkdir "%OPENCODE_DATA%\cache"
if not exist "%OPENCODE_DATA%\log" mkdir "%OPENCODE_DATA%\log"
if not exist "%OPENCODE_DATA%\tmp" mkdir "%OPENCODE_DATA%\tmp"

echo.
echo ========================================
echo   Limpeza concluida!
echo ========================================
echo.
echo Backup salvo em: %OPENCODE_DATA%\backup
echo.
pause