# OpenCode Portable - Documentacao

Indice geral da documentacao do projeto OpenCode Portable.

## Estrutura

```
docs/
├── README.md              # Este arquivo
├── 1-ui/                  # Interface do Usuario
├── 2-worktrees/           # Sistema de Worktrees
├── 3-mcp/                 # Ferramentas MCP
├── 4-plugins/             # Plugins
├── 5-nvidia-router/       # NVIDIA Model Router
├── scripts/               # Scripts Auxiliares
├── data/                  # Dados Runtime
└── tests/                 # Testes
```

## 1. Interface do Usuario

Documentacao sobre launchers, configuracao e sistema de voz.

- [Visao Geral](1-ui/README.md)
- [Launcher BAT](1-ui/opencode.bat.md)
- [Launcher PowerShell](1-ui/opencode.ps1.md)
- [Configuracao](1-ui/config.md)
- [Sistema de Voz](1-ui/voice.md)

## 2. Worktrees

Documentacao sobre plan mode e seletor de projetos.

- [Visao Geral](2-worktrees/README.md)
- [Plan Mode](2-worktrees/plan-mode.md)
- [Seletor de Projetos](2-worktrees/projetos.md)

## 3. Ferramentas MCP

Documentacao sobre os servidores MCP (Model Context Protocol).

- [Visao Geral](3-mcp/README.md)
- [Office MCP](3-mcp/office-mcp.md) — 51 tools (Word, Excel, PPT, PDF)
- [Brain MCP](3-mcp/brain-mcp.md) — Memoria portatil com busca vetorial
- [Project MCP](3-mcp/project-mcp.md)
- [Configuracao MCP](3-mcp/configuracao.md)

## 4. Plugins

Documentacao sobre os plugins do OpenCode.

- [Visao Geral](4-plugins/README.md)
- [Voice Plugin](4-plugins/voice-plugin.md)
- [Workspace Plugin](4-plugins/workspace-plugin.md)
- [Auto-Switch Plugin](4-plugins/auto-switch-plugin.md)

## 5. NVIDIA Model Router

Proxy server local que roteia requisicoes entre multiplos modelos gratuitos da NVIDIA com fallback inteligente.

- [Visao Geral](5-nvidia-router/README.md)

## Scripts Auxiliares

- [Install BAT](scripts/install.md)
- [Install Office Deps](scripts/install-office-deps.md)
- [OpenCode Monitor](scripts/opencode-monitor.md)

## Dados Runtime

- [Estrutura da Pasta Data](data/estrutura.md)

## Testes

- [Framework de Testes](tests/run-tests.md)
