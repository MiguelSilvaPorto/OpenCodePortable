# 2. Worktrees

Esta secao documenta o sistema de worktrees do OpenCode Portable, incluindo plan mode e seletor de projetos.

## Arquivos

| Arquivo | Descricao |
|---------|-----------|
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
└── ProjetoB/
```

## Variavel de Ambiente

```batch
set "OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true"
set "OPENCODE_EXPERIMENTAL_PLAN_MODE=true"
```
