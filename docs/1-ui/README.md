# 1. Interface do Usuario

Esta secao documenta os componentes de interface do usuario do OpenCode Portable, incluindo launchers, configuracao e sistema de voz.

## Arquivos

| Arquivo | Descricao |
|---------|-----------|
| [opencode.bat.md](opencode.bat.md) | Launcher principal (BAT) com health check automatico |
| [opencode.ps1.md](opencode.ps1.md) | Launcher alternativo (PowerShell) com funcionalidades avancadas |
| [config.md](config.md) | Arquivo de configuracao opencode.jsonc |
| [voice.md](voice.md) | Sistema de reconhecimento de voz (microfone) |

## Fluxo Geral

```
opencode.bat / opencode.ps1
    │
    ├── 1. Verificar/Instalar executavel
    ├── 2. Verificar atualizacoes
    ├── 3. Health check de dependencias (whisper, sox, python, etc.)
    ├── 4. Corrigir caminhos MCP (portabilidade)
    ├── 5. Seletor de projetos
    └── 6. Iniciar opencode.exe
```

## Variaveis de Ambiente

| Variavel | Descricao |
|----------|-----------|
| `OPENCODE_HOME` | Diretorio raiz do projeto portatil |
| `OPENCODE_BIN` | Pasta bin (executaveis) |
| `OPENCODE_CONFIG` | Caminho para opencode.jsonc |
| `OPENCODE_DATA` | Pasta de dados (logs, modelos, etc.) |
| `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS` | Habilita subagents em background |
| `OPENCODE_EXPERIMENTAL_PLAN_MODE` | Habilita modo de planejamento |
