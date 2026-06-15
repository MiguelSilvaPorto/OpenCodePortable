@echo off
setlocal enabledelayedexpansion

:: Habilitar codificação UTF-8 no terminal ativo para suporte correto a caracteres especiais e ícones (ex.: microfone)
chcp 65001 >nul

:: Wrapper portátil: delega toda a inicializacao e execução robusta para o PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0opencode.ps1" %*
exit /b !errorlevel!
