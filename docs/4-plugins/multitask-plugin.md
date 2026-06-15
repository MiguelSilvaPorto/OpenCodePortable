# Multitask Plugin

Plugin que fornece o agent multitask para execucao de tarefas em background.

## Localizacao

```
Plugin: "multitask" (interno)
TUI: "multitask-tui.tsx" (interno)
```

## Funcionalidade

Permite executar multiplas tarefas simultaneamente via subagents:

```
┌─────────────────────────────────────────────────┐
│  Usuario: "Refatore modulo X e rode testes"     │
│      │                                          │
│      ▼                                          │
│  Multitask Agent                                │
│      │                                          │
│      ├──▶ Subagent 1: Refatorar modulo X        │
│      ├──▶ Subagent 2: Rodar testes              │
│      └──▶ Aguardar conclusao                    │
│                                                 │
│  Resultado consolidado                          │
└─────────────────────────────────────────────────┘
```

## Configuracao

Habilitado via variavel de ambiente:

```batch
set "OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true"
```

E listado no config:

```jsonc
"plugin": [
    "multitask",
    "multitask-tui.tsx",
    ...
]
```

## Arquivos

| Arquivo | Funcao |
|---------|--------|
| `multitask` | Plugin principal (agent) |
| `multitask-tui.tsx` | Interface do usuario |

## Limitacoes

- Subagents rodam em background
- Cada subagent tem contexto isolado
- Worktrees temporarios em `%TEMP%\opencode-worktrees`
- Juncao `multitask-worktrees` criada pelo launcher
