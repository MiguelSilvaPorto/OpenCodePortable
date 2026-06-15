# Seletor de Projetos

Sistema de gerenciamento de projetos do OpenCode Portable.

## Localizacao

```
Projects/              # Diretorio raiz de projetos
opencode.ps1           # Seletor interativo (PowerShell)
```

## Funcionalidade

O OpenCode Portable gerencia multiplos projetos em uma pasta centralizada:

```
OpenCodePortable/
├── Projects/
│   ├── Default/       # Projeto padrao
│   ├── ProjetoA/      # Projetos do usuario
│   └── ProjetoB/
├── bin/
├── config/
└── data/
```

## Comportamento

### PowerShell (opencode.ps1)

 Interface interativa completa:

```
============================================
  OpenCode - Seletor de Projetos
============================================

Projetos Existentes:
  [1] ProjetoA
  [2] ProjetoB

Opcoes:
  [0] Criar Novo Projeto
  [Q] Sair

Escolha uma opcao:
```

- **1 projeto**: Abre automaticamente
- **2+ projetos**: Mostra seletor
- **0 projetos**: Cria `Default/` e abre

### BAT (opencode.bat)

- Usa o primeiro argumento como caminho do projeto
- Se nao fornecido, usa diretorio atual

## Criacao de Projetos

Ao criar um novo projeto via PowerShell:

1. Cria pasta em `Projects/[nome]`
2. Inicializa Git (`git init`)
3. Cria commit inicial
4. Configura `.opencode/workspace.json`
5. Opcao de criar repo GitHub (via `gh` CLI)

## workspace.json

```json
{
    "mode": "local",
    "limitGB": 10
}
```

| Campo | Valores | Descricao |
|-------|---------|-----------|
| `mode` | `local` / `cloud` | Local ou GitHub |
| `limitGB` | Numero | Limite de armazenamento |

## Uso

```powershell
# Abrir seletor
.\opencode.ps1

# Abrir projeto especifico
.\opencode.ps1 "C:\meu\projeto"

# Abrir por nome (se esta em Projects/)
.\opencode.ps1 "ProjetoA"
```
