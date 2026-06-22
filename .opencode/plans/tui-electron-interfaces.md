# Plano: TUI + Electron Desktop (Dois Launchers)

## Arquitetura

```
opencode.bat ──> opencode.ps1 ──> [módulos shared] ──> opencode.exe (TUI)
opencode-electron.bat ──> opencode-electron.ps1 ──> [módulos shared] ──> Electron (Desktop)
```

## Módulos Compartilhados (scripts/shared/)

| Módulo | Funções | Origem (opencode.ps1) |
|--------|---------|----------------------|
| `logging.ps1` | `Write-LogEntry`, `Rotate-LogFiles` | Linhas 124-192 |
| `version.ps1` | `Test-OpenCodeExe`, `Get-LatestVersion`, `Download-OpenCodeExe` | Linhas 198-335 |
| `setup.ps1` | `Ensure-Python`, `Run-InitialSetup` | Linhas 49-115, 341-770 |
| `project.ps1` | `Select-Project`, `Ensure-BrainStructure` | Linhas 797-1031 |
| `env.ps1` | `Update-OpenCodeConfig` | Linhas 777-791 |

## Arquivos a criar

### 1. `scripts/shared/logging.ps1`
Extrair funções de log do opencode.ps1 (linhas 124-192) com parâmetros de caminho.

### 2. `scripts/shared/version.ps1`
Extrair `Test-OpenCodeExe`, `Get-LatestVersion`, `Download-OpenCodeExe` com parâmetros.

### 3. `scripts/shared/setup.ps1`
Extrair `Ensure-Python`, `Run-InitialSetup` com parâmetros.

### 4. `scripts/shared/project.ps1`
Extrair `Select-Project`, `Ensure-BrainStructure` com parâmetros.

### 5. `scripts/shared/env.ps1`
Extrair `Update-OpenCodeConfig` e variáveis de ambiente.

### 6. `opencode-electron.bat`
```batch
@echo off
setlocal
set "OPENCODE_HOME=%~dp0"
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] PowerShell nao encontrado.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%OPENCODE_HOME%opencode-electron.ps1" %*
exit /b %errorlevel%
```

### 7. `opencode-electron.ps1`
```powershell
# Dot-source módulos compartilhados
. "$PSScriptRoot\scripts\shared\logging.ps1"
. "$PSScriptRoot\scripts\shared\version.ps1"
. "$PSScriptRoot\scripts\shared\setup.ps1"

# Constantes
$OPENCODE_HOME = $PSScriptRoot
$OPENCODE_BIN = Join-Path $OPENCODE_HOME "bin"
$OPENCODE_DATA = Join-Path $OPENCODE_HOME "data"
$LOG_DIR = Join-Path $OPENCODE_DATA "logs"

# 1. Setup
Rotate-LogFiles -LogDir $LOG_DIR
$setupDone = Run-InitialSetup -OpenCodeHome $OPENCODE_HOME -DataDir $OPENCODE_DATA

# 2. Verificar opencode.exe
$exePath = Join-Path $OPENCODE_BIN "opencode.exe"
$status = Test-OpenCodeExe -ExePath $exePath
if (-not $status.valid) {
    $version = Get-LatestVersion -CacheFile $CACHE_FILE
    Download-OpenCodeExe -Version $version -BinDir $OPENCODE_BIN
}

# 3. Iniciar Electron
$electronDir = Join-Path $OPENCODE_HOME "TuiElectron"
Push-Location $electronDir
& npm start
Pop-Location
```

### 8. Modificar `opencode.ps1`
Refatorar para dot-source os módulos compartilhados em vez de ter tudo inline.

### 9. `TuiElectron/src/main.ts`
Adicionar:
- IPC handlers para: `execute-command`, `select-project`, `get-status`
- Spawn de opencode.exe via child_process
- Chamada ao PowerShell para setup

### 10. `TuiElectron/src/preload.ts`
Adicionar APIs:
- `executeCommand(command)` - executa comando no opencode.exe
- `selectProject()` - abre seletor de projetos
- `getStatus()` - verifica status do ambiente
- `onOutput(callback)` - recebe output do opencode.exe

### 11. `TuiElectron/src/renderer/index.html` (script)
Substituir `// TODO: send to agent backend` por:
```javascript
window.electronAPI.executeCommand(msg).then(response => {
    // mostrar resposta
});
```

## Observações
- Interface HTML/CSS permanece intacta
- Apenas o JavaScript do index.html é modificado (comportamento)
- Lógica de setup é compartilhada entre TUI e Electron via dot-sourcing
- Electron usa child_process para spawnar opencode.exe
