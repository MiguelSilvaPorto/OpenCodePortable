function Ensure-Python {
    try {
        $ver = & python --version 2>&1
        if ($ver -match "^Python\s+\d") {
            $exe = & python -c "import sys; print(sys.executable)" 2>&1
            if ($exe -and -not ($exe -match "WindowsApps") -and (Test-Path $exe)) {
                return $true
            }
        }
    } catch {}
    Write-Host "  [PYTHON] Instalando Python 3.12..." -ForegroundColor Cyan
    $dataDir = Join-Path $PSScriptRoot "..\.." | Resolve-Path
    $installerDir = Join-Path $dataDir "data\installers"
    if (-not (Test-Path $installerDir)) { New-Item -ItemType Directory -Path $installerDir -Force | Out-Null }
    $pyPath = Join-Path $installerDir "python-installer.exe"
    if (-not (Test-Path $pyPath)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "  [PYTHON] Baixando Python 3.12.8..." -ForegroundColor Gray
        try {
            Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe" -OutFile $pyPath -UseBasicParsing -TimeoutSec 180
        } catch {
            Write-Host "  [PYTHON] Falha no download: $($_.Exception.Message)" -ForegroundColor Yellow
            return $false
        }
    }
    if (Test-Path $pyPath) {
        Write-Host "  [PYTHON] Instalando com privilegios admin..." -ForegroundColor Gray
        try {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& '$pyPath' /quiet InstallAllUsers=0 PrependPath=1 Include_test=0`"" -Verb RunAs -Wait
        } catch {
            Write-Host "  [PYTHON] Instalacao cancelada ou falhou." -ForegroundColor Yellow
            return $false
        }
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        $pyPaths = @(
            "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
            "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
            "$env:ProgramFiles\Python312\python.exe"
        )
        foreach ($p in $pyPaths) {
            if (Test-Path $p) {
                $env:Path = (Split-Path $p -Parent) + ";" + $env:Path
                break
            }
        }
    }
    try {
        $ver = & python --version 2>&1
        if ($ver -match "^Python\s+\d") {
            Write-Host "  [PYTHON] OK: $ver" -ForegroundColor Green
            return $true
        }
    } catch {}
    Write-Host "  [PYTHON] NAO instalado." -ForegroundColor Yellow
    return $false
}

function Run-InitialSetup {
    param(
        [string]$OpenCodeHome,
        [string]$DataDir,
        [string]$ConfigDir,
        [string]$LogDir
    )
    $FIRST_RUN_MARKER = Join-Path $DataDir ".voice-setup-done"
    $MODELS_DIR = Join-Path $DataDir "whisper-models"
    $configFile = Join-Path $ConfigDir "opencode.jsonc"

    $nodeInstalled = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
    $mcpInstalled = $false
    try { python -c "import mcp" 2>$null; $mcpInstalled = $LASTEXITCODE -eq 0 } catch {}
    if ((Test-Path $FIRST_RUN_MARKER) -and (Test-Path $configFile) -and $nodeInstalled -and $mcpInstalled) {
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "SKIPPED" -Context @{ reason = "Todos os componentes ja instalados"; marker = $FIRST_RUN_MARKER } }
        return $true
    }

    if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "START" @{} }

    $steps = @(
        @{
            name = "SCOOP"
            check = {
                if ($null -ne (Get-Command scoop -ErrorAction SilentlyContinue)) { return $true }
                $defaultScoopPath = Join-Path $env:USERPROFILE "scoop\shims\scoop.ps1"
                if (Test-Path $defaultScoopPath) { $env:PATH = "$(Join-Path $env:USERPROFILE 'scoop\shims');$env:PATH"; return $true }
                return $false
            }
            install = {
                Write-Host "  Instalando Scoop..." -ForegroundColor Gray
                try {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                    $installCmd = 'Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13; iex "& {$(irm get.scoop.sh)} -RunAsAdmin"'
                    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$installCmd`"" -Verb RunAs -Wait
                    $scoopShimPath = Join-Path $env:USERPROFILE "scoop\shims"
                    if (Test-Path $scoopShimPath) { $env:PATH = "$scoopShimPath;$env:PATH" }
                } catch { Write-Host "  [INFO] Instalacao do Scoop falhou: $($_.Exception.Message)" -ForegroundColor Yellow }
                $scoopInstalled = $null -ne (Get-Command scoop -ErrorAction SilentlyContinue)
                if (-not $scoopInstalled) {
                    Write-Host "  [AVISO] Scoop nao pode ser configurado automaticamente." -ForegroundColor Yellow
                } else { Write-Host "  [SCOOP] Scoop instalado com sucesso!" -ForegroundColor Green }
            }
        },
        @{
            name = "EXTRAS_BUCKET"
            check = { $null -ne (Get-Command scoop -ErrorAction SilentlyContinue) -and (scoop bucket list 2>$null | Select-String -Pattern "extras") }
            install = { scoop bucket add extras 2>$null }
        },
        @{
            name = "WHISPER_CPP"
            check = { $null -ne (Get-Command whisper-cli -ErrorAction SilentlyContinue) }
            install = { scoop install whisper-cpp 2>$null }
        },
        @{
            name = "SOX"
            check = { $null -ne (Get-Command sox -ErrorAction SilentlyContinue) }
            install = { scoop install sox 2>$null }
        },
        @{
            name = "WHISPER_MODEL"
            check = { Test-Path (Join-Path $MODELS_DIR "ggml-base.bin") }
            install = {
                if (-not (Test-Path $MODELS_DIR)) { New-Item -ItemType Directory -Path $MODELS_DIR -Force | Out-Null }
                Write-Host "  Baixando modelo Whisper (148MB)..." -ForegroundColor Gray
                try {
                    $url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
                    $output = Join-Path $MODELS_DIR "ggml-base.bin"
                    Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing -TimeoutSec 300
                } catch {
                    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
                    if ($curl) { & $curl.exe -L -o $output $url 2>$null }
                    else { Write-Host "  [AVISO] Falha ao baixar modelo Whisper" -ForegroundColor Yellow }
                }
            }
        },
        @{
            name = "WINGET"
            check = { $null -ne (Get-Command winget -ErrorAction SilentlyContinue) }
            install = {
                Write-Host "  Instalando winget..." -ForegroundColor Gray
                try {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $installerDir = Join-Path $DataDir "installers"
                    if (-not (Test-Path $installerDir)) { New-Item -ItemType Directory -Path $installerDir -Force | Out-Null }
                    $apiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
                    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -TimeoutSec 30
                    $asset = $release.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
                    if ($asset) {
                        $bundlePath = Join-Path $installerDir $asset.name
                        Write-Host "    Baixando winget ($($asset.name))..." -ForegroundColor Gray
                        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $bundlePath -UseBasicParsing -TimeoutSec 120
                        if (Test-Path $bundlePath) { Add-AppxPackage -Path $bundlePath -ErrorAction SilentlyContinue }
                    }
                } catch { Write-Host "  [INFO] Falha ao instalar winget. Continuando..." -ForegroundColor Gray }
            }
        },
        @{
            name = "WINDOWS_TERMINAL"
            check = {
                if ($null -ne (Get-Command wt -ErrorAction SilentlyContinue)) { return $true }
                if (Test-Path (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\wt.exe")) { return $true }
                return $false
            }
            install = {
                Write-Host "  Instalando Windows Terminal..." -ForegroundColor Gray
                $winget = Get-Command winget -ErrorAction SilentlyContinue
                if ($winget) {
                    try {
                        $proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"winget install Microsoft.WindowsTerminal --silent --accept-source-agreements --accept-package-agreements`"" -Verb RunAs -Wait -PassThru
                        if ($proc.ExitCode -eq 0) { Write-Host "    Windows Terminal instalado!" -ForegroundColor Green }
                    } catch { Write-Host "    [AVISO] UAC recusado: $($_.Exception.Message)" -ForegroundColor Yellow }
                }
            }
        },
        @{
            name = "NODEJS"
            check = { $null -ne (Get-Command node -ErrorAction SilentlyContinue) }
            install = {
                Write-Host "  Instalando Node.js..." -ForegroundColor Gray
                $nodeInstalled = $false
                try {
                    $installerDir = Join-Path $DataDir "installers"
                    if (-not (Test-Path $installerDir)) { New-Item -ItemType Directory -Path $installerDir -Force | Out-Null }
                    $installerPath = Join-Path $installerDir "node-installer.msi"
                    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    try {
                        $versions = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json" -UseBasicParsing -TimeoutSec 15
                        $latestLTS = $versions | Where-Object { $_.lts -ne $false } | Select-Object -First 1
                        $nodeVersion = if ($latestLTS) { $latestLTS.version } else { throw "API vazia" }
                        $nodeUrl = "https://nodejs.org/dist/$nodeVersion/node-$nodeVersion-$arch.msi"
                    } catch { $nodeUrl = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-$arch.msi" }
                    Invoke-WebRequest -Uri $nodeUrl -OutFile $installerPath -UseBasicParsing -TimeoutSec 180
                    if (Test-Path $installerPath) {
                        $proc = Start-Process msiexec -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait -PassThru
                        if ($proc.ExitCode -eq 1603) {
                            try { $proc = Start-Process msiexec -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait -PassThru -Verb RunAs } catch {}
                        }
                        $nodePaths = @("$env:ProgramFiles\nodejs\node.exe", "${env:ProgramFiles(x86)}\nodejs\node.exe", "$env:LOCALAPPDATA\Programs\nodejs\node.exe")
                        foreach ($p in $nodePaths) { if (Test-Path $p) { $nodeDir = Split-Path $p -Parent; $env:Path = "$nodeDir;$env:Path"; $nodeInstalled = $true; break } }
                        if (-not $nodeInstalled) {
                            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
                            $nodeInstalled = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
                        }
                    }
                } catch { Write-Host "    [INFO] Download falhou: $($_.Exception.Message)" -ForegroundColor Gray }

                if (-not $nodeInstalled) {
                    $winget = Get-Command winget -ErrorAction SilentlyContinue
                    if ($winget) {
                        try {
                            $wingetJob = Start-Job -ScriptBlock { & winget install OpenJS.NodeJS --silent --accept-package-agreements 2>$null }
                            $wingetResult = Wait-Job -Job $wingetJob -Timeout 60
                            if (-not $wingetResult) { Stop-Job -Job $wingetJob }
                            Remove-Job -Job $wingetJob -ErrorAction SilentlyContinue
                            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
                            $nodeInstalled = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
                        } catch {}
                    }
                }
                if (-not $nodeInstalled) {
                    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
                    if ($scoop) { & scoop install nodejs 2>$null; $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User"); $nodeInstalled = $null -ne (Get-Command node -ErrorAction SilentlyContinue) }
                }
                if ($nodeInstalled) { Write-Host "    Node.js instalado!" -ForegroundColor Green }
                else { Write-Host "  [INFO] Node.js nao instalado." -ForegroundColor Yellow }
            }
        },
        @{
            name = "PYTHON_DEPS"
            check = {
                try {
                    $ver = & python --version 2>&1
                    if (-not ($ver -match "^Python\s+\d")) { return $false }
                    python -c "import mcp" 2>$null; $LASTEXITCODE -eq 0
                } catch { return $false }
            }
            install = {
                Write-Host "  [DEPS] Instalando dependencias Python..." -ForegroundColor Cyan
                try {
                    $ver = & python --version 2>&1
                    if (-not ($ver -match "^Python\s+\d")) { Write-Host "  [DEPS] Python nao encontrado." -ForegroundColor Yellow; return }
                    Write-Host "  [DEPS] Python: $ver" -ForegroundColor Gray
                } catch { Write-Host "  [DEPS] Python nao encontrado." -ForegroundColor Yellow; return }
                python -m pip install --upgrade pip 2>&1 | Out-Null
                $packages = @("mcp", "openpyxl", "python-docx", "python-pptx", "psutil", "lxml")
                $ok = 0; $fail = 0
                foreach ($pkg in $packages) {
                    Write-Host "  [DEPS] Instalando $pkg..." -ForegroundColor Gray
                    $output = python -m pip install $pkg 2>&1 | Out-String
                    if ($output -match "Successfully installed|already satisfied") { Write-Host "  [DEPS]   $pkg OK" -ForegroundColor Green; $ok++ }
                    else { Write-Host "  [DEPS]   $pkg FALHA" -ForegroundColor Red; $fail++ }
                }
                Write-Host "  [DEPS] Resultado: $ok OK, $fail FALHA" -ForegroundColor Cyan
            }
        }
    )

    foreach ($step in $steps) {
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "STEP_START" -Context @{ step = $step.name } }
        try {
            $installed = & $step.check
            if (-not $installed) {
                if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "INSTALLING" -Context @{ step = $step.name } }
                & $step.install
                $installed = & $step.check
                if ($installed) { if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "STEP_OK" -Context @{ step = $step.name } } }
                else { if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "STEP_FAILED" -Context @{ step = $step.name } -Level "ERROR" } }
            } else { if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "STEP_SKIP" -Context @{ step = $step.name; reason = "ALREADY_INSTALLED" } } }
        }
        catch { if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "STEP_ERROR" -Context @{ step = $step.name; error = $_.Exception.Message } -Level "ERROR" } }
    }

    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollama) {
        $models = & ollama list 2>$null
        if ($null -eq ($models | Select-String "nomic-embed-text")) {
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "BRAIN" -Event "PULLING_EMBED" -Context @{ model = "nomic-embed-text" } }
            Start-Process ollama -ArgumentList "pull nomic-embed-text" -WindowStyle Hidden
        } else { if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "BRAIN" -Event "EMBED_OK" -Context @{ model = "nomic-embed-text" } } }
    } else { if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "BRAIN" -Event "OLLAMA_NOT_FOUND" -Context @{ hint = "Instale o Ollama em ollama.ai para busca vetorial" } -Level "WARN" } }

    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }

    $updateScript = Join-Path $OpenCodeHome "scripts\update_config.js"
    if (Test-Path $updateScript) {
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "CONFIG_WRITE" -Context @{ file = $configFile } }
        node $updateScript $OpenCodeHome
    } else { Write-Error "[CONFIG] update_config.js nao encontrado" }

    $pythonCheck = Get-Command python -ErrorAction SilentlyContinue
    $nodeCheck = Get-Command node -ErrorAction SilentlyContinue
    $depsCheck = $false
    try { python -c "import mcp" 2>$null; $depsCheck = $LASTEXITCODE -eq 0 } catch {}
    if ($pythonCheck -and $nodeCheck -and $depsCheck) {
        New-Item -ItemType File -Path $FIRST_RUN_MARKER -Force | Out-Null
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "COMPLETED" -Context @{ marker = $FIRST_RUN_MARKER } }
        Write-Host ""; Write-Host "============================================" -ForegroundColor Green
        Write-Host "  Configuracao Inicial Concluida!" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green; Write-Host ""
    } else {
        $missing = @()
        if (-not $pythonCheck) { $missing += "Python" }
        if (-not $nodeCheck) { $missing += "Node.js" }
        if (-not $depsCheck) { $missing += "dependencias MCP" }
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "SETUP" -Event "INCOMPLETE" -Context @{ reason = "Faltando: $($missing -join ', ')" } -Level "WARN" }
        Write-Host ""; Write-Host "============================================" -ForegroundColor Yellow
        Write-Host "  Configuracao Inicial INCOMPLETA!" -ForegroundColor Yellow
        Write-Host "============================================" -ForegroundColor Yellow
        Write-Host "  $($missing -join ' e ') nao foram instalados." -ForegroundColor Gray; Write-Host ""
    }
    return $true
}
