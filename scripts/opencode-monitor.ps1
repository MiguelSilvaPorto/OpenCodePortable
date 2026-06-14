# ============================================================================
# OpenCode Portable - Monitor de Logs Avançado Centralizado (Background)
# ============================================================================
# Arquivo: scripts/opencode-monitor.ps1
# Descricao: Monitor de logs persistente com Mutex global, escuta dinâmica
#            multissessão, filtragem de caminhos de projetos e desligamento
#            com grace period de 30 segundos.
# ============================================================================

param(
    [string]$LogDir,
    [string]$OpenCodeHome
)

$mutexName = "Global\OpenCodePortableMonitor"
$createdNew = $false

try {
    # 1. Tentar adquirir o Mutex de Sistema Global
    $mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
    
    if (-not $createdNew) {
        # O monitor já está rodando em segundo plano. Finalizar esta instância silenciosamente.
        exit 0
    }
}
catch {
    # Falha ao criar ou obter o Mutex
    exit 1
}

# Configurações do arquivo de crash
$reportPath = Join-Path $LogDir "crash-report.md"
$launcherLog = Join-Path $LogDir "launcher.jsonl"
$lastCheckTime = Get-Date

function Write-CrashReport($title, $reason, $details, $file = "Desconhecido", $line = "Desconhecido") {
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Criar cabeçalho Markdown de Crash
    $md = @"
# Relatório de Falha do OpenCode Portable

**Data e Hora:** $date
**Componente Afetado:** $title
**Arquivo de Origem:** $file
**Linha do Erro:** $line

## O que aconteceu?
$reason

## Detalhes Técnicos / Rastreamento de Pilha (Stack Trace)
```text
$details
```

---
*Este relatório foi gerado em tempo real pelo Monitor de Logs Exclusivo do OpenCode.*
"@
    # Garante que a pasta de logs existe
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    
    # Adicionar o log de forma legível
    Set-Content -Path $reportPath -Value $md -Encoding utf8
}

# Inicializar o loop de monitoramento com escuta dinâmica de processos e arquivos
$gracePeriodSeconds = 30
$noProcessTimer = 0
$projectsPath = Join-Path $OpenCodeHome "Projects"

Write-Output "Monitor do OpenCode iniciado com sucesso em segundo plano."

try {
    while ($true) {
        # 1. Monitorar processos do OpenCode ativos no sistema
        $opencodeProcesses = Get-Process -Name "opencode" -ErrorAction SilentlyContinue
        
        # Filtra processos que pertencem ao diretório portátil para não cruzar com outras instalações do PC
        $activePortableProcesses = @()
        foreach ($proc in $opencodeProcesses) {
            try {
                $path = $proc.Path
                if ($path -and $path -like "*$OpenCodeHome*") {
                    $activePortableProcesses += $proc
                }
            }
            catch {}
        }
        
        if ($activePortableProcesses.Count -eq 0) {
            # Sem processos ativos no repositório portátil
            $noProcessTimer += 2
            if ($noProcessTimer -ge $gracePeriodSeconds) {
                # Fim do Grace Period de 30 segundos
                break
            }
        }
        else {
            # Resetar timer se encontrar alguma instância ativa do OpenCode portátil
            $noProcessTimer = 0
            
            # Verificar se os processos ativos terminaram com erro (código de saída não zero)
            foreach ($proc in $activePortableProcesses) {
                if ($proc.HasExited) {
                    $exitCode = $proc.ExitCode
                    if ($exitCode -ne 0 -and $exitCode -ne $null) {
                        # Gerar crash report de fechamento inesperado
                        $reason = "O executável principal do OpenCode encerrou inesperadamente retornando um código de falha do Windows."
                        $details = "Código de Encerramento (Exit Code): $exitCode`nID do Processo: $($proc.Id)"
                        Write-CrashReport -title "Encerramento Inesperado do Executável" -reason $reason -details $details -file "opencode.exe" -line "Interno"
                    }
                }
            }
        }
        
        # 2. Monitorar o arquivo de logs estruturado (launcher.jsonl) em busca de novos erros
        if (Test-Path $launcherLog) {
            try {
                $lastWrite = (Get-Item $launcherLog).LastWriteTime
                if ($lastWrite -gt $lastCheckTime) {
                    # Ler apenas as linhas novas adicionadas após a última checagem
                    $lines = Get-Content $launcherLog -ErrorAction SilentlyContinue | Select-String -Pattern '"level":"ERROR"'
                    foreach ($lineMatch in $lines) {
                        $logEntry = ConvertFrom-Json $lineMatch.Line -ErrorAction SilentlyContinue
                        if ($logEntry) {
                            $ts = [datetime]$logEntry.ts
                            if ($ts -gt $lastCheckTime) {
                                # Capturar o contexto do erro
                                $stage = $logEntry.stage
                                $event = $logEntry.event
                                $context = $logEntry.context
                                
                                # Filtrar caminhos contendo Projects/ ou multitask-worktrees para evitar falsos positivos
                                $pathString = $context | ConvertTo-Json -Compress
                                if ($pathString -match "Projects" -or $pathString -match "worktrees" -or $pathString -match "multitask-worktrees") {
                                    continue
                                }
                                
                                # Determinar detalhes do erro com arquivo e linha por regex nas exceções
                                $errFile = "Instalação/Launcher"
                                $errLine = "N/A"
                                $details = "Estágio: $stage`nEvento: $event`nContexto: $($pathString)"
                                
                                if ($context.error -and $context.error -match "linha\s+(\d+)") {
                                    $errLine = $Matches[1]
                                }
                                if ($context.error -and $context.error -match "file\s+'([^']+)'") {
                                    $errFile = Split-Path $Matches[1] -Leaf
                                }
                                if ($context.script_trace) {
                                    $details += "`n`nTrace:`n$($context.script_trace)"
                                    if ($context.script_trace -match "linha\s+(\d+)") {
                                        $errLine = $Matches[1]
                                    }
                                }
                                
                                $reason = "Ocorreu um erro crítico durante a orquestração ou inicialização portátil do OpenCode."
                                if ($context.error) {
                                    $reason = $context.error
                                }
                                
                                Write-CrashReport -title "Erro de Inicialização ($stage)" -reason $reason -details $details -file $errFile -line $errLine
                            }
                        }
                    }
                    $lastCheckTime = $lastWrite
                }
            }
            catch {}
        }
        
        Start-Sleep -Seconds 2
    }
}
finally {
    # 3. Liberar o Mutex do sistema e encerrar de forma limpa
    if ($mutex) {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}
