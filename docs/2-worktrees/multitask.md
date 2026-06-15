# Multitask Agent

Agent que permite executar multiplas tarefas em background.

## Localizacao

```
Plugin: "multitask" (interno)
TUI: "multitask-tui.tsx" (interno)
```

## Funcionalidade

O multitask agent permite que o OpenCode execute varias tarefas simultaneamente:

```
┌─────────────────────────────────────────────────┐
│  Usuario inicia tarefa                          │
│      │                                          │
│      ▼                                          │
│  Multitask Agent cria subagent                  │
│      │                                          │
│      ├──▶ Subagent 1: Editar codigo             │
│      ├──▶ Subagent 2: Rodar testes              │
│      └──▶ Subagent 3: Documentar                │
│                                                 │
│  Resultados consolidados ao final               │
└─────────────────────────────────────────────────┘
```

## Como Usar

1. Inicie o OpenCode
2. O multitask agent esta disponivel automaticamente
3. Para tarefas complexas, ele cria subagents

## Configuracao

Habilitado via variavel de ambiente:

```batch
set "OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true"
```

## Limitacoes

- Subagents rodam em background (nao bloqueiam a UI)
- Cada subagent tem seu proprio contexto
- Resultados sao consolidados ao final da tarefa
- Worktrees temporarios sao criados em `%TEMP%\opencode-worktrees`

## Arquivos Relacionados

- `multitask-tui.tsx`: Interface do usuario para multitask
- `workspace-tui.tsx`: Interface de workspaces
- `opencode.bat`: Configura juncao `multitask-worktrees`
