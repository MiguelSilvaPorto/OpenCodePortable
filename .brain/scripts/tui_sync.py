#!/usr/bin/env python3
"""
tui_sync.py - Sincroniza dados do opencode TUI SQLite para .brain/ do projeto.

Operacao READ-ONLY no SQLite do TUI (nao bloqueia opencode.exe).
Operacao WRITE no .brain/ do projeto (registro portatil de chats).

Uso:
    python tui_sync.py                    # sync uma vez
    python tui_sync.py --loop 60          # sync a cada 60s
    python tui_sync.py --project <id>     # filtrar por project_id
"""

import os
import sys
import json
import time
import sqlite3
import argparse
import traceback
from pathlib import Path
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from get_tui_db_path import get_tui_db_path, get_portable_path

BRAIN_DIR = Path(os.path.join(os.getcwd(), '.brain'))
REGISTRY_PATH = BRAIN_DIR / 'chat_registry.json'
SESSIONS_DIR = BRAIN_DIR / 'sessions'
DELETED_DIR = SESSIONS_DIR / '_deleted'

DELETION_GRACE_SCANS = 3
DEFAULT_LOOP_INTERVAL = 60


def get_tui_connection():
    """Abre TUI SQLite em modo read-only (nao bloqueia opencode.exe)."""
    db_path = get_tui_db_path()
    if not db_path.exists():
        raise FileNotFoundError(f"TUI DB nao encontrado em: {db_path}")
    uri = f"file:{db_path}?mode=ro"
    return sqlite3.connect(uri, uri=True), db_path


def get_tui_sessions(conn, since_ms=None, project_id=None):
    """Le sessions do TUI. Filtra por time_updated se since_ms fornecido."""
    query = ("SELECT id, project_id, title, agent, model, time_created, "
             "time_updated, time_archived, parent_id, directory FROM session")
    params = []
    conditions = []
    if project_id:
        conditions.append("project_id = ?")
        params.append(project_id)
    elif since_ms:
        conditions.append("time_updated > ?")
        params.append(since_ms)
    if conditions:
        query += " WHERE " + " AND ".join(conditions)
    query += " ORDER BY time_updated DESC"
    return conn.execute(query, params).fetchall()


def get_message_count(conn, session_id):
    """Conta messages de uma session no TUI."""
    return conn.execute(
        "SELECT COUNT(*) FROM message WHERE session_id = ?", (session_id,)
    ).fetchone()[0]


def get_messages(conn, session_id):
    """Retorna todas as messages de uma session."""
    return conn.execute(
        "SELECT id, time_created, data FROM message WHERE session_id = ? "
        "ORDER BY time_created", (session_id,)
    ).fetchall()


def load_registry():
    """Carrega chat_registry.json. Retorna dict vazio se nao existir."""
    if REGISTRY_PATH.exists():
        try:
            with open(REGISTRY_PATH, encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            print(f"[tui-sync] WARN: registry corrompido, criando novo: {e}",
                  file=sys.stderr)
    db_path = get_tui_db_path()
    return {
        "version": 1,
        "last_sync": None,
        "last_sync_ms": 0,
        "tui_storage_path": get_portable_path(db_path),
        "platform_created": sys.platform,
        "stats": {"total_sessions": 0, "active": 0, "deleted": 0},
        "chats": {}
    }


def save_registry(registry):
    """Salva registry com backup do anterior."""
    REGISTRY_PATH.parent.mkdir(parents=True, exist_ok=True)
    if REGISTRY_PATH.exists():
        backup = REGISTRY_PATH.with_suffix('.json.bak')
        try:
            REGISTRY_PATH.replace(backup)
        except OSError:
            pass
    tmp_path = REGISTRY_PATH.with_suffix('.json.tmp')
    with open(tmp_path, 'w', encoding='utf-8') as f:
        json.dump(registry, f, indent=2, ensure_ascii=False)
    tmp_path.replace(REGISTRY_PATH)


def detect_title_change(entry, new_title):
    """Adiciona entrada em title_history se titulo mudou. Retorna True se mudou."""
    if entry.get('title') == new_title:
        return False
    if 'title_history' not in entry:
        entry['title_history'] = []
    if not entry['title_history'] or entry['title_history'][-1].get('title') != new_title:
        entry['title_history'].append({
            "title": new_title,
            "changed_at": datetime.utcnow().isoformat() + "Z",
            "source": "auto"
        })
    return True


def write_session_metadata(session_id, metadata):
    """Cria/atualiza metadata.json de uma session."""
    session_dir = SESSIONS_DIR / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    with open(session_dir / 'metadata.json', 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)


def write_session_messages(session_id, messages):
    """Escreve messages.jsonl com historico espelhado."""
    session_dir = SESSIONS_DIR / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    with open(session_dir / 'messages.jsonl', 'w', encoding='utf-8') as f:
        for msg_id, time_created, data in messages:
            try:
                parsed = json.loads(data) if isinstance(data, str) else data
            except json.JSONDecodeError:
                parsed = {"raw": data}
            entry = {
                "id": msg_id,
                "time_created": time_created,
                "data": parsed
            }
            f.write(json.dumps(entry, ensure_ascii=False) + '\n')


def move_to_deleted(session_id, metadata):
    """Move session para _deleted/ quando TUI remove."""
    DELETED_DIR.mkdir(parents=True, exist_ok=True)
    src = SESSIONS_DIR / session_id
    dst = DELETED_DIR / session_id
    if src.exists():
        try:
            src.rename(dst)
        except OSError:
            import shutil
            shutil.rmtree(dst, ignore_errors=True)
            shutil.move(str(src), str(dst))
    metadata['status'] = 'deleted'
    metadata['deleted_at'] = datetime.utcnow().isoformat() + 'Z'
    metadata.pop('missed_scans', None)
    with open(dst / 'metadata.json', 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)


def sync_once(project_id=None):
    """Executa um ciclo de sincronizacao. Retorna stats."""
    stats = {
        "scanned": 0,
        "added": 0,
        "updated": 0,
        "marked_for_deletion": 0,
        "moved_to_deleted": 0,
        "errors": []
    }

    try:
        conn, db_path = get_tui_connection()
    except Exception as e:
        stats["errors"].append(f"Cannot open TUI DB: {e}")
        return stats

    try:
        registry = load_registry()
        last_sync_ms = registry.get('last_sync_ms', 0)
        tui_sessions = get_tui_sessions(conn, since_ms=last_sync_ms,
                                        project_id=project_id)
        tui_ids = {row[0] for row in tui_sessions}
        stats["scanned"] = len(tui_sessions)

        most_recent_updated = last_sync_ms
        most_recent_id = None

        for row in tui_sessions:
            (sid, proj_id, title, agent, model_json, t_created, t_updated,
             t_archived, parent_id, directory) = row
            try:
                model = json.loads(model_json) if model_json else {}
            except json.JSONDecodeError:
                model = {"raw": model_json}

            entry = registry['chats'].get(sid, {})
            is_new = not entry

            entry.update({
                "tui_session_id": sid,
                "brain_uuid": sid,
                "project_id": proj_id,
                "directory": directory,
                "title": title,
                "agent": agent,
                "model": model,
                "parent_id": parent_id,
                "time_created": t_created,
                "time_updated": t_updated,
                "time_archived": t_archived,
                "status": "active",
                "synced_at": datetime.utcnow().isoformat() + 'Z'
            })

            if not is_new:
                detect_title_change(entry, title)
                entry.pop('missed_scans', None)

            try:
                msg_count = get_message_count(conn, sid)
            except Exception:
                msg_count = 0
            entry['message_count'] = msg_count

            try:
                write_session_metadata(sid, entry)
                messages = get_messages(conn, sid)
                write_session_messages(sid, messages)
            except Exception as e:
                stats["errors"].append(f"{sid[:20]}: {e}")

            if t_updated > most_recent_updated:
                most_recent_updated = t_updated
                most_recent_id = sid

            if is_new:
                stats["added"] += 1
            else:
                stats["updated"] += 1

            registry['chats'][sid] = entry

        if most_recent_id:
            current_file = BRAIN_DIR / 'current_session.txt'
            current_file.parent.mkdir(parents=True, exist_ok=True)
            current_file.write_text(most_recent_id, encoding='utf-8')

        for sid in list(registry['chats'].keys()):
            entry = registry['chats'][sid]
            if entry.get('status') == 'deleted':
                continue
            if sid not in tui_ids:
                entry.setdefault('missed_scans', 0)
                entry['missed_scans'] += 1
                if entry['missed_scans'] >= DELETION_GRACE_SCANS:
                    try:
                        move_to_deleted(sid, entry)
                        stats["moved_to_deleted"] += 1
                    except Exception as e:
                        stats["errors"].append(f"move {sid[:20]}: {e}")
                else:
                    stats["marked_for_deletion"] += 1

        registry['last_sync'] = datetime.utcnow().isoformat() + 'Z'
        registry['last_sync_ms'] = most_recent_updated
        registry['platform_resolved_at'] = datetime.utcnow().isoformat() + 'Z'
        registry['stats'] = {
            "total_sessions": len(registry['chats']),
            "active": sum(1 for e in registry['chats'].values()
                          if e.get('status') == 'active'),
            "deleted": sum(1 for e in registry['chats'].values()
                           if e.get('status') == 'deleted')
        }
        save_registry(registry)
    finally:
        conn.close()

    return stats


def run_loop(interval):
    """Loop continuo de sync."""
    print(f"[tui-sync] Starting loop (interval: {interval}s)")
    while True:
        try:
            stats = sync_once()
            msg = (f"[tui-sync] {datetime.now().strftime('%H:%M:%S')} "
                   f"scanned={stats['scanned']} +{stats['added']} "
                   f"~{stats['updated']} -{stats['moved_to_deleted']}")
            if stats['errors']:
                msg += f" errors={len(stats['errors'])}"
                for err in stats['errors'][:3]:
                    print(f"  ! {err}", file=sys.stderr)
            print(msg)
        except KeyboardInterrupt:
            print("\n[tui-sync] Stopped by user")
            break
        except Exception as e:
            print(f"[tui-sync] ERROR: {e}", file=sys.stderr)
            traceback.print_exc()
        time.sleep(interval)


def main():
    parser = argparse.ArgumentParser(description="TUI Sync - espelha TUI SQLite para .brain/")
    parser.add_argument("--loop", type=int, default=0,
                        help="Se > 0, roda em loop com este intervalo (segundos)")
    parser.add_argument("--project", type=str, default=None,
                        help="Filtrar por project_id do TUI")
    args = parser.parse_args()

    if args.loop > 0:
        run_loop(args.loop)
    else:
        result = sync_once(project_id=args.project)
        print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
