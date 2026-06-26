# Script de Automação de Compilação do Instalador do OpenCode

param (
    [string]$Version = ""
)

# 1. Localizar o compilador do Inno Setup (ISCC.exe)
$isccPath = ""
$searchPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    (Get-Command iscc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)

foreach ($path in $searchPaths) {
    if ($path -and (Test-Path $path)) {
        $isccPath = $path
        break
    }
}

if (-not $isccPath) {
    Write-Host "Compilador do Inno Setup (ISCC.exe) não foi encontrado no computador." -ForegroundColor Yellow
    $choice = Read-Host "Deseja instalar o Inno Setup automaticamente via winget agora? (S/N)"
    if ($choice -match "[sS]") {
        Write-Host "Instalando Inno Setup... Por favor, aguarde." -ForegroundColor Cyan
        winget install --id JRSoftware.InnoSetup -e -s winget --silent
        
        # Tenta localizar novamente
        $searchPaths = @(
            "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
            "C:\Program Files\Inno Setup 6\ISCC.exe",
            "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
        )
        foreach ($path in $searchPaths) {
            if (Test-Path $path) {
                $isccPath = $path
                break
            }
        }
    }
}

if (-not $isccPath -or -not (Test-Path $isccPath)) {
    Write-Error "Não foi possível prosseguir sem o Inno Setup. Instale-o manualmente e tente novamente."
    exit 1
}

Write-Host "Inno Setup encontrado em: $isccPath" -ForegroundColor Green

# 2. Solicitar versão se não fornecida por parâmetro
if (-not $Version) {
    $Version = Read-Host "Digite a versão para esta build (Ex: beta-v1, beta-v2, 1.0.0)"
    if (-not $Version) {
        $Version = "beta-v1"
    }
}

# Limpar o formato do nome da versão para nomes de arquivos seguros
$safeVersion = $Version -replace '[^a-zA-Z0-9_\-\.]', '_'

# 3. Compilar usando o ISCC e passar a versão como definição externa (/D)
Write-Host "Compilando instalador para a versão '$Version'..." -ForegroundColor Cyan

$installerFile = "d:\OpenCodePortable\opencode-installer.iss"
$outputName = "OpenCodeSetup-$safeVersion"

# Executar o compilador
& $isccPath /DMyAppVersion="$Version" /DOutputBaseFilename="$outputName" $installerFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "Sucesso! O instalador foi gerado em: installers\$outputName.exe" -ForegroundColor Green
} else {
    Write-Error "Ocorreu um erro ao compilar o instalador."
}
