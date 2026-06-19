# Brain MCP

Servidor MCP para sistema de memoria portatil com busca vetorial.

## Localizacao

```
.brain/scripts/brain_mcp.py
```

## O que e o Brain?

O Brain e um **segundo cerebro** para a IA. Armazena memorias de longo prazo com embeddings vetoriais para busca semantica. Cada sessao de conversa tem seu proprio UUID isolado.

## Ferramentas Disponiveis (6)

| Ferramenta | Descricao |
|------------|-----------|
| `brain_init` | Inicializa sessao, gera UUID automaticamente |
| `brain_add` | Armazena memoria com embedding vetorial |
| `brain_search` | Busca semantica por similaridade de cosseno |
| `brain_list` | Lista memorias da sessao ativa |
| `brain_status` | Mostra UUID ativo e estatisticas |
| `brain_sync` | Sincroniza SQLite para Markdown legivel |

## brain_init

Inicializa o sistema brain e retorna o UUID da sessao ativa.

**Quando usar:** No inicio de toda conversa, antes de qualquer operacao de memoria.

**O que faz:**
1. Se ja existe sessao ativa → retorna UUID existente
2. Se nao existe → gera UUID novo, cria estrutura de pastas, salva

**Exemplo:**
```
brain_init()
# Retorna: {"status": "created", "session_id": "a1b2c3d4-...", "message": "Nova sessao criada: a1b2c3d4-..."}
```

## brain_add

Armazena uma memoria na sessao ativa com embedding vetorial.

**Quando usar:**
- Decisoes de arquitetura ou design
- Descricoes de imagens (use prefixo `[IMAGEM]`)
- Codigo importante criado ou alterado
- Erros encontrados e solucoes aplicadas
- Contexto de escopo do trabalho atual
- Mudancas de direcao na conversa

**Parametros:**
- `text` (obrigatorio): Texto da memoria. Seja conciso e denso em contexto.
- `turn` (opcional, default=0): Numero do turno na conversa.

**Exemplo:**
```
brain_add(text="Decisao: usar SQLite com busca vetorial para memoria", turn=5)
# Retorna: {"status": "ok", "id": 1, "turn": 5, "embedding_dim": 768, "source": "ollama"}
```

## brain_search

Busca semantica na memoria por similaridade de cosseno.

**Quando usar:** ANTES de responder perguntas que exigem contexto de sessoes anteriores.

**Parametros:**
- `query` (obrigatorio): Texto da consulta.
- `limit` (opcional, default=5): Maximo de resultados.

**Exemplo:**
```
brain_search("como funciona a memoria do agente")
# Retorna resultados com scores: [{"turn": 5, "text": "...", "score": 0.89}]
```

**Score:** Valores > 0.5 indicam relevancia.

## brain_list

Lista as memorias da sessao ativa.

**Parametros:**
- `limit` (opcional, default=20): Maximo de entradas.

## brain_status

Mostra o status atual da memoria: UUID ativo, total de entradas, ultimas 3 memorias.

## brain_sync

Sincroniza o SQLite para session_memory.md (arquivo legivel).

**Quando usar:** Periodicamente ou quando o usuario pedir.

## Arquitetura

```
.brain/
├── .gitignore              # Ignora memory.db, session data
├── current_session.txt     # UUID da sessao ativa
├── memory.db               # SQLite com embeddings
├── sessions/
│   └── {UUID}/
│       ├── metadata.json
│       ├── session_memory.md
│       └── session_history.md
└── scripts/
    ├── brain_mcp.py        # Servidor MCP (6 tools)
    └── brain_memory.py     # Engine vetorial (standalone)
```

## Embeddings

| Source | Modelo | Dimensao |
|--------|--------|----------|
| Ollama | nomic-embed-text | 768 |
| Fallback | Hash de palavras | 768 |

O fallback funciona sem Ollama, mas com precisao reduzida.

## Portabilidade

- Todos os caminhos sao relativos (`./`)
- O `memory.db` e ignorado pelo Git
- O `scripts/brain_mcp.py` e rastreado pelo Git
- Funciona em qualquer maquina com Python + Ollama (opcional)

## Configuracao

```jsonc
"brain-mcp": {
    "type": "local",
    "command": ["python", ".brain/scripts/brain_mcp.py"],
    "enabled": true
}
```

## Dependencias

- Python (stdlib apenas: sqlite3, urllib, json, math)
- Ollama com nomic-embed-text (opcional, para busca precisa)
