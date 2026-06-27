@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: build-installer.bat - Compila o instalador do OpenCode Portable via Inno Setup
:: ============================================================================
:: Uso:  build-installer.bat [nome_versao]
:: Ex:   build-installer.bat beta_v1_r18
:: ============================================================================

set "ISS_FILE=%~dp0opencode-installer.iss"
set "OUTPUT_DIR=%~dp0installers"

:: Verificar se o .iss existe
if not exist "%ISS_FILE%" (
    echo [ERRO] Arquivo nao encontrado: %ISS_FILE%
    pause
    exit /b 1
)

:: ============================================================================
:: 1. Procurar o compilador ISCC.exe
:: ============================================================================
set "ISCC="

:: Lugares comuns de instalacao do Inno Setup
set "ISCC_PATHS[0]=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
set "ISCC_PATHS[1]=%ProgramFiles%\Inno Setup 6\ISCC.exe"
set "ISCC_PATHS[2]=%ProgramFiles(x86)%\Inno Setup 5\ISCC.exe"
set "ISCC_PATHS[3]=%ProgramFiles%\Inno Setup 5\ISCC.exe"
set "ISCC_PATHS[4]=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"
set "ISCC_PATHS[5]=%LocalAppData%\Programs\Inno Setup 5\ISCC.exe"

for %%p in ("%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "%ProgramFiles%\Inno Setup 6\ISCC.exe" "%ProgramFiles(x86)%\Inno Setup 5\ISCC.exe" "%ProgramFiles%\Inno Setup 5\ISCC.exe" "%LocalAppData%\Programs\Inno Setup 6\ISCC.exe" "%LocalAppData%\Programs\Inno Setup 5\ISCC.exe") do (
    if exist %%p (
        set "ISCC=%%p"
        goto :FoundISCC
    )
)

:: Procurar no PATH
where ISCC.exe >nul 2>&1
if %errorlevel% equ 0 (
    set "ISCC=ISCC.exe"
    goto :FoundISCC
)

echo [ERRO] Inno Setup nao encontrado.
echo.
echo        Baixe e instale o Inno Setup em:
echo        https://jrsoftware.org/isdl.php
echo.
echo        Ou especifique o caminho manualmente:
echo        set "ISCC=C:\caminho\para\ISCC.exe"
echo        %~nx0
pause
exit /b 1

:FoundISCC
echo [OK] Compilador Inno Setup encontrado: %ISCC%
echo.

:: ============================================================================
:: 2. Determinar nome da versao
:: ============================================================================
set "VERSION=%~1"
if "%VERSION%"=="" (
    :: Tentar ler a versao do proprio EXE
    for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "& { try { $v = & '%~dp0bin\opencode.exe' --version 2>&1 | Select-Object -First 1; if ($v) { $v.Trim() } else { 'beta_v1' } } catch { 'beta_v1' } }"`) do set "VERSION=%%v"
)
if "%VERSION%"=="" set "VERSION=beta_v1"

:: Sanitizar: substituir espacos e pontos por underscore
set "VERSION=%VERSION: =.%"
set "VERSION=%VERSION: =_%"
set "VERSION=%VERSION:-=_%"

set "OUTPUT_NAME=OpenCodeSetup-%VERSION%"

echo ========================================
echo   Compilar Instalador OpenCode
echo ========================================
echo   Versao:     %VERSION%
echo   ISS:        %ISS_FILE%
echo   Saida:      %OUTPUT_DIR%\%OUTPUT_NAME%.exe
echo ========================================
echo.

:: ============================================================================
:: 3. Criar diretorio de saida
:: ============================================================================
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: ============================================================================
:: 4. Executar o compilador
:: ============================================================================
echo Compilando...
"%ISCC%" /Q "%ISS_FILE%" /dOutputBaseFilename="%OUTPUT_NAME%"
set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% equ 0 (
    echo ========================================
    echo   Instalador criado com sucesso!
    echo ========================================
    echo   Arquivo: %OUTPUT_DIR%\%OUTPUT_NAME%.exe
    echo.
    echo   Para distribuir, copie o arquivo acima.
    echo ========================================
) else (
    echo [ERRO] Falha na compilacao (codigo: %EXIT_CODE%).
    echo        Verifique o ISS e tente novamente.
)

echo.
pause
exit /b %EXIT_CODE%
