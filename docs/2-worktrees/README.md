# 2. Worktrees

Esta secao documenta o sistema de worktrees do OpenCode Portable, incluindo multitask agent, plan mode e seletor de projetos.

## Arquivos

| Arquivo | Descricao |
|---------|-----------|
| [multitask.md](multitask.md) | Agent multitask para tarefas em background |
| [plan-mode.md](plan-mode.md) | Modo de planejamento estruturado |
| [projetos.md](projetos.md) | Seletor e gerenciamento de projetos |

## Conceito

Worktrees sao copias de um repositorio Git que permitem trabalhar em branches diferentes simultaneamente. O OpenCode Portable usa worktrees para:

- Executar subagents em background
- Isolar tarefas do plan mode
- Gerenciar multiplos projetos

## Estrutura de Pastas

```
Projects/
├── Default/           # Projeto padrao (criado automaticamente)
├── ProjetoA/          # Projetos do usuario
├── ProjetoB/
└── multitask-worktrees/  # Juncao para TEMP (evita recursao)
```

## Variavel de Ambiente

```batch
set "OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true"
set "OPENCODE_EXPERIMENTAL_PLAN_MODE=true"
```

## Juncao Multitask-Worktrees

Para evitar erros de recursao do multitask agent, o OpenCode cria uma juncao simbolica:

```batch
if exist "multitask-worktrees" rmdir /s /q "multitask-worktrees"
if not exist "%TEMP%\opencode-worktrees" mkdir "%TEMP%\opencode-worktrees"
mklink /j "multitask-worktrees" "%TEMP%\opencode-worktrees"
```

Isso redireciona worktrees temporarios para a pasta TEMP do sistema.
