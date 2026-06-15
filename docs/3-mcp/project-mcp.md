# Project MCP

Servidor MCP para criacao de projetos isolados.

## Localizacao

```
scripts/project_generator.py
```

## Ferramenta

### create_isolated_project

Cria uma nova pasta fisica isolada para um projeto.

**Parametros:**

| Parametro | Tipo | Obrigatorio | Descricao |
|-----------|------|-------------|-----------|
| `project_name` | string | Sim | Nome do projeto |
| `mode` | string | Nao | `local` (padrao) ou `cloud` |

**Retorno:**

```json
{
    "status": "success",
    "project_name": "MeuProjeto",
    "path": "D:/Github/OpencodePortable/Projects/MeuProjeto",
    "mode": "local",
    "github": "Apenas local"
}
```

## O que e Criado

```
Projects/[nome_projeto]/
├── .opencode/
│   └── workspace.json     # Configuracao do workspace
├── README.md              # README inicial
└── .git/                  # Repositorio Git
```

### workspace.json

```json
{
    "mode": "local",
    "limitGB": 10
}
```

## Fluxo

1. Sanitiza nome do projeto (remove espacos, caracteres invalidos)
2. Cria pasta em `Projects/`
3. Inicializa Git (`git init`)
4. Cria commit inicial vazio
5. Cria estrutura `.opencode/workspace.json`
6. Cria `README.md` basico
7. Se `mode=cloud` e `gh` disponivel, cria repo GitHub privado

## Seguranca

- Nome sanitizado contra path traversal
- Evita sobrescrever pastas existentes (gera sufixo numerico)
- Git config isolado (autor: OpenCode)

## Exemplo de Uso

```python
# Via MCP
create_isolated_project("MeuProjeto", mode="local")

# Resultado
Projects/MeuProjeto/
├── .opencode/workspace.json
├── README.md
└── .git/
```
