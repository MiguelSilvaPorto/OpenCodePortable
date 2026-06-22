function Update-OpenCodeConfig {
    param(
        [string]$OpenCodeHome,
        [string]$ConfigDir,
        [string]$LogDir
    )
    $updateScript = Join-Path $OpenCodeHome "scripts\update_config.js"
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node -and (Test-Path $updateScript)) {
        & node $updateScript $OpenCodeHome
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "CONFIG" -Event "UPDATED" -Context @{ file = Join-Path $ConfigDir "opencode.jsonc" } }
    } elseif (-not $node) {
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "CONFIG" -Event "NODE_MISSING" -Context @{ hint = "Node.js sera instalado na proxima execucao do setup" } -Level "WARN" }
    } else {
        Write-Error "[CONFIG] update_config.js nao encontrado"
    }
}

function Start-OpenCodeServices {
    param(
        [string]$OpenCodeHome,
        [string]$DataDir,
        [string]$ProjectPath,
        [string]$LogDir
    )
    # Brain monitor
    $brainDir = Join-Path $ProjectPath ".brain"
    $monitorPidFile = Join-Path $brainDir "monitor.pid"
    $monitorScript = Join-Path $brainDir "scripts\brain_monitor.py"
    if ((Test-Path $monitorScript) -and -not (Test-Path $monitorPidFile)) {
        $sessionFile = Join-Path $brainDir "current_session.txt"
        $sessionId = "default"
        if (Test-Path $sessionFile) { $sessionId = Get-Content $sessionFile -Raw }
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$monitorScript`" --session `"$sessionId`" --context 128000"
        Start-Process powershell.exe -ArgumentList $argList -WindowStyle Hidden
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "LAUNCH" -Event "BRAIN_MONITOR_STARTED" -Context @{ session = $sessionId } }
    }

    # NVIDIA Router
    $nvidiaScript = Join-Path $OpenCodeHome "scripts\nvidia_router.py"
    $nvidiaPidFile = Join-Path $DataDir "nvidia_router.pid"
    if ((Test-Path $nvidiaScript) -and -not (Test-Path $nvidiaPidFile)) {
        $python = Get-Command pythonw, python -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($python) {
            $nvidiaExe = if ($python.Name -eq "pythonw.exe") { "pythonw" } else { "python" }
            $proc = Start-Process -FilePath $nvidiaExe -ArgumentList "`"$nvidiaScript`"" -WindowStyle Hidden -PassThru
            $proc.Id | Out-File -FilePath $nvidiaPidFile -Encoding UTF8
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "LAUNCH" -Event "NVIDIA_ROUTER_STARTED" -Context @{ exe = $nvidiaExe; pid = $proc.Id } }
        }
    }
}

function Set-OpenCodeEnv {
    param([string]$OpenCodeHome, [string]$ConfigDir)
    $env:PATH = "$(Join-Path $OpenCodeHome 'bin');$env:PATH"
    $scoopShims = Join-Path $env:USERPROFILE "scoop\shims"
    if (Test-Path $scoopShims) { $env:PATH = "$scoopShims;$env:PATH" }
    $env:OPENCODE_CONFIG = Join-Path $ConfigDir "opencode.jsonc"
    $env:OPENCODE_DISABLE_PROJECT_CONFIG = "1"
    $env:OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true"
    $env:OPENCODE_EXPERIMENTAL_PLAN_MODE = "true"
}
