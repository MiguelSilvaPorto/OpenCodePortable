@echo off
title Install Network Apps - IMCOPA
:: Launcher: detecta admin e roda o script principal com cmd /k
:: Se nao for admin, usa PowerShell para elevar UAC e abrir nova janela

:: Tenta rodar direto primeiro (caso ja seja admin)
net session >nul 2>&1
if %errorlevel% equ 0 (
    cmd /k "D:\install-network-apps.bat"
    exit /b
)

:: Nao e admin: eleva via PowerShell
:: A nova janela sera elevada e rodara o script com cmd /k (mantem aberta)
echo Solicitando privilegios de Administrador (UAC)...
echo Clique "Sim" no prompt do Windows.
powershell -Command "Start-Process cmd -ArgumentList '/k \"D:\install-network-apps.bat\"' -Verb RunAs -WindowStyle Normal"
exit /b
