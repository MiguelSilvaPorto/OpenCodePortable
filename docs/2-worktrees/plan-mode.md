# Plan Mode

Modo de planejamento estruturado do OpenCode.

## Localizacao

```
Variavel: OPENCODE_EXPERIMENTAL_PLAN_MODE=true
Agent: "plan" (interno)
```

## Funcionalidade

O Plan Mode permite criar planos detalhados antes de executar mudancas:

```
┌─────────────────────────────────────────────────┐
│  Usuario descreve tarefa                        │
│      │                                          │
│      ▼                                          │
│  Plan Agent cria plano estruturado              │
│      │                                          │
│      ├──▶ Analise do codigo                     │
│      ├──▶ Identificacao de arquivos             │
│      ├──▶ Definicao de passos                   │
│      └──▶ Estimativa de impacto                 │
│                                                 │
│  Usuario aprova/rejeita o plano                  │
│      │                                          │
│      ▼                                          │
│  Execucao do plano                              │
└─────────────────────────────────────────────────┘
```

## Como Usar

1. Descreva a tarefa desejada
2. O Plan Agent cria um plano em `.opencode/plans/`
3. Revise o plano
4. Aprove para executar

## Estrutura do Plano

```markdown
# Plano: [Nome da Tarefa]

## Objetivo
[Descricao do que sera feito]

## Arquivos a Modificar
| Arquivo | Mudanca |
|---------|---------|
| arquivo1.js | Adicionar funcao X |
| arquivo2.ts | Remover classe Y |

## Passos
1. [ ] Passo 1
2. [ ] Passo 2
3. [ ] Passo 3

## Verificacao
- Testes a serem executados
- Criterios de aceitacao
```

## Localizacao dos Planos

Planos sao salvos em:
- `.opencode/plans/` (no repositorio)
- `data/plans/` (fallback local)

## Configuracao

Habilitado via variavel de ambiente:

```batch
set "OPENCODE_EXPERIMENTAL_PLAN_MODE=true"
```

## Vantagens

- Planejamento antes de execucao
- Revisao humana antes de mudancas
- Documentacao automatica de decisoes
- Reducao de erros em tarefas complexas
