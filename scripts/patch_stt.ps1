# Helper script para patchear stt.js com segurança e garantir gravação universal
$cacheDir = Join-Path $env:USERPROFILE ".cache\opencode\packages\@renjfk\opencode-voice@latest"
$sttFile = Join-Path $cacheDir "node_modules\@renjfk\opencode-voice\lib\stt.js"

# Se o backup ou o stt.js atual contiver o erro antigo (DialogInput), limpamos tudo para forçar reinstalação limpa
if (Test-Path $sttFile) {
    $content = Get-Content $sttFile -Raw
    if ($content -match "DialogInput") {
        Write-Host "[HEALTH] Detectado patch antigo com DialogInput. Limpando cache para reinstalar..." -ForegroundColor Yellow
        Remove-Item (Join-Path $cacheDir "node_modules") -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Se o cache ou stt.js estiver ausente, criamos e instalamos previamente para o patch rodar sempre
if (-not (Test-Path $sttFile)) {
    Write-Host "[HEALTH] Pre-instalando dependencias do plugin de voz..." -ForegroundColor Yellow
    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    
    # Criar um package.json dummy no cache para permitir a instalacao local
    $pkgJson = Join-Path $cacheDir "package.json"
    if (-not (Test-Path $pkgJson)) {
        '{"name":"opencode-voice-cache"}' | Set-Content -Path $pkgJson -Encoding UTF8
    }

    # Instalar o plugin via npm
    Push-Location $cacheDir
    try {
        npm install @renjfk/opencode-voice@latest --no-audit --no-fund --quiet 2>$null | Out-Null
    } catch {}
    Pop-Location
}

# Executar o patcher em Node.js para aplicar as modificacoes robustas e tolerantes a falha no stt.js
$patcherJs = Join-Path $PSScriptRoot "patch_stt.js"
if (Test-Path $patcherJs) {
    node $patcherJs
} else {
    Write-Error "[HEALTH] patch_stt.js nao encontrado em $patcherJs"
}

