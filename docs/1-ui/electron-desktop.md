# OpenCode Desktop — Interface Electron

Interface grafica desktop para o OpenCode, inspirada no Cursor Agent. dois launchers compartilham a mesma logica de setup via `scripts/shared/`.

## Arquitetura

```
opencode.bat ──────────> opencode.ps1 ──────> opencode.exe (TUI)
opencode-electron.bat ─> opencode-electron.ps1 ─> Electron (Desktop)
                               │
                         scripts/shared/
                         ├── logging.ps1
                         ├── version.ps1
                         ├── setup.ps1
                         ├── project.ps1
                         └── env.ps1
```

## Como Usar

```batch
opencode.bat              :: Abre a interface TUI (terminal)
opencode-electron.bat     :: Abre a interface Electron (desktop)
```

## Estrutura do TuiElectron/

```
TuiElectron/
├── src/
│   ├── main.ts              :: Processo principal Electron (IPC, spawn opencode.exe)
│   ├── preload.ts           :: Bridge entre main e renderer (contextIsolation)
│   └── renderer/
│       └── index.html       :: Interface completa (HTML + CSS + JS, ~1930 linhas)
├── dist/                    :: JavaScript compilado
├── assets/                  :: Icones (vazio)
├── package.json             :: Dependencias: electron, typescript
└── tsconfig.json            :: Config TypeScript
```

## Componentes da Interface

### 1. Titlebar Customizado
- Frameless window (sem borda do SO)
- Controles de janela: minimizar, maximizar, fechar
- Menu: File, Edit, View, Help (decorativo)

### 2. Sidebar
- **New Agent** (Ctrl+N) — cria nova conversa
- **Automations** — badge "New"
- **Customize** — abre Settings
- **Lista de repositorios** com conversas aninhadas
- **Perfil do usuario** (avatar, nome, plano)
- **Menu do usuario** — Settings (Ctrl+,), Docs, Shortcuts, Contact, Log Out
- Toggle sidebar via hamburger

### 3. Chat Area

#### Welcome Screen (sem mensagens)
- Header "Home > Local"
- Input box com placeholder: "Plan, Build, / for skills, @ for context"
- Toolbar: botao "+", botao do modo ativo, "Auto" dropdown, microfone
- "Plan New Idea" (Cmd+Tab)
- Footer hint sobre `/model`

#### Messages View (com mensagens)
- Mensagens do usuario (alinhamento direita, fundo escuro)
- Mensagens do agente (alinhamento esquerda, sem fundo)
- Indicador "thinking" (3 pontos pulsantes)
- Streaming de resposta char-a-char com cursor
- Markdown renderizado (code blocks com copy, headers, bold, italic, lists, links, tables)

### 4. Dropdown "+"
- Header: "Add agents, context, tools..."
- Modos: Plan, Build, Debug, Multitask, Ask
- Agentes: Composer, Office, Plan Agent
- Skills, MCP Servers (com submenu)

### 5. Model Dropdown (Auto)
- Toggle Auto (ligado/desligado)
- Modelos: Composer 2.5 Fast, Opus 4.8, GPT-5.5, Sonnet 4.6, Codex 5.3, Fable 5
- Busca por modelo
- Botao "Add Models"

### 6. Voice Input (simulado)
- Estados: idle, listening, processing, speaking
- Indicadores visuais (dots coloridos + texto)

### 7. Settings Screen
- 15 paineis de navegacao
- General, Appearance, Models, Agents, Plugins, Tools & MCPs, etc.
- Toggle switches para configuracoes

## Backend (main.ts)

### IPC Handlers

| Handler | Parametros | Retorno | Descricao |
|---------|-----------|---------|-----------|
| `get-status` | — | `{version, exeExists, home, projects}` | Status do opencode.exe |
| `execute-prompt` | `(prompt, agent?)` | `{stdout, stderr, code}` | Executa prompt via `opencode.exe run` |
| `open-terminal` | `(projectPath?)` | `{success}` | Abre terminal com opencode.exe |
| `select-folder` | — | `string \| null` | Abre dialogo de selecao de pasta |

### Fluco do Execute Prompt

```
Renderer: api.executePrompt("criar funcao hello", "composer")
    │
    ▼
Preload: ipcRenderer.invoke('execute-prompt', prompt, agent)
    │
    ▼
Main: spawn('bin/opencode.exe', ['run', prompt, '--agent', agent, '--dangerously-skip-permissions'])
    │
    ▼
opencode.exe: executa prompt com o agent especificado
    │
    ▼
Main: resolve({stdout, stderr, code})
    │
    ▼
Renderer: strip ANSI codes → streamResponse() → renderiza Markdown
```

### Mapeamento de Agentes

| Modo no Dropdown | Agent OpenCode | Descricao |
|-----------------|----------------|-----------|
| Plan | `plan` | Analise e planejamento (somente leitura) |
| Build | `composer` | Construcao com TDD |
| Debug | `composer` | Debug com skills especializadas |
| Multitask | `composer` | Tarefas paralelas |
| Ask | `composer` | Pergunta direta |
| Composer | `composer` | Orquestrador de workflows |
| Office | `office` | Documentos Word, Excel, PowerPoint |
| Plan Agent | `plan` | Agente de planejamento |

## Modulos Compartilhados (scripts/shared/)

| Modulo | Funcoes |
|--------|---------|
| `logging.ps1` | `Write-LogEntry`, `Rotate-LogFiles` |
| `version.ps1` | `Test-OpenCodeExe`, `Get-LatestVersion`, `Download-OpenCodeExe` |
| `setup.ps1` | `Ensure-Python`, `Run-InitialSetup` |
| `project.ps1` | `Select-Project`, `Ensure-BrainStructure` |
| `env.ps1` | `Update-OpenCodeConfig`, `Start-OpenCodeServices`, `Set-OpenCodeEnv` |

## Tecnologias

| Componente | Versao |
|------------|--------|
| Electron | 33.4.11 |
| TypeScript | 5.9.3 |
| Node.js | 26.3.0 |

## Estado Atual

- [x] Titlebar customizado com controles
- [x] Sidebar com conversas
- [x] Chat com Markdown e streaming
- [x] Dropdown de modos/agentes
- [x] Integracao com opencode.exe via IPC
- [x] Selecao de modelo
- [x] Sistema de voz (simulado)
- [x] Tela de Settings completa
- [x] Persistencia via localStorage
- [x] Atalhos de teclado (Ctrl+N, Ctrl+, Escape, Enter)
- [ ] Audio de voz real
- [ ] Conexao com MCP servers do Electron
- [ ] Upload de arquivos
- [ ] Multi-window
