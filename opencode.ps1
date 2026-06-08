# Opencode Portable - Script PowerShell
# Este script configura o ambiente para uso portátil

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)

# Configurar diretório de trabalho
$OpenCodeHome = Split-Path -Parent $MyInvocation.MyCommand.Path
$OpenCodeBin = Join-Path $OpenCodeHome "bin"
$OpenCodeConfig = Join-Path $OpenCodeHome "config"
$OpenCodeData = Join-Path $OpenCodeHome "data"

# Configurar variáveis de ambiente para portabilidade
$env:OPENCODE_DISABLE_PROJECT_CONFIG = "1"
$env:OPENCODE_CONFIG = Join-Path $OpenCodeConfig "opencode.jsonc"
$env:OPENCODE_HOME = $OpenCodeHome
$env:OPENCODE_DATA = $OpenCodeData

# Adicionar bin ao PATH
$env:PATH = "$OpenCodeBin;$env:PATH"

# Adicionar shims do Scoop ao PATH (necessario para whisper-cli, sox, etc.)
$ScoopShims = Join-Path $env:USERPROFILE "scoop\shims"
if (Test-Path $ScoopShims) {
    $env:PATH = "$ScoopShims;$env:PATH"
}

# Verificar se o executável existe
$OpenCodeExe = Join-Path $OpenCodeBin "opencode.exe"
if (-not (Test-Path $OpenCodeExe)) {
    Write-Error "ERRO: opencode.exe nao encontrado em $OpenCodeBin"
    exit 1
}

# Criar diretórios de dados se não existirem
if (-not (Test-Path $OpenCodeData)) {
    New-Item -ItemType Directory -Path $OpenCodeData -Force | Out-Null
}
if (-not (Test-Path $OpenCodeConfig)) {
    New-Item -ItemType Directory -Path $OpenCodeConfig -Force | Out-Null
}

# Iniciar opencode com configuração portátil
Write-Host "Iniciando Opencode Portable..." -ForegroundColor Green

if ($Arguments.Count -eq 0) {
    Write-Host ""
    Write-Host "Uso: .\opencode.ps1 [comandos]" -ForegroundColor Yellow
    Write-Host "Exemplo: .\opencode.ps1 chat 'Olá, mundo!'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Configuração portátil em: $OpenCodeConfig" -ForegroundColor Cyan
    Write-Host "Dados portáteis em: $OpenCodeData" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pressione Enter para continuar..." -ForegroundColor Gray
    Read-Host
} else {
    & $OpenCodeExe $Arguments
}