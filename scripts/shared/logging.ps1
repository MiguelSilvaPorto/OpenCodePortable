function Write-LogEntry {
    param(
        [string]$LogDir,
        [string]$Stage,
        [string]$Event,
        [hashtable]$Context = @{},
        [string]$Level = ""
    )
    $LOG_FILE = Join-Path $LogDir "launcher.jsonl"
    $LOG_LATEST = Join-Path $LogDir "launcher-latest.jsonl"
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    if ($Level -eq "") {
        if ($Event -match "FAILED|ERROR|ABORTED|EXCEPTION") { $Level = "ERROR" }
        elseif ($Event -match "SUCCESS|COMPLETED|OK|DONE|HIT") { $Level = "SUCCESS" }
        elseif ($Event -match "WARN|FALLBACK|RETRY|STALE|SKIP") { $Level = "WARN" }
        else { $Level = "INFO" }
    }
    $entry = [ordered]@{
        ts       = (Get-Date).ToString("o")
        level    = $Level
        stage    = $Stage
        event    = $Event
        context  = $Context
        pid      = $PID
    }
    $json = $entry | ConvertTo-Json -Depth 5 -Compress
    [System.IO.File]::AppendAllText($LOG_FILE, "$json`n", [System.Text.Encoding]::UTF8)
    if (Test-Path $LOG_LATEST) { Remove-Item $LOG_LATEST -Force }
    Copy-Item -Path $LOG_FILE -Destination $LOG_LATEST -Force
    $color = switch ($Level) {
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        default   { "Cyan" }
    }
    $ts = (Get-Date).ToString("HH:mm:ss")
    Write-Host "[$ts] [$Stage] $Event" -ForegroundColor $color
}

function Rotate-LogFiles {
    param([string]$LogDir)
    $MAX_SIZE = 10MB
    $MAX_FILES = 5
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    $LOG_FILE = Join-Path $LogDir "launcher.jsonl"
    if (Test-Path $LOG_FILE) {
        $size = (Get-Item $LOG_FILE).Length
        if ($size -gt $MAX_SIZE) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $rotated = Join-Path $LogDir "launcher-$timestamp.jsonl"
            Rename-Item -Path $LOG_FILE -NewName $rotated -Force
            $oldLogs = Get-ChildItem $LogDir -Filter "launcher-*.jsonl" |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -Skip $MAX_FILES
            foreach ($f in $oldLogs) { Remove-Item $f.FullName -Force }
        }
    }
}
