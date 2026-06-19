#!/usr/bin/env python3
"""
.brain/scripts/brain_memory.py
Engine de memoria vetorial portatil para o OpenCode.

Dependencias: Apenas stdlib (sqlite3, urllib, json, math, argparse)
Requer: Ollama rodando localmente com modelo nomic-embed-text
        (baixar uma vez: ollama pull nomic-embed-text)

Uso:
    python .brain/scripts/brain_memory.py init
    python .brain/scripts/brain_memory.py add --session UUID --turn 5 --text "descricao"
    python .brain/scripts/brain_memory.py search "pergunta do usuario" --limit 5
    python .brain/scripts/brain_memory.py list --session UUID
    python .brain/scripts/brain_memory.py stats
    python .brain/scripts/brain_memory.py sync --session UUID
"""

import sqlite3
import json
import urllib.request
import urllib.error
import math
import os
import argparse
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BRAIN_DIR = os.path.dirname(SCRIPT_DIR)
DB_PATH = os.path.join(BRAIN_DIR, "memory.db")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/api/embeddings")
EMBED_MODEL = os.environ.get("BRAIN_EMBED_MODEL", "nomic-embed-text")
EMBED_DIM = 768


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
    """Embedding fallback baseado em hash de palavras (sem semantica)."""
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


def init_db():
    """Cria o banco SQLite se nao existir."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS memory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            turn INTEGER,
            text TEXT NOT NULL,
            embedding TEXT NOT NULL,
            source TEXT DEFAULT 'ollama',
            created_at TEXT DEFAULT (datetime('now'))
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_session ON memory(session_id)")
    conn.commit()
    conn.close()


def cmd_init(args):
    init_db()
    print(json.dumps({"status": "ok", "db": DB_PATH}))


def cmd_add(args):
    init_db()
    embedding, source = get_embedding(args.text)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "INSERT INTO memory (session_id, turn, text, embedding, source) VALUES (?, ?, ?, ?, ?)",
        (args.session, args.turn, args.text, json.dumps(embedding), source),
    )
    conn.commit()
    cur = conn.execute("SELECT last_insert_rowid()")
    row_id = cur.fetchone()[0]
    conn.close()
    print(
        json.dumps(
            {
                "status": "ok",
                "id": row_id,
                "session": args.session,
                "turn": args.turn,
                "embedding_dim": len(embedding),
                "source": source,
            }
        )
    )


def cmd_search(args):
    init_db()
    query_emb, source = get_embedding(args.query)
    conn = sqlite3.connect(DB_PATH)
    if args.session:
        cur = conn.execute(
            "SELECT id, session_id, turn, text, embedding FROM memory WHERE session_id = ?",
            (args.session,),
        )
    else:
        cur = conn.execute(
            "SELECT id, session_id, turn, text, embedding FROM memory"
        )
    results = []
    for row in cur.fetchall():
        rid, sid, turn, text, emb_json = row
        emb = json.loads(emb_json)
        score = cosine_similarity(query_emb, emb)
        results.append(
            {
                "id": rid,
                "session": sid,
                "turn": turn,
                "text": text,
                "score": round(score, 4),
            }
        )
    conn.close()
    results.sort(key=lambda x: x["score"], reverse=True)
    top = results[: args.limit]
    print(
        json.dumps(
            {"query_source": source, "results": top, "total_scanned": len(results)},
            ensure_ascii=False,
            indent=2,
        )
    )


def cmd_list(args):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    if args.session:
        cur = conn.execute(
            "SELECT id, session_id, turn, text, source, created_at FROM memory WHERE session_id = ? ORDER BY turn",
            (args.session,),
        )
    else:
        cur = conn.execute(
            "SELECT id, session_id, turn, text, source, created_at FROM memory ORDER BY id DESC LIMIT ?",
            (args.limit,),
        )
    rows = cur.fetchall()
    conn.close()
    entries = [
        {
            "id": r[0],
            "session": r[1],
            "turn": r[2],
            "text": r[3],
            "source": r[4],
            "created_at": r[5],
        }
        for r in rows
    ]
    print(
        json.dumps(
            {"entries": entries, "count": len(entries)},
            ensure_ascii=False,
            indent=2,
        )
    )


def cmd_stats(args):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.execute("SELECT COUNT(*) FROM memory")
    total = cur.fetchone()[0]
    cur = conn.execute("SELECT COUNT(DISTINCT session_id) FROM memory")
    sessions = cur.fetchone()[0]
    cur = conn.execute("SELECT session_id, COUNT(*) FROM memory GROUP BY session_id")
    per_session = {row[0]: row[1] for row in cur.fetchall()}
    conn.close()
    print(
        json.dumps(
            {
                "total_entries": total,
                "total_sessions": sessions,
                "per_session": per_session,
                "db_path": DB_PATH,
                "ollama_url": OLLAMA_URL,
                "embed_model": EMBED_MODEL,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


def cmd_sync(args):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.execute(
        "SELECT turn, text, created_at FROM memory WHERE session_id = ? ORDER BY turn",
        (args.session,),
    )
    rows = cur.fetchall()
    conn.close()
    session_dir = os.path.join(BRAIN_DIR, "sessions", args.session)
    os.makedirs(session_dir, exist_ok=True)
    md_path = os.path.join(session_dir, "session_memory.md")
    lines = ["# Memoria da Sessao (sync do SQLite)", ""]
    for turn, text, created in rows:
        lines.append(f"- [Turno {turn}] {text}")
        lines.append(f"  _registrado em {created}_")
        lines.append("")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(
        json.dumps(
            {"status": "ok", "synced": len(rows), "file": md_path},
            ensure_ascii=False,
        )
    )


def main():
    parser = argparse.ArgumentParser(
        description="Brain Memory - Busca Vetorial Portatil"
    )
    sub = parser.add_subparsers(dest="command")

    p_init = sub.add_parser("init", help="Inicializa o banco SQLite")
    p_init.set_defaults(func=cmd_init)

    p_add = sub.add_parser("add", help="Adiciona entrada na memoria vetorial")
    p_add.add_argument("--session", required=True, help="UUID da sessao")
    p_add.add_argument("--turn", type=int, default=0, help="Numero do turno")
    p_add.add_argument("--text", required=True, help="Texto da memoria")
    p_add.set_defaults(func=cmd_add)

    p_search = sub.add_parser("search", help="Busca semantica na memoria")
    p_search.add_argument("query", help="Texto da consulta")
    p_search.add_argument("--session", default=None, help="Filtrar por sessao")
    p_search.add_argument("--limit", type=int, default=5, help="Max de resultados")
    p_search.set_defaults(func=cmd_search)

    p_list = sub.add_parser("list", help="Lista entradas da memoria")
    p_list.add_argument("--session", default=None)
    p_list.add_argument("--limit", type=int, default=20)
    p_list.set_defaults(func=cmd_list)

    p_stats = sub.add_parser("stats", help="Estatisticas do banco")
    p_stats.set_defaults(func=cmd_stats)

    p_sync = sub.add_parser("sync", help="Sincroniza SQLite para session_memory.md")
    p_sync.add_argument("--session", required=True, help="UUID da sessao")
    p_sync.set_defaults(func=cmd_sync)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)
    args.func(args)


if __name__ == "__main__":
    main()
