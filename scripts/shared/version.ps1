function Test-OpenCodeExe {
    param([string]$ExePath)
    $MIN_EXE_SIZE = 10MB
    if (-not (Test-Path $ExePath)) {
        return @{ exists = $false; valid = $false; reason = "NOT_FOUND" }
    }
    $item = Get-Item $ExePath
    $size = $item.Length
    if ($size -lt $MIN_EXE_SIZE) {
        return @{ exists = $true; valid = $false; reason = "TOO_SMALL"; size = $size; expected_min = $MIN_EXE_SIZE }
    }
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

function Get-LatestVersion {
    param(
        [string]$CacheFile,
        [string]$GitHubRepo = "MiguelSilvaPorto/OpenCodePortable",
        [string]$FallbackVersion = "1.17.7",
        [string]$LogDir
    )
    $CACHE_TTL_HOURS = 24
    $MAX_RETRIES = 3
    $TIMEOUT_API = 15

    # 1. Verificar cache
    if (Test-Path $CacheFile) {
        try {
            $cache = Get-Content $CacheFile -Raw | ConvertFrom-Json
            $age = (Get-Date) - [datetime]$cache.timestamp
            if ($age.TotalHours -lt $CACHE_TTL_HOURS) {
                if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "VERSION" -Event "CACHE_HIT" -Context @{ version = $cache.version; age_hours = [math]::Round($age.TotalHours, 1) } }
                return $cache.version
            }
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "VERSION" -Event "CACHE_STALE" -Context @{ version = $cache.version; age_hours = [math]::Round($age.TotalHours, 1) } -Level "WARN" }
        }
        catch {
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "VERSION" -Event "CACHE_CORRUPT" -Context @{ error = $_.Exception.Message } -Level "WARN" }
        }
    }

    # 2. GitHub API com retry
    for ($attempt = 1; $attempt -le $MAX_RETRIES; $attempt++) {
        try {
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "VERSION" -Event "API_REQUEST" -Context @{ attempt = $attempt; max = $MAX_RETRIES } }
            $headers = @{ Accept = "application/vnd.github.v3+json" }
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubRepo/releases/latest" -Headers $headers -TimeoutSec $TIMEOUT_API
            $version = $response.tag_name -replace '^v', ''
            $cacheData = @{ version = $version; timestamp = (Get-Date).ToString("o") }
            $cacheData | ConvertTo-Json -Depth 3 | Set-Content -Path $CacheFile -Encoding UTF8
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "VERSION" -Event "API_SUCCESS" -Context @{ version = $version; attempt = $attempt } }
            return $version
        }
        catch {
            $delay = [math]::Pow(2, $attempt)
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "VERSION" -Event "API_FAILED" -Context @{ attempt = $attempt; error = $_.Exception.Message; next_retry_in = "${delay}s" } -Level "WARN" }
            if ($attempt -lt $MAX_RETRIES) { Start-Sleep -Seconds $delay }
        }
    }

    # 3. Fallback
    if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "VERSION" -Event "FALLBACK_USED" -Context @{ version = $FallbackVersion; reason = "API_FAILED_ALL_RETRIES" } -Level "WARN" }
    return $FallbackVersion
}

function Download-OpenCodeExe {
    param(
        [string]$Version,
        [string]$BinDir,
        [string]$GitHubRepo = "MiguelSilvaPorto/OpenCodePortable",
        [string]$LogDir
    )
    $MAX_RETRIES = 3
    $MIN_ZIP_SIZE = 5MB
    $url = "https://github.com/$GitHubRepo/releases/download/v$Version/opencode-windows-x64.zip"
    $zipPath = Join-Path $BinDir "opencode.zip"
    $exePath = Join-Path $BinDir "opencode.exe"

    if (-not (Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir -Force | Out-Null }

    for ($attempt = 1; $attempt -le $MAX_RETRIES; $attempt++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "DOWNLOAD" -Event "START" -Context @{ url = $url; attempt = $attempt; max = $MAX_RETRIES } }
        try {
            # Configurar TLS 1.2 e TLS 1.3
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
            
            try {
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) OpenCodePortable")
                $webClient.DownloadFile($url, $zipPath)
            }
            catch {
                # Fallback usando Invoke-WebRequest
                Invoke-WebRequest -Uri $url -OutFile $zipPath -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) OpenCodePortable" -UseBasicParsing
            }
            
            $sw.Stop()
            $bytes = (Get-Item $zipPath).Length
            if ($bytes -lt $MIN_ZIP_SIZE) {
                throw "ZIP muito pequeno: $bytes bytes (esperado > $MIN_ZIP_SIZE)"
            }
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "DOWNLOAD" -Event "COMPLETED" -Context @{ bytes = $bytes; duration_ms = $sw.ElapsedMilliseconds; attempt = $attempt } }
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "EXTRACT" -Event "START" -Context @{ zip = $zipPath; dest = $BinDir } }
            Expand-Archive -Path $zipPath -DestinationPath $BinDir -Force
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            $verify = Test-OpenCodeExe -ExePath $exePath
            if ($verify.valid) {
                if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "EXTRACT" -Event "SUCCESS" -Context @{ version = $verify.version; size = $verify.size; duration_ms = $sw.ElapsedMilliseconds } }
                return $true
            }
            else {
                if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "EXTRACT" -Event "VERIFY_FAILED" -Context @{ reason = $verify.reason; size = $verify.size } -Level "ERROR" }
                if (Test-Path $exePath) { Remove-Item $exePath -Force }
            }
        }
        catch {
            $sw.Stop()
            $retry = $attempt -lt $MAX_RETRIES
            if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "DOWNLOAD" -Event "FAILED" -Context @{ error = $_.Exception.Message; attempt = $attempt; duration_ms = $sw.ElapsedMilliseconds; retry = $retry } -Level "ERROR" }
            if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
            if ($retry) { Start-Sleep -Seconds (5 * $attempt) }
        }
    }
    if ($LogDir) { Write-LogEntry -LogDir $LogDir -Stage "DOWNLOAD" -Event "ABORTED" -Context @{ reason = "MAX_RETRIES_EXCEEDED"; max = $MAX_RETRIES } -Level "ERROR" }
    return $false
}
