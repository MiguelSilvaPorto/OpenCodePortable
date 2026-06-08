@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   Instalador de Dependencias Office MCP
echo ========================================
echo.

:: Verificar se Python está instalado
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Python nao encontrado. Instalando Python via Scoop...
    call scoop install python
    if !errorlevel! neq 0 (
        echo [ERRO] Falha ao instalar o Python via Scoop. Por favor, instale o Python manualmente.
        pause
        exit /b 1
    )
) else (
    echo [OK] Python encontrado.
)

echo.
echo [1/2] Atualizando pip...
python -m pip install --upgrade pip

echo.
echo [2/2] Instalando bibliotecas de manipulacao de documentos e MCP...
python -m pip install openpyxl python-docx python-pptx pywin32 mcp

if !errorlevel! neq 0 (
    echo [ERRO] Falha ao instalar dependencias via pip.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Instalacao concluida com sucesso!
echo ========================================
echo.
if "%~1"=="" pause
