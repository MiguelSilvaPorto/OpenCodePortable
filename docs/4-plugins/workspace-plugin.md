# Workspace Plugin

Plugin de gerenciamento de workspaces do OpenCode.

## Localizacao

```
Plugin: "workspace-tui.tsx" (interno)
```

## Funcionalidade

Fornece interface TUI para gerenciar workspaces e projetos:

```
┌─────────────────────────────────────────────────┐
│  Workspace TUI                                  │
│                                                 │
│  Projetos:                                      │
│  ├── Default                                    │
│  ├── ProjetoA                                   │
│  └── ProjetoB                                   │
│                                                 │
│  [N] Novo  [A] Abrir  [D] Deletar  [Q] Sair    │
└─────────────────────────────────────────────────┘
```

## Configuracao

Listado no config:

```jsonc
"plugin": [
    "workspace-tui.tsx",
    ...
]
```

## Integracao

- Trabalha com `Projects/` directory
- Cria workspace automaticamente
- Gerencia `.opencode/workspace.json`
- Suporta Git e GitHub (via `gh` CLI)

## workspace.json

```json
{
    "mode": "local",
    "limitGB": 10
}
```
