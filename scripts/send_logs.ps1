# send_logs.ps1 - Envia relatorios de erro e logs de diagnostico para o repositorio GitHub
# ============================================================================

$OPENCODE_HOME = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path
$LOG_DIR = Join-Path $OPENCODE_HOME "data\logs"
$ZIP_PATH = Join-Path $LOG_DIR "opencode-diagnostics.zip"
$REPORT_PATH = Join-Path $LOG_DIR "crash-report.md"
$HISTORY_PATH = Join-Path $LOG_DIR "errors-history.md"
$GITHUB_REPO = "MiguelSilvaPorto/OpenCodePortable"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  OpenCode Portable - Envio de Diagnosticos  " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Gerar os arquivos de log unificados e o ZIP
Write-Host "  [1/3] Compilando logs e relatorios..." -ForegroundColor Gray
$loggerScript = Join-Path $OPENCODE_HOME "scripts\advanced_logger.py"
if (Test-Path $loggerScript) {
    & python $loggerScript --generate | Out-Null
} else {
    Write-Host "[ERRO] advanced_logger.py nao encontrado." -ForegroundColor Red
    exit 1
}

# 2. Verificar se o ZIP foi gerado com sucesso
if (-not (Test-Path $ZIP_PATH)) {
    Write-Host "[ERRO] Falha ao gerar o arquivo ZIP de diagnostico." -ForegroundColor Red
    exit 1
}
Write-Host "        Logs empacotados com sucesso em: $ZIP_PATH" -ForegroundColor Green

# 3. Verificar login do GitHub CLI (gh)
Write-Host "  [2/3] Verificando autenticacao no GitHub..." -ForegroundColor Gray
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host ""
    Write-Host "[ATENCAO] O utilitario 'gh' (GitHub CLI) nao esta instalado ou disponivel no PATH." -ForegroundColor Yellow
    Write-Host "Voce pode fazer o upload manual do arquivo ZIP abaixo no seu repositorio GitHub:" -ForegroundColor Gray
    Write-Host "-> Path: $ZIP_PATH" -ForegroundColor White
    Write-Host ""
    exit 0
}

# Verificar se esta logado
$authStatus = & gh auth status 2>&1 | Out-String
if ($authStatus -match "Logged in to github.com") {
    Write-Host "        Autenticado no GitHub com sucesso!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[ATENCAO] Voce nao esta autenticado no GitHub CLI (gh)." -ForegroundColor Yellow
    Write-Host "Por favor, execute o comando abaixo para se autenticar antes de enviar:" -ForegroundColor Gray
    Write-Host "-> gh auth login" -ForegroundColor White
    Write-Host ""
    exit 0
}

# 4. Criar a issue no repositorio e vincular os logs
Write-Host "  [3/3] Enviando relatorio para o GitHub..." -ForegroundColor Gray

$ERRORS_LOG = Join-Path $LOG_DIR "advanced_errors.log"
$LAUNCHER_LOG = Join-Path $LOG_DIR "launcher.jsonl"
$FULL_LOG = Join-Path $LOG_DIR "advanced_full.log"

$filesToUpload = @()
if (Test-Path $REPORT_PATH) { $filesToUpload += $REPORT_PATH }
if (Test-Path $HISTORY_PATH) { $filesToUpload += $HISTORY_PATH }
if (Test-Path $ERRORS_LOG) { $filesToUpload += $ERRORS_LOG }
if (Test-Path $LAUNCHER_LOG) { $filesToUpload += $LAUNCHER_LOG }
if (Test-Path $FULL_LOG) { $filesToUpload += $FULL_LOG }

$gistUrl = ""
if ($filesToUpload.Count -gt 0) {
    try {
        Write-Host "        Criando Gist privado com os logs..." -ForegroundColor Gray
        $gistOutput = & gh gist create $filesToUpload -d "Logs de Diagnostico do OpenCode Portable - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" 2>$null
        $gistUrl = ($gistOutput | Out-String).Trim()
        if ($gistUrl -match "https://gist.github.com/") {
            Write-Host "        Gist criado com sucesso: $gistUrl" -ForegroundColor Green
        } else {
            Write-Host "        [ATENCAO] Nao foi possivel obter a URL do Gist. Retorno: $gistUrl" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "        [ATENCAO] Erro ao criar Gist: $_" -ForegroundColor Yellow
    }
}

$title = "OpenCode Portable: Relatorio de Erros - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
$body = "Enviado automaticamente pelo utilitario de logs do OpenCode Portable.`n`n"

if ($gistUrl -match "https://gist.github.com/") {
    $gistZipUrl = $gistUrl + "/archive/main.zip"
    $body += "Logs e Diagnosticos Online (Gist): $gistUrl`n"
    $body += "Baixar todos os logs (ZIP): [$gistZipUrl]($gistZipUrl)`n`n"
} else {
    $body += "Nota: Os logs locais nao puderam ser enviados via Gist. Verifique a pasta local data/logs para o arquivo ZIP de diagnostico.`n`n"
}

if (Test-Path $REPORT_PATH) {
    $body += "### Ultimo Relatorio de Falha`n`n"
    $body += Get-Content $REPORT_PATH -Raw
} else {
    $body += "Nenhum erro critico registrado recentemente."
}

# Escrever corpo em arquivo temporario para evitar problemas de escape de argumentos
$bodyPath = Join-Path $LOG_DIR "issue-body.md"
$body | Out-File -FilePath $bodyPath -Encoding utf8

try {
    # Criar issue no GitHub usando o arquivo temporario
    $issueOutput = & gh issue create --repo $GITHUB_REPO --title $title --body-file $bodyPath 2>&1
    $issueUrl = ($issueOutput | Out-String).Trim()
    
    if ($issueUrl -match "https://github.com/") {
        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host "  Relatorio enviado com sucesso! " -ForegroundColor Green
        Write-Host "  Link da Issue:" -ForegroundColor Gray
        Write-Host "  -> $issueUrl" -ForegroundColor White
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "[ERRO] Falha ao criar a issue no GitHub. Retorno: $issueUrl" -ForegroundColor Red
    }
} catch {
    Write-Host "[ERRO] Falha ao enviar para o GitHub: $_" -ForegroundColor Red
} finally {
    if (Test-Path $bodyPath) {
        Remove-Item $bodyPath -Force | Out-Null
    }
}
