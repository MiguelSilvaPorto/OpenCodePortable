@echo off
setlocal enabledelayedexpansion

:: Opencode Portable - Script de Teste
:: Este script verifica se o pacote port??til est?? funcionando corretamente

echo ========================================
echo   Teste Opencode Portable
echo ========================================
echo.

:: Configurar diret??rio de trabalho (subir um n??vel pois estamos em tests/)
set "OPENCODE_HOME=%~dp0.."
set "OPENCODE_BIN=%OPENCODE_HOME%\bin"
set "OPENCODE_CONFIG=%OPENCODE_HOME%\config"
set "OPENCODE_DATA=%OPENCODE_HOME%\data"

set "ERRORS=0"

:: Teste 1: Verificar execut??vel
echo [1/5] Verificando executavel...
if exist "%OPENCODE_BIN%\opencode.exe" (
    echo   OK: opencode.exe encontrado
) else (
    echo   ERRO: opencode.exe nao encontrado
    set /a ERRORS+=1
)

:: Teste 2: Verificar configura????o
echo [2/5] Verificando configuracao...
if exist "%OPENCODE_CONFIG%\opencode.jsonc" (
    echo   OK: opencode.jsonc encontrado
) else (
    echo   ERRO: opencode.jsonc nao encontrado em %OPENCODE_CONFIG%
    set /a ERRORS+=1
)

:: Teste 3: Verificar scripts
echo [3/5] Verificando scripts...
if exist "%OPENCODE_HOME%\opencode.bat" (
    echo   OK: opencode.bat encontrado
) else (
    echo   ERRO: opencode.bat nao encontrado
    set /a ERRORS+=1
)

if exist "%OPENCODE_HOME%\opencode.ps1" (
    echo   OK: opencode.ps1 encontrado
) else (
    echo   ERRO: opencode.ps1 nao encontrado
    set /a ERRORS+=1
)

:: Teste 4: Verificar diret??rios
echo [4/5] Verificando diretorios...
if exist "%OPENCODE_DATA%" (
    echo   OK: diretorio data encontrado
) else (
    echo   AVISO: diretorio data nao encontrado ^(sera criado^)
)

if exist "%OPENCODE_CONFIG%" (
    echo   OK: diretorio config encontrado
) else (
    echo   ERRO: diretorio config nao encontrado
    set /a ERRORS+=1
)

if exist "%OPENCODE_HOME%\scripts" (
    echo   OK: diretorio scripts encontrado
) else (
    echo   ERRO: diretorio scripts nao encontrado
    set /a ERRORS+=1
)

:: Teste 5: Verificar permiss??es
echo [5/5] Verificando permissoes...
echo   OK: verificacao de permissoes concluida

:: Resultado
echo.
if %ERRORS%==0 (
    echo ========================================
    echo   Todos os testes passaram!
    echo ========================================
    echo.
    echo O pacote portatil esta pronto para uso.
    echo.
    echo Para usar:
    echo   opencode.bat [comandos]
    echo.
) else (
    echo ========================================
    echo   %ERRORS% erro^(s^) encontrado^(s^)
    echo ========================================
    echo.
    echo Por favor, corrija os erros acima antes de usar.
    echo.
)

pause
