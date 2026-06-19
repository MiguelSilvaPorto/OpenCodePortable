#!/usr/bin/env python3
"""
brain_mcp.py - Servidor MCP para o sistema .brain
Fornece ferramentas nativas para gerenciar memoria vetorial portatil.
"""

import os
import sys
import json
import math
import sqlite3
import urllib.request
import urllib.error
from datetime import datetime
from mcp.server.fastmcp import FastMCP

# Configuracao
BRAIN_DIR = os.path.join(os.getcwd(), ".brain")
DB_PATH = os.path.join(BRAIN_DIR, "memory.db")
SESSIONS_DIR = os.path.join(BRAIN_DIR, "sessions")
CURRENT_SESSION_FILE = os.path.join(BRAIN_DIR, "current_session.txt")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/api/embeddings")
EMBED_MODEL = os.environ.get("BRAIN_EMBED_MODEL", "nomic-embed-text")
EMBED_DIM = 768

mcp = FastMCP("Brain", instructions="""
Sistema de memoria portatil com busca vetorial para o OpenCode.

Este servidor MCP fornece ferramentas para gerenciar memoria de longo prazo do agente.
Cada sessao de conversa tem seu proprio UUID isolado, armazenado em .brain/sessions/{UUID}/.
O banco de dados SQLite (.brain/memory.db) armazena embeddings vetoriais para busca semantica.

FLUXO PADRAO:
1. Chame brain_init no inicio de toda conversa para garantir que a sessao esta ativa
2. Use brain_add para armazenar informacoes relevantes (decisoes, imagens, codigo, erros)
3. Use brain_search ANTES de responder perguntas que exigem contexto anterior
4. Chame brain_sync periodicamente para manter o Markdown legivel atualizado

O sistema funciona offline com fallback (hash embeddings) se o Ollama nao estiver disponivel.
Para busca semantica precisa, o Ollama deve estar rodando com o modelo nomic-embed-text.
""")

# ==========================================
# UTILITARIOS
# ==========================================

def get_embedding(text):
    """Gera embedding via Ollama. Fallback para hash se indisponivel."""
    data = json.dumps({"model": EMBED_MODEL, "prompt": text}).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_URL,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            emb = result.get("embedding", [])
            if emb:
                return emb, "ollama"
    except (urllib.error.URLError, OSError, KeyError, ValueError):
        pass
    return simple_hash_embedding(text), "fallback"


def simple_hash_embedding(text, dim=EMBED_DIM):
    """Embedding fallback baseado em hash de palavras."""
    vec = [0.0] * dim
    for word in text.lower().split():
        h = abs(hash(word)) % dim
        vec[h] += 1.0
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / norm for v in vec]


def cosine_similarity(a, b):
    """Similaridade por cosseno entre dois vetores."""
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def get_db():
    """Retorna conexao com o banco SQLite."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS memory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            turn INTEGER,
            text TEXT NOT NULL,
            embedding TEXT NOT NULL,
            source TEXT DEFAULT 'ollama',
            created_at TEXT DEFAULT (datetime('now'))
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_session ON memory(session_id)")
    conn.commit()
    return conn


def read_current_session():
    """Le o UUID da sessao ativa."""
    if os.path.exists(CURRENT_SESSION_FILE):
        with open(CURRENT_SESSION_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    return None


def write_current_session(uuid_str):
    """Escreve o UUID da sessao ativa."""
    with open(CURRENT_SESSION_FILE, "w", encoding="utf-8") as f:
        f.write(uuid_str)


def create_session_structure(uuid_str):
    """Cria a estrutura de pastas e arquivos da sessao."""
    session_dir = os.path.join(SESSIONS_DIR, uuid_str)
    os.makedirs(session_dir, exist_ok=True)

    metadata_path = os.path.join(session_dir, "metadata.json")
    if not os.path.exists(metadata_path):
        metadata = {
            "session_id": uuid_str,
            "workspace_relative_root": f"./.brain/sessions/{uuid_str}",
            "created_date": datetime.now().strftime("%Y-%m-%d"),
            "status": "active",
            "parent_session_id": None,
            "title": "Sessao auto-gerada"
        }
        with open(metadata_path, "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)

    memory_path = os.path.join(session_dir, "session_memory.md")
    if not os.path.exists(memory_path):
        with open(memory_path, "w", encoding="utf-8") as f:
            f.write(f"# Memoria da Sessao: {uuid_str}\n\n")

    history_path = os.path.join(session_dir, "session_history.md")
    if not os.path.exists(history_path):
        with open(history_path, "w", encoding="utf-8") as f:
            f.write(f"# Historico Condensado: {uuid_str}\n\n")

    return session_dir


# ==========================================
# TOOLS MCP
# ==========================================

@mcp.tool()
def brain_init() -> str:
    """
    Inicializa o sistema brain e retorna o UUID da sessao ativa.

    Esta tool DEVE ser chamada no inicio de toda conversa, antes de qualquer
    operacao de memoria. Ela garante que:

    1. Se ja existe uma sessao ativa (current_session.txt existe):
       - Valida que a pasta da sessao existe no disco
       - Retorna o UUID existente

    2. Se NAO existe sessao ativa:
       - Gera um UUID novo via python uuid.uuid4()
       - Cria a estrutura de pastas: .brain/sessions/{UUID}/
       - Cria os arquivos: metadata.json, session_memory.md, session_history.md
       - Salva o UUID em .brain/current_session.txt
       - Registra a primeira entrada no SQLite

    RETORNO:
    - status: "ok" (sessao existente) ou "created" (nova sessao)
    - session_id: UUID da sessao ativa
    - message: Mensagem descritiva

    EXEMPLO DE USO:
    brain_init()
    # Retorna: {"status": "created", "session_id": "a1b2c3d4-...", "message": "Nova sessao criada: a1b2c3d4-..."}
    """
    uuid_str = read_current_session()

    if uuid_str:
        session_dir = os.path.join(SESSIONS_DIR, uuid_str)
        if os.path.exists(session_dir):
            return json.dumps({
                "status": "ok",
                "session_id": uuid_str,
                "message": f"Sessao ativa: {uuid_str}"
            }, ensure_ascii=False)

    import uuid
    uuid_str = str(uuid.uuid4())
    write_current_session(uuid_str)
    session_dir = create_session_structure(uuid_str)

    conn = get_db()
    conn.execute(
        "INSERT INTO memory (session_id, turn, text, embedding, source) VALUES (?, ?, ?, ?, ?)",
        (uuid_str, 0, f"[INICIO] Sessao {uuid_str} iniciada", json.dumps([0.0] * EMBED_DIM), "system"),
    )
    conn.commit()
    conn.close()

    return json.dumps({
        "status": "created",
        "session_id": uuid_str,
        "message": f"Nova sessao criada: {uuid_str}"
    }, ensure_ascii=False)


@mcp.tool()
def brain_add(text: str, turn: int = 0) -> str:
    """
    Armazena uma memoria na sessao ativa com embedding vetorial para busca semantica.

    Esta tool converte o texto em um vetor numerico (embedding) usando Ollama
    (ou fallback via hash) e armazena no SQLite para busca futura por similaridade.

    QUANDO USAR:
    - Decisoes de arquitetura ou design
    - Descricoes de imagens enviadas pelo usuario (use prefixo [IMAGEM])
    - Codigo importante criado ou alterado
    - Erros encontrados e solucoes aplicadas
    - Contexto de escopo do trabalho atual
    - Mudancas de direcao na conversa

    PARAMETROS:
    - text: Texto da memoria (obrigatorio). Seja conciso e denso em contexto.
           Para imagens: "[IMAGEM] nome_arquivo.png: descricao visual detalhada"
    - turn: Numero do turno na conversa (opcional, default=0). Use contagem
           numerica incremental: 1, 2, 3, etc. Nunca timestamps.

    RETORNO:
    - status: "ok" ou "error"
    - id: ID da entrada no SQLite
    - session_id: UUID da sessao
    - turn: Turno registrado
    - embedding_dim: Dimensao do vetor (768 para nomic-embed-text)
    - source: "ollama" ou "fallback"
    - message: Mensagem descritiva

    EXEMPLO DE USO:
    brain_add(text="Decisao: usar SQLite com busca vetorial para memoria", turn=5)
    # Retorna: {"status": "ok", "id": 1, "session_id": "...", "turn": 5, "embedding_dim": 768, "source": "ollama", "message": "Memoria registrada (Turno 5)"}
    """
    uuid_str = read_current_session()
    if not uuid_str:
        return json.dumps({"error": "Nenhuma sessao ativa. Chame brain_init primeiro."})

    embedding, source = get_embedding(text)
    conn = get_db()
    conn.execute(
        "INSERT INTO memory (session_id, turn, text, embedding, source) VALUES (?, ?, ?, ?, ?)",
        (uuid_str, turn, text, json.dumps(embedding), source),
    )
    conn.commit()
    cur = conn.execute("SELECT last_insert_rowid()")
    row_id = cur.fetchone()[0]
    conn.close()

    return json.dumps({
        "status": "ok",
        "id": row_id,
        "session_id": uuid_str,
        "turn": turn,
        "embedding_dim": len(embedding),
        "source": source,
        "message": f"Memoria registrada (Turno {turn})"
    }, ensure_ascii=False)


@mcp.tool()
def brain_search(query: str, limit: int = 5) -> str:
    """
    Busca semantica na memoria por similaridade de cosseno.

    Esta tool converte a query em um embedding e compara com todas as memorias
    armazenadas na sessao ativa, retornando as mais relevantes por score de
    similaridade (0.0 a 1.0).

    QUANDO USAR:
    - ANTES de responder perguntas que exigem contexto de sessoes anteriores
    - Quando o usuario pergunta sobre algo que ja foi discutido
    - Para encontrar decisoes, erros ou codigo relevante anteriormente
    - Para buscar descricoes de imagens que foram enviadas

    PARAMETROS:
    - query: Texto da consulta (obrigatorio). Use a mesma lingua do usuario.
    - limit: Maximo de resultados retornados (opcional, default=5, max=20)

    RETORNO:
    - query_source: "ollama" ou "fallback"
    - results: Lista de resultados ordenados por score desc:
       - id: ID no SQLite
       - session: UUID da sessao
       - turn: Turno registrado
       - text: Texto original da memoria
       - score: Similaridade (0.0 a 1.0, >0.5 = relevante)
    - total_scanned: Total de entradas verificadas

    EXEMPLO DE USO:
    brain_search("como funciona a memoria do agente")
    # Retorna resultados com scores, ex: [{"turn": 5, "text": "...", "score": 0.89}]
    """
    uuid_str = read_current_session()
    if not uuid_str:
        return json.dumps({"error": "Nenhuma sessao ativa. Chame brain_init primeiro."})

    query_emb, source = get_embedding(query)
    conn = get_db()
    cur = conn.execute(
        "SELECT id, session_id, turn, text, embedding FROM memory WHERE session_id = ?",
        (uuid_str,),
    )
    results = []
    for row in cur.fetchall():
        rid, sid, turn, text, emb_json = row
        emb = json.loads(emb_json)
        score = cosine_similarity(query_emb, emb)
        results.append({
            "id": rid,
            "session": sid,
            "turn": turn,
            "text": text,
            "score": round(score, 4),
        })
    conn.close()

    results.sort(key=lambda x: x["score"], reverse=True)
    top = results[:limit]

    return json.dumps({
        "query_source": source,
        "results": top,
        "total_scanned": len(results)
    }, ensure_ascii=False, indent=2)


@mcp.tool()
def brain_list(limit: int = 20) -> str:
    """
    Lista as memorias da sessao ativa.
    Use para ver o historico de memorias registradas.
    """
    uuid_str = read_current_session()
    if not uuid_str:
        return json.dumps({"error": "Nenhuma sessao ativa. Chame brain_init primeiro."})

    conn = get_db()
    cur = conn.execute(
        "SELECT id, turn, text, source, created_at FROM memory WHERE session_id = ? ORDER BY turn LIMIT ?",
        (uuid_str, limit),
    )
    rows = cur.fetchall()
    conn.close()

    entries = [
        {
            "id": r[0],
            "turn": r[1],
            "text": r[2],
            "source": r[3],
            "created_at": r[4],
        }
        for r in rows
    ]

    return json.dumps({
        "session_id": uuid_str,
        "entries": entries,
        "count": len(entries)
    }, ensure_ascii=False, indent=2)


@mcp.tool()
def brain_status() -> str:
    """
    Mostra o status atual da memoria: UUID ativo, total de entradas, ultimas 3 memorias.
    """
    uuid_str = read_current_session()
    if not uuid_str:
        return json.dumps({
            "status": "no_session",
            "message": "Nenhuma sessao ativa. Chame brain_init para criar uma."
        }, ensure_ascii=False)

    conn = get_db()
    cur = conn.execute("SELECT COUNT(*) FROM memory WHERE session_id = ?", (uuid_str,))
    total = cur.fetchone()[0]

    cur = conn.execute(
        "SELECT turn, text, created_at FROM memory WHERE session_id = ? ORDER BY id DESC LIMIT 3",
        (uuid_str,),
    )
    last_3 = [{"turn": r[0], "text": r[1], "created_at": r[2]} for r in cur.fetchall()]
    conn.close()

    metadata_path = os.path.join(SESSIONS_DIR, uuid_str, "metadata.json")
    title = "Sessao auto-gerada"
    if os.path.exists(metadata_path):
        with open(metadata_path, "r", encoding="utf-8") as f:
            meta = json.load(f)
            title = meta.get("title", title)

    return json.dumps({
        "session_id": uuid_str,
        "title": title,
        "total_entries": total,
        "last_3_memories": last_3
    }, ensure_ascii=False, indent=2)


@mcp.tool()
def brain_sync() -> str:
    """
    Sincroniza o SQLite para session_memory.md (arquivo legivel).
    Use periodicamente ou quando o usuario pedir.
    """
    uuid_str = read_current_session()
    if not uuid_str:
        return json.dumps({"error": "Nenhuma sessao ativa. Chame brain_init primeiro."})

    conn = get_db()
    cur = conn.execute(
        "SELECT turn, text, created_at FROM memory WHERE session_id = ? ORDER BY turn",
        (uuid_str,),
    )
    rows = cur.fetchall()
    conn.close()

    session_dir = os.path.join(SESSIONS_DIR, uuid_str)
    os.makedirs(session_dir, exist_ok=True)
    md_path = os.path.join(session_dir, "session_memory.md")

    lines = [f"# Memoria da Sessao: {uuid_str}", ""]
    for turn, text, created in rows:
        lines.append(f"- [Turno {turn}] {text}")
        lines.append(f"  _registrado em {created}_")
        lines.append("")

    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    return json.dumps({
        "status": "ok",
        "synced": len(rows),
        "file": md_path,
        "message": f"{len(rows)} memorias sincronizadas para {md_path}"
    }, ensure_ascii=False)


if __name__ == "__main__":
    mcp.run()
