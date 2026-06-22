function Select-Project {
    param(
        [string]$ProjectsRoot,
        [string]$ProvidedPath,
        [string]$LogDir
    )
    if ($ProvidedPath) {
        $resolved = Resolve-Path $ProvidedPath -ErrorAction SilentlyContinue
        if ($resolved -and (Test-Path $resolved.Path -PathType Container)) {
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "PROJECT" -Event "PROVIDED" -Context @{ path = $resolved.Path } }
            return $resolved.Path
        }
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "PROJECT" -Event "INVALID_PATH" -Context @{ provided = $ProvidedPath } -Level "WARN" }
    }
    if (-not (Test-Path $ProjectsRoot)) { New-Item -ItemType Directory -Path $ProjectsRoot -Force | Out-Null }
    $dirs = Get-ChildItem $ProjectsRoot -Directory -ErrorAction SilentlyContinue

    if ((-not $dirs -or $dirs.Count -eq 0) -and -not $ProvidedPath) {
        $defaultDir = Join-Path $ProjectsRoot "Default"
        if (-not (Test-Path $defaultDir)) {
            New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null
            Push-Location $defaultDir
            try { git init 2>$null | Out-Null; git commit --allow-empty -m "Initial commit" 2>$null | Out-Null } catch { }
            Pop-Location
            $wsDir = Join-Path $defaultDir ".opencode"
            if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir -Force | Out-Null }
            @{ mode = "local"; limitGB = 10 } | ConvertTo-Json | Set-Content (Join-Path $wsDir "workspace.json")
        }
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "PROJECT" -Event "DEFAULT_CREATED" -Context @{ path = $defaultDir } }
        return $defaultDir
    }

    if ($dirs.Count -eq 1) {
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "PROJECT" -Event "AUTO_SELECTED" -Context @{ name = $dirs[0].Name; path = $dirs[0].FullName } }
        return $dirs[0].FullName
    }

    while ($true) {
        $dirs = Get-ChildItem $ProjectsRoot -Directory -ErrorAction SilentlyContinue
        Clear-Host
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  OpenCode - Seletor de Projetos" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan; Write-Host ""
        if ($dirs -and $dirs.Count -gt 0) {
            Write-Host "Projetos Existentes:" -ForegroundColor White
            for ($i = 0; $i -lt $dirs.Count; $i++) { Write-Host "  [$($i + 1)] $($dirs[$i].Name)" -ForegroundColor White }
        }
        Write-Host ""; Write-Host "Opcoes:" -ForegroundColor White
        Write-Host "  [0] Criar Novo Projeto" -ForegroundColor Green
        Write-Host "  [Q] Sair" -ForegroundColor Red; Write-Host ""
        $choice = Read-Host "Escolha uma opcao"
        if ($choice -eq "q" -or $choice -eq "Q") { if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "PROJECT" -Event "EXIT" -Context @{ action = "USER_QUIT" } }; exit 0 }
        if ($choice -eq "0") {
            Write-Host ""; $newName = Read-Host "Digite o nome do novo projeto"
            if ([string]::IsNullOrWhiteSpace($newName)) { continue }
            $newName = $newName -replace '\s+', '_'
            $newDir = Join-Path $ProjectsRoot $newName
            if (Test-Path $newDir) { Write-Host "Ja existe um projeto com esse nome." -ForegroundColor Red; Start-Sleep -Seconds 2; continue }
            New-Item -ItemType Directory -Path $newDir -Force | Out-Null
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "PROJECT" -Event "CREATED" -Context @{ name = $newName; path = $newDir } }
            Write-Host "Inicializando Git local..." -ForegroundColor Gray
            Push-Location $newDir
            try { git init 2>$null | Out-Null; git commit --allow-empty -m "Initial commit" 2>$null | Out-Null } catch { }
            Pop-Location
            return $newDir
        }
        $idx = 0
        if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $dirs.Count) {
            $selected = $dirs[$idx - 1].FullName
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "PROJECT" -Event "SELECTED" -Context @{ name = $dirs[$idx - 1].Name; path = $selected } }
            return $selected
        }
        Write-Host "Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1
    }
}

function Ensure-BrainStructure {
    param(
        [string]$ProjectPath,
        [string]$OpenCodeHome,
        [string]$LogDir
    )
    $brainDir = Join-Path $ProjectPath ".brain"
    $sessionsDir = Join-Path $brainDir "sessions"
    $scriptsDir = Join-Path $brainDir "scripts"
    $gitignore = Join-Path $brainDir ".gitignore"
    $agentsMd = Join-Path $ProjectPath "AGENTS.md"
    $agentsSource = Join-Path $OpenCodeHome "AGENTS.md"

    if ((Test-Path $agentsSource) -and -not (Test-Path $agentsMd)) {
        Copy-Item -Path $agentsSource -Destination $agentsMd -Force
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "BRAIN" -Event "AGENTS_COPIED" -Context @{ path = $ProjectPath } }
    }

    if (-not (Test-Path $brainDir)) {
        New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        @"
*
!.gitignore
!scripts/
!scripts/**
!**/metadata.json
"@ | Set-Content -Path $gitignore -Encoding UTF8

        $brainScripts = @("brain_memory.py", "brain_mcp.py", "brain_checkpoint.py", "brain_monitor.py", "skill_mcp.py")
        foreach ($script in $brainScripts) {
            $scriptSource = Join-Path $OpenCodeHome ".brain\scripts\$script"
            $scriptDest = Join-Path $scriptsDir $script
            if ((Test-Path $scriptSource) -and -not (Test-Path $scriptDest)) { Copy-Item -Path $scriptSource -Destination $scriptDest -Force }
        }
        $mcpScripts = @("office_mcp.py", "project_generator.py")
        foreach ($script in $mcpScripts) {
            $scriptSource = Join-Path $OpenCodeHome "scripts\$script"
            $scriptDest = Join-Path $scriptsDir $script
            if ((Test-Path $scriptSource) -and -not (Test-Path $scriptDest)) { Copy-Item -Path $scriptSource -Destination $scriptDest -Force }
        }
        $skillsSource = Join-Path $OpenCodeHome ".brain\skills"
        $skillsDest = Join-Path $brainDir "skills"
        if ((Test-Path $skillsSource) -and -not (Test-Path $skillsDest)) { Copy-Item -Path $skillsSource -Destination $skillsDest -Recurse -Force }
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "BRAIN" -Event "STRUCTURE_CREATED" -Context @{ path = $brainDir } }
    }
}
