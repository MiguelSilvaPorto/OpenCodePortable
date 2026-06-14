# ============================================================================
# OpenCode Portable - Orquestrador Principal (PowerShell)
# ============================================================================
# Arquivo: opencode.ps1
# Descricao: Launcher completo com:
#   - Sistema de logs JSONL (AI-readable)
#   - Verificacao inteligente do executavel
#   - Busca de versao latest (cache 24h + GitHub API + fallback)
#   - Download robusto com retry e verificacao de integridade
#   - Setup inicial idempotente (Scoop, whisper, sox, Python, deps Office)
#   - Seletor de projetos interativo
# ============================================================================

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)

# ============================================================================
# CONSTANTES
# ============================================================================

$OPENCODE_HOME     = Split-Path -Parent $MyInvocation.MyCommand.Path
$OPENCODE_BIN      = Join-Path $OPENCODE_HOME "bin"
$OPENCODE_DATA     = Join-Path $OPENCODE_HOME "data"
$OPENCODE_CONFIG   = Join-Path $OPENCODE_HOME "config"
$PROJECTS_ROOT     = Join-Path $OPENCODE_HOME "Projects"
$CACHE_FILE        = Join-Path $OPENCODE_DATA "version.cache"
$FIRST_RUN_MARKER  = Join-Path $OPENCODE_DATA ".voice-setup-done"
$LOG_DIR           = Join-Path $OPENCODE_DATA "logs"
$LOG_FILE          = Join-Path $LOG_DIR "launcher.jsonl"
$LOG_LATEST        = Join-Path $LOG_DIR "launcher-latest.jsonl"
$MODELS_DIR        = Join-Path $OPENCODE_DATA "whisper-models"
$MIN_EXE_SIZE      = 10MB
$MIN_ZIP_SIZE      = 5MB
$CACHE_TTL_HOURS   = 24
$MAX_RETRIES       = 3
$FALLBACK_VERSION  = "1.17.1"
$GITHUB_REPO       = "anomalyco/opencode"
$LOG_MAX_SIZE      = 10MB
$LOG_MAX_FILES     = 5
$TIMEOUT_DOWNLOAD  = 120
$TIMEOUT_API       = 15

# ============================================================================
# SISTEMA DE LOGS JSONL (AI-Readable)
# ============================================================================

function Ensure-LogDir {
    if (-not (Test-Path $LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    }
}

function Rotate-Logs {
    Ensure-LogDir
    if (Test-Path $LOG_FILE) {
        $size = (Get-Item $LOG_FILE).Length
        if ($size -gt $LOG_MAX_SIZE) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $rotated = Join-Path $LOG_DIR "launcher-$timestamp.jsonl"
            Rename-Item -Path $LOG_FILE -NewName $rotated -Force
            # Limpar arquivos antigos (manter max)
            $oldLogs = Get-ChildItem $LOG_DIR -Filter "launcher-*.jsonl" |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -Skip $LOG_MAX_FILES
            foreach ($f in $oldLogs) { Remove-Item $f.FullName -Force }
        }
    }
}

function Write-Log {
    param(
        [string]$Stage,
        [string]$Event,
        [hashtable]$Context = @{},
        [string]$Level = ""
    )

    Ensure-LogDir

    # Determinar level automaticamente
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

    # Escrever no arquivo principal
    [System.IO.File]::AppendAllText($LOG_FILE, "$json`n", [System.Text.Encoding]::UTF8)

    # Atualizar symlink do latest
    if (Test-Path $LOG_LATEST) { Remove-Item $LOG_LATEST -Force }
    Copy-Item -Path $LOG_FILE -Destination $LOG_LATEST -Force

    # Console colorido
    $color = switch ($Level) {
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        default   { "Cyan" }
    }
    $ts = (Get-Date).ToString("HH:mm:ss")
    Write-Host "[$ts] [$Stage] $Event" -ForegroundColor $color
}

# ============================================================================
# VERIFICACAO INTELIGENTE DO EXECUTAVEL
# ============================================================================

function Test-OpenCodeExe {
    param([string]$ExePath)

    if (-not (Test-Path $ExePath)) {
        return @{ exists = $false; valid = $false; reason = "NOT_FOUND" }
    }

    $item = Get-Item $ExePath
    $size = $item.Length

    if ($size -lt $MIN_EXE_SIZE) {
        return @{ exists = $true; valid = $false; reason = "TOO_SMALL"; size = $size; expected_min = $MIN_EXE_SIZE }
    }

    # Testar execucao
    try {
        $version = & $ExePath --version 2>&1 | Select-Object -First 1
        if ($version -match '(\d+\.\d+\.\d+)') {
            return @{ exists = $true; valid = $true; version = $Matches[1]; size = $size }
        }
        return @{ exists = $true; valid = $false; reason = "VERSION_PARSE_FAIL"; size = $size }
    }
    catch {
        return @{ exists = $true; valid = $false; reason = "EXEC_FAILED"; error = $_.Exception.Message; size = $size }
    }
}

# ============================================================================
# BUSCA DE VERSAO (Cache + GitHub API + Fallback)
# ============================================================================

function Get-LatestVersion {
    # 1. Verificar cache
    if (Test-Path $CACHE_FILE) {
        try {
            $cache = Get-Content $CACHE_FILE -Raw | ConvertFrom-Json
            $age = (Get-Date) - [datetime]$cache.timestamp
            if ($age.TotalHours -lt $CACHE_TTL_HOURS) {
                Write-Log "VERSION" "CACHE_HIT" @{ version = $cache.version; age_hours = [math]::Round($age.TotalHours, 1) }
                return $cache.version
            }
            Write-Log "VERSION" "CACHE_STALE" @{ version = $cache.version; age_hours = [math]::Round($age.TotalHours, 1) } "WARN"
        }
        catch {
            Write-Log "VERSION" "CACHE_CORRUPT" @{ error = $_.Exception.Message } "WARN"
        }
    }

    # 2. GitHub API com retry
    for ($attempt = 1; $attempt -le $MAX_RETRIES; $attempt++) {
        try {
            Write-Log "VERSION" "API_REQUEST" @{ attempt = $attempt; max = $MAX_RETRIES }
            $headers = @{ Accept = "application/vnd.github.v3+json" }
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GITHUB_REPO/releases/latest" -Headers $headers -TimeoutSec $TIMEOUT_API
            $version = $response.tag_name -replace '^v', ''

            # Salvar cache
            $cacheData = @{ version = $version; timestamp = (Get-Date).ToString("o") }
            $cacheData | ConvertTo-Json -Depth 3 | Set-Content -Path $CACHE_FILE -Encoding UTF8
            Write-Log "VERSION" "API_SUCCESS" @{ version = $version; attempt = $attempt }
            return $version
        }
        catch {
            $delay = [math]::Pow(2, $attempt)
            Write-Log "VERSION" "API_FAILED" @{ attempt = $attempt; error = $_.Exception.Message; next_retry_in = "${delay}s" } "WARN"
            if ($attempt -lt $MAX_RETRIES) { Start-Sleep -Seconds $delay }
        }
    }

    # 3. Fallback
    Write-Log "VERSION" "FALLBACK_USED" @{ version = $FALLBACK_VERSION; reason = "API_FAILED_ALL_RETRIES" } "WARN"
    return $FALLBACK_VERSION
}

# ============================================================================
# DOWNLOAD ROBUSTO COM VERIFICACAO
# ============================================================================

function Download-OpenCodeExe {
    param([string]$Version)

    $url = "https://github.com/$GITHUB_REPO/releases/download/v$Version/opencode-windows-x64.zip"
    $zipPath = Join-Path $OPENCODE_BIN "opencode.zip"
    $exePath = Join-Path $OPENCODE_BIN "opencode.exe"

    if (-not (Test-Path $OPENCODE_BIN)) {
        New-Item -ItemType Directory -Path $OPENCODE_BIN -Force | Out-Null
    }

    for ($attempt = 1; $attempt -le $MAX_RETRIES; $attempt++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Log "DOWNLOAD" "START" @{ url = $url; attempt = $attempt; max = $MAX_RETRIES }

        try {
            # TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Download
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($url, $zipPath)
            $sw.Stop()

            # Verificar tamanho
            $bytes = (Get-Item $zipPath).Length
            if ($bytes -lt $MIN_ZIP_SIZE) {
                throw "ZIP muito pequeno: $bytes bytes (esperado > $MIN_ZIP_SIZE)"
            }

            Write-Log "DOWNLOAD" "COMPLETED" @{ bytes = $bytes; duration_ms = $sw.ElapsedMilliseconds; attempt = $attempt }

            # Extrair
            Write-Log "EXTRACT" "START" @{ zip = $zipPath; dest = $OPENCODE_BIN }
            Expand-Archive -Path $zipPath -DestinationPath $OPENCODE_BIN -Force
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

            # Verificar executavel resultante
            $verify = Test-OpenCodeExe $exePath
            if ($verify.valid) {
                Write-Log "EXTRACT" "SUCCESS" @{ version = $verify.version; size = $verify.size; duration_ms = $sw.ElapsedMilliseconds }
                return $true
            }
            else {
                Write-Log "EXTRACT" "VERIFY_FAILED" @{ reason = $verify.reason; size = $verify.size } "ERROR"
                if (Test-Path $exePath) { Remove-Item $exePath -Force }
            }
        }
        catch {
            $sw.Stop()
            $retry = $attempt -lt $MAX_RETRIES
            Write-Log "DOWNLOAD" "FAILED" @{ error = $_.Exception.Message; attempt = $attempt; duration_ms = $sw.ElapsedMilliseconds; retry = $retry } "ERROR"
            if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
            if ($retry) { Start-Sleep -Seconds (5 * $attempt) }
        }
    }

    Write-Log "DOWNLOAD" "ABORTED" @{ reason = "MAX_RETRIES_EXCEEDED"; max = $MAX_RETRIES } "ERROR"
    return $false
}

# ============================================================================
# SETUP INICIAL (Idempotente)
# ============================================================================

function Run-InitialSetup {
    $configFile = Join-Path $OPENCODE_CONFIG "opencode.jsonc"
    if ((Test-Path $FIRST_RUN_MARKER) -and (Test-Path $configFile)) {
        Write-Log "SETUP" "SKIPPED" @{ reason = "MARKER_AND_CONFIG_EXIST"; marker = $FIRST_RUN_MARKER }
        return $true
    }

    Write-Log "SETUP" "START" @{}

    $steps = @(
        @{
            name = "SCOOP"
            check = { $null -ne (Get-Command scoop -ErrorAction SilentlyContinue) }
            install = {
                Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
            }
        },
        @{
            name = "EXTRAS_BUCKET"
            check = { scoop bucket list 2>$null | Select-String -Pattern "extras" }
            install = { scoop bucket add extras }
        },
        @{
            name = "WHISPER_CPP"
            check = { $null -ne (Get-Command whisper-cli -ErrorAction SilentlyContinue) }
            install = { scoop install whisper-cpp }
        },
        @{
            name = "SOX"
            check = { $null -ne (Get-Command sox -ErrorAction SilentlyContinue) }
            install = { scoop install sox }
        },
        @{
            name = "WHISPER_MODEL"
            check = { Test-Path (Join-Path $MODELS_DIR "ggml-base.bin") }
            install = {
                if (-not (Test-Path $MODELS_DIR)) { New-Item -ItemType Directory -Path $MODELS_DIR -Force | Out-Null }
                curl -L -o (Join-Path $MODELS_DIR "ggml-base.bin") "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
            }
        },
        @{
            name = "PYTHON"
            check = { $null -ne (Get-Command python -ErrorAction SilentlyContinue) }
            install = { scoop install python }
        },
        @{
            name = "PYTHON_DEPS"
            check = {
                python -c "import openpyxl, docx, pptx, mcp, win32com.client" 2>$null
                $LASTEXITCODE -eq 0
            }
            install = {
                python -m pip install --upgrade pip 2>$null
                python -m pip install openpyxl python-docx python-pptx pywin32 mcp 2>$null
            }
        }
    )

    foreach ($step in $steps) {
        Write-Log "SETUP" "STEP_START" @{ step = $step.name }
        try {
            $installed = & $step.check
            if (-not $installed) {
                Write-Log "SETUP" "INSTALLING" @{ step = $step.name }
                & $step.install
                # Verificar novamente
                $installed = & $step.check
                if ($installed) {
                    Write-Log "SETUP" "STEP_OK" @{ step = $step.name }
                }
                else {
                    Write-Log "SETUP" "STEP_FAILED" @{ step = $step.name; error = "Post-install check failed" } "ERROR"
                    # Nao abortar - setup continua (steps sao independentes)
                }
            }
            else {
                Write-Log "SETUP" "STEP_SKIP" @{ step = $step.name; reason = "ALREADY_INSTALLED" }
            }
        }
        catch {
            Write-Log "SETUP" "STEP_ERROR" @{ step = $step.name; error = $_.Exception.Message } "ERROR"
        }
    }

    # Garantir que a pasta config existe
    if (-not (Test-Path $OPENCODE_CONFIG)) {
        New-Item -ItemType Directory -Path $OPENCODE_CONFIG -Force | Out-Null
    }

    $mcpScriptPath = Join-Path $OPENCODE_HOME "scripts\office_mcp.py"
    $mcpScriptPathJson = $mcpScriptPath -replace '\\', '/'

    $projectMcpScriptPath = Join-Path $OPENCODE_HOME "scripts\project_generator.py"
    $projectMcpScriptPathJson = $projectMcpScriptPath -replace '\\', '/'

    $endpoint = "http://localhost:11434/v1"
    $model = "llama3.2"
    $apiKey = $null

    if ($env:GROQ_API_KEY) {
        $endpoint = "https://api.groq.com/openai/v1"
        $model = "llama3-8b-8192"
        $apiKey = $env:GROQ_API_KEY
        Write-Log "SETUP" "GROQ_DETECTED" @{ model = $model }
    } else {
        Write-Log "SETUP" "OLLAMA_FALLBACK" @{ model = $model }
    }

    $voiceConfig = [ordered]@{
        "endpoint" = $endpoint
        "model" = $model
    }
    if ($apiKey) {
        $voiceConfig.Add("apiKey", $apiKey)
    }

    Write-Log "SETUP" "CONFIG_WRITE" @{ file = $configFile; office_mcp_path = $mcpScriptPathJson; project_mcp_path = $projectMcpScriptPathJson }
    
    $configObj = [ordered]@{
        "`$schema" = "https://opencode.ai/config.json"
        "plugin" = @(
            @(
                "@renjfk/opencode-voice",
                $voiceConfig
            ),
            "multitask",
            "multitask-tui.tsx",
            "workspace-tui.tsx",
            "auto-switch-mode.ts"
        )
        "mcp" = [ordered]@{
            "office-mcp" = [ordered]@{
                "type" = "local"
                "command" = @("python", $mcpScriptPathJson)
                "enabled" = $true
            }
            "project-mcp" = [ordered]@{
                "type" = "local"
                "command" = @("python", $projectMcpScriptPathJson)
                "enabled" = $true
            }
        }
    }
    
    $configObj | ConvertTo-Json -Depth 10 | Set-Content -Path $configFile -Encoding UTF8

    # Criar marker
    New-Item -ItemType File -Path $FIRST_RUN_MARKER -Force | Out-Null
    Write-Log "SETUP" "COMPLETED" @{ marker = $FIRST_RUN_MARKER }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Configuracao Inicial Concluida!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Para usar microfone: ollama serve & Ctrl+R" -ForegroundColor Gray
    Write-Host ""
    return $true
}

# ============================================================================
# SELETOR DE PROJETOS
# ============================================================================

function Select-Project {
    param(
        [string]$ProvidedPath,
        [switch]$SkipPrompt
    )

    # Se caminho foi fornecido, verificar e usar direto
    if ($ProvidedPath) {
        $resolved = Resolve-Path $ProvidedPath -ErrorAction SilentlyContinue
        if ($resolved -and (Test-Path $resolved.Path -PathType Container)) {
            Write-Log "PROJECT" "PROVIDED" @{ path = $resolved.Path }
            return $resolved.Path
        }
        Write-Log "PROJECT" "INVALID_PATH" @{ provided = $ProvidedPath } "WARN"
    }

    # Criar Projects root se nao existir
    if (-not (Test-Path $PROJECTS_ROOT)) {
        New-Item -ItemType Directory -Path $PROJECTS_ROOT -Force | Out-Null
    }

    $dirs = Get-ChildItem $PROJECTS_ROOT -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "multitask-worktrees" }

    # Se nenhum projeto existe → criar Default e abrir direto
    if ((-not $dirs -or $dirs.Count -eq 0) -and -not $ProvidedPath) {
        $defaultDir = Join-Path $PROJECTS_ROOT "Default"
        if (-not (Test-Path $defaultDir)) {
            New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null
            Push-Location $defaultDir
            try { git init 2>$null | Out-Null; git commit --allow-empty -m "Initial commit" 2>$null | Out-Null } catch { }
            Pop-Location
            $wsDir = Join-Path $defaultDir ".opencode"
            if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir -Force | Out-Null }
            @{ mode = "local"; limitGB = 10 } | ConvertTo-Json | Set-Content (Join-Path $wsDir "workspace.json")
        }
        Write-Log "PROJECT" "DEFAULT_CREATED" @{ path = $defaultDir }
        return $defaultDir
    }

    # Se so tem 1 projeto → abrir direto sem perguntar
    if ($dirs.Count -eq 1) {
        Write-Log "PROJECT" "AUTO_SELECTED" @{ name = $dirs[0].Name; path = $dirs[0].FullName }
        return $dirs[0].FullName
    }

    # Se tem mais de 1 projeto → mostrar seletor
    while ($true) {
        $dirs = Get-ChildItem $PROJECTS_ROOT -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "multitask-worktrees" }

        Clear-Host
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  OpenCode - Seletor de Projetos" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""

        if ($dirs -and $dirs.Count -gt 0) {
            Write-Host "Projetos Existentes:" -ForegroundColor White
            for ($i = 0; $i -lt $dirs.Count; $i++) {
                Write-Host "  [$($i + 1)] $($dirs[$i].Name)" -ForegroundColor White
            }
        }

        Write-Host ""
        Write-Host "Opcoes:" -ForegroundColor White
        Write-Host "  [0] Criar Novo Projeto" -ForegroundColor Green
        Write-Host "  [Q] Sair" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "Escolha uma opcao"

        if ($choice -eq "q" -or $choice -eq "Q") {
            Write-Log "PROJECT" "EXIT" @{ action = "USER_QUIT" }
            exit 0
        }

        if ($choice -eq "0") {
            Write-Host ""
            $newName = Read-Host "Digite o nome do novo projeto"
            if ([string]::IsNullOrWhiteSpace($newName)) { continue }

            $newName = $newName -replace '\s+', '_'
            $newDir = Join-Path $PROJECTS_ROOT $newName

            if (Test-Path $newDir) {
                Write-Host "Ja existe um projeto com esse nome." -ForegroundColor Red
                Start-Sleep -Seconds 2
                continue
            }

            New-Item -ItemType Directory -Path $newDir -Force | Out-Null
            Write-Log "PROJECT" "CREATED" @{ name = $newName; path = $newDir }

            # Git init
            Write-Host "Inicializando Git local..." -ForegroundColor Gray
            Push-Location $newDir
            try {
                git init 2>$null | Out-Null
                git commit --allow-empty -m "Initial commit" 2>$null | Out-Null
            }
            catch { }
            Pop-Location

            # GitHub CLI (opcional)
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                Write-Host ""
                Write-Host "Deseja criar um repositorio privado no GitHub?" -ForegroundColor White
                Write-Host "  [1] Sim (Nuvem Privada)" -ForegroundColor Green
                Write-Host "  [2] Nao (Apenas Local)" -ForegroundColor Gray
                $ghChoice = Read-Host "Escolha [1-2]"

                if ($ghChoice -eq "1") {
                    Write-Host "Criando repositorio privado no GitHub..." -ForegroundColor Yellow
                    Push-Location $newDir
                    try {
                        gh repo create $newName --private --source=. --push 2>$null | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "Repositorio criado com sucesso!" -ForegroundColor Green
                            $wsDir = Join-Path $newDir ".opencode"
                            if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir -Force | Out-Null }
                            @{ mode = "cloud"; limitGB = 10 } | ConvertTo-Json | Set-Content (Join-Path $wsDir "workspace.json")
                        }
                        else {
                            Write-Host "[AVISO] Falha ao criar repositorio remoto. Mantendo apenas local." -ForegroundColor Yellow
                            $wsDir = Join-Path $newDir ".opencode"
                            if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir -Force | Out-Null }
                            @{ mode = "local"; limitGB = 10 } | ConvertTo-Json | Set-Content (Join-Path $wsDir "workspace.json")
                        }
                    }
                    catch {
                        $wsDir = Join-Path $newDir ".opencode"
                        if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir -Force | Out-Null }
                        @{ mode = "local"; limitGB = 10 } | ConvertTo-Json | Set-Content (Join-Path $wsDir "workspace.json")
                    }
                    Pop-Location
                }
                else {
                    $wsDir = Join-Path $newDir ".opencode"
                    if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir -Force | Out-Null }
                    @{ mode = "local"; limitGB = 10 } | ConvertTo-Json | Set-Content (Join-Path $wsDir "workspace.json")
                }
            }
            else {
                $wsDir = Join-Path $newDir ".opencode"
                if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir -Force | Out-Null }
                @{ mode = "local"; limitGB = 10 } | ConvertTo-Json | Set-Content (Join-Path $wsDir "workspace.json")
            }

            return $newDir
        }

        # Validar escolha numerica
        $idx = 0
        if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $dirs.Count) {
            $selected = $dirs[$idx - 1].FullName
            Write-Log "PROJECT" "SELECTED" @{ name = $dirs[$idx - 1].Name; path = $selected }
            return $selected
        }

        Write-Host "Opcao invalida." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}

# ============================================================================
# INICIALIZACAO DO OPENCODE
# ============================================================================

function Invoke-OpenCode {
    param([string]$ProjectPath)

    Push-Location $ProjectPath

    # Limpar multitask-worktrees temporario se existir
    $mtDir = Join-Path $ProjectPath "multitask-worktrees"
    if (Test-Path $mtDir) {
        Remove-Item -Path $mtDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Configurar ambiente
    $env:OPENCODE_CONFIG = Join-Path $OPENCODE_CONFIG "opencode.jsonc"
    $env:OPENCODE_DISABLE_PROJECT_CONFIG = "1"
    $env:OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true"
    $env:OPENCODE_EXPERIMENTAL_PLAN_MODE = "true"

    $exePath = Join-Path $OPENCODE_BIN "opencode.exe"

    Write-Log "LAUNCH" "START" @{ path = $ProjectPath; exe = $exePath }
    Write-Host ""
    Write-Host "Iniciando OpenCode em: $ProjectPath" -ForegroundColor Green
    Write-Host ""

    & $exePath $ProjectPath

    if ($LASTEXITCODE -ne 0) {
        Write-Log "LAUNCH" "ERROR_EXIT" @{ exit_code = $LASTEXITCODE } "ERROR"
        Write-Host ""
        Write-Host "[ERRO] OpenCode encerrou com codigo de erro: $LASTEXITCODE" -ForegroundColor Red
        Write-Host ""
    }

    Pop-Location
}

# ============================================================================
# FLUXO PRINCIPAL
# ============================================================================

# Configurar ambiente
$env:PATH = "$OPENCODE_BIN;$env:PATH"

# Adicionar shims do Scoop
$scoopShims = Join-Path $env:USERPROFILE "scoop\shims"
if (Test-Path $scoopShims) {
    $env:PATH = "$scoopShims;$env:PATH"
}

# Iniciar logs
Ensure-LogDir
Rotate-Logs

# Disparar o monitor de logs exclusivo em background de forma transparente
$monitorScript = Join-Path $OPENCODE_HOME "scripts\opencode-monitor.ps1"
if (Test-Path $monitorScript) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$monitorScript`" -LogDir `"$LOG_DIR`" -OpenCodeHome `"$OPENCODE_HOME`""
    Start-Process powershell.exe -ArgumentList $argList -WindowStyle Hidden
}

Write-Log "SYSTEM" "START" @{
    ps_version = $PSVersionTable.PSVersion.ToString()
    os = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } else { "macOS" }
    pid = $PID
    args = if ($Arguments) { $Arguments -join " " } else { "" }
}


# Garantir diretorios
if (-not (Test-Path $OPENCODE_BIN))  { New-Item -ItemType Directory -Path $OPENCODE_BIN -Force | Out-Null }
if (-not (Test-Path $OPENCODE_DATA)) { New-Item -ItemType Directory -Path $OPENCODE_DATA -Force | Out-Null }
if (-not (Test-Path $OPENCODE_CONFIG)) { New-Item -ItemType Directory -Path $OPENCODE_CONFIG -Force | Out-Null }

# 1. Verificar executavel
$exePath = Join-Path $OPENCODE_BIN "opencode.exe"
$exeStatus = Test-OpenCodeExe $exePath

if ($exeStatus.valid) {
    Write-Log "SYSTEM" "EXE_OK" @{ version = $exeStatus.version; size = $exeStatus.size }
}
elseif ($exeStatus.exists -and -not $exeStatus.valid) {
    Write-Log "SYSTEM" "EXE_INVALID" @{ reason = $exeStatus.reason; size = $exeStatus.size } "WARN"
    # Deletar executavel invalido
    Remove-Item $exePath -Force -ErrorAction SilentlyContinue
    # Baixar novamente
    $version = Get-LatestVersion
    $downloaded = Download-OpenCodeExe $version
    if (-not $downloaded) {
        Write-Log "SYSTEM" "FATAL" @{ reason = "DOWNLOAD_FAILED" } "ERROR"
        Write-Host "[ERRO] Nao foi possivel baixar o opencode.exe. Verifique sua conexao." -ForegroundColor Red
        Write-Host "       Log: $LOG_FILE" -ForegroundColor Gray
        Read-Host "Pressione Enter para sair"
        exit 1
    }
}
else {
    Write-Log "SYSTEM" "EXE_MISSING" @{ reason = "NOT_FOUND" }
    $version = Get-LatestVersion
    $downloaded = Download-OpenCodeExe $version
    if (-not $downloaded) {
        Write-Log "SYSTEM" "FATAL" @{ reason = "DOWNLOAD_FAILED" } "ERROR"
        Write-Host "[ERRO] Nao foi possivel baixar o opencode.exe. Verifique sua conexao." -ForegroundColor Red
        Write-Host "       Log: $LOG_FILE" -ForegroundColor Gray
        Read-Host "Pressione Enter para sair"
        exit 1
    }
}

# 2. Setup inicial (se necessario)
$setupDone = Run-InitialSetup

# 3. Seletor de projetos
$providedPath = ""
if ($Arguments.Count -gt 0) {
    $providedPath = $Arguments[0]
}

$projectPath = Select-Project -ProvidedPath $providedPath

# 4. Executar OpenCode
Invoke-OpenCode -ProjectPath $projectPath

Write-Log "SYSTEM" "END" @{ exit_code = $LASTEXITCODE }