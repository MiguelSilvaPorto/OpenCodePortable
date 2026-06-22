param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)

$OPENCODE_HOME = Split-Path -Parent $MyInvocation.MyCommand.Path
$OPENCODE_BIN  = Join-Path $OPENCODE_HOME "bin"
$OPENCODE_DATA = Join-Path $OPENCODE_HOME "data"
$OPENCODE_CONFIG = Join-Path $OPENCODE_HOME "config"
$LOG_DIR       = Join-Path $OPENCODE_DATA "logs"
$CACHE_FILE    = Join-Path $OPENCODE_DATA "version.cache"

. (Join-Path $OPENCODE_HOME "scripts\shared\logging.ps1")
. (Join-Path $OPENCODE_HOME "scripts\shared\version.ps1")
. (Join-Path $OPENCODE_HOME "scripts\shared\setup.ps1")
. (Join-Path $OPENCODE_HOME "scripts\shared\env.ps1")

# Garantir diretorios
if (-not (Test-Path $OPENCODE_BIN))  { New-Item -ItemType Directory -Path $OPENCODE_BIN -Force | Out-Null }
if (-not (Test-Path $OPENCODE_DATA)) { New-Item -ItemType Directory -Path $OPENCODE_DATA -Force | Out-Null }
if (-not (Test-Path $OPENCODE_CONFIG)) { New-Item -ItemType Directory -Path $OPENCODE_CONFIG -Force | Out-Null }

# Iniciar logs
Rotate-LogFiles -LogDir $LOG_DIR
Write-LogEntry -LogDir $LOG_DIR -Stage "SYSTEM" -Event "ELECTRON_LAUNCHER_START" -Context @{
    ps_version = $PSVersionTable.PSVersion.ToString()
    pid = $PID
}

# 1. Verificar executavel
$exePath = Join-Path $OPENCODE_BIN "opencode.exe"
$exeStatus = Test-OpenCodeExe -ExePath $exePath

if ($exeStatus.valid) {
    Write-LogEntry -LogDir $LOG_DIR -Stage "SYSTEM" -Event "EXE_OK" -Context @{ version = $exeStatus.version; size = $exeStatus.size }
}
elseif ($exeStatus.exists -and -not $exeStatus.valid) {
    Write-LogEntry -LogDir $LOG_DIR -Stage "SYSTEM" -Event "EXE_INVALID" -Context @{ reason = $exeStatus.reason; size = $exeStatus.size } -Level "WARN"
    Remove-Item $exePath -Force -ErrorAction SilentlyContinue
    $version = Get-LatestVersion -CacheFile $CACHE_FILE -LogDir $LOG_DIR
    $downloaded = Download-OpenCodeExe -Version $version -BinDir $OPENCODE_BIN -LogDir $LOG_DIR
    if (-not $downloaded) {
        Write-LogEntry -LogDir $LOG_DIR -Stage "SYSTEM" -Event "FATAL" -Context @{ reason = "DOWNLOAD_FAILED" } -Level "ERROR"
        Write-Host "[ERRO] Nao foi possivel baixar o opencode.exe." -ForegroundColor Red
        Read-Host "Pressione Enter para sair"
        exit 1
    }
}
else {
    Write-LogEntry -LogDir $LOG_DIR -Stage "SYSTEM" -Event "EXE_MISSING" -Context @{ reason = "NOT_FOUND" }
    $version = Get-LatestVersion -CacheFile $CACHE_FILE -LogDir $LOG_DIR
    $downloaded = Download-OpenCodeExe -Version $version -BinDir $OPENCODE_BIN -LogDir $LOG_DIR
    if (-not $downloaded) {
        Write-LogEntry -LogDir $LOG_DIR -Stage "SYSTEM" -Event "FATAL" -Context @{ reason = "DOWNLOAD_FAILED" } -Level "ERROR"
        Write-Host "[ERRO] Nao foi possivel baixar o opencode.exe." -ForegroundColor Red
        Read-Host "Pressione Enter para sair"
        exit 1
    }
}

# 2. Setup inicial
$setupDone = Run-InitialSetup -OpenCodeHome $OPENCODE_HOME -DataDir $OPENCODE_DATA -ConfigDir $OPENCODE_CONFIG -LogDir $LOG_DIR

# 3. Atualizar config
Update-OpenCodeConfig -OpenCodeHome $OPENCODE_HOME -ConfigDir $OPENCODE_CONFIG -LogDir $LOG_DIR

# 4. Iniciar servicios em background
Set-OpenCodeEnv -OpenCodeHome $OPENCODE_HOME -ConfigDir $OPENCODE_CONFIG

# 5. Iniciar Electron
$electronDir = Join-Path $OPENCODE_HOME "TuiElectron"
if (-not (Test-Path (Join-Path $electronDir "node_modules"))) {
    Write-Host "[ELECTRON] Instalando dependencias..." -ForegroundColor Cyan
    Push-Location $electronDir
    & npm install
    Pop-Location
}

Write-LogEntry -LogDir $LOG_DIR -Stage "ELECTRON" -Event "LAUNCH" -Context @{ dir = $electronDir }
Write-Host ""
Write-Host "Iniciando OpenCode Desktop..." -ForegroundColor Green
Write-Host ""

Push-Location $electronDir
& npm run start
Pop-Location

Write-LogEntry -LogDir $LOG_DIR -Stage "SYSTEM" -Event "ELECTRON_EXIT"
