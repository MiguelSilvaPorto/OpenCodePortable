#!/usr/bin/env python3
"""
get_tui_db_path.py - Resolvedor portatil do path do SQLite do opencode TUI.

Suporta Windows, Mac e Linux com fallback para env var.

Uso:
    from get_tui_db_path import get_tui_db_path
    db_path = get_tui_db_path()
"""

import os
import sys
from pathlib import Path


def get_tui_db_path() -> Path:
    """
    Resolve o path do SQLite do TUI com 3 niveis de prioridade:
    1. Env var OPENCODE_TUI_DB_PATH (maxima prioridade, override explicito)
    2. Path detectado por plataforma (win32, darwin, linux)
    3. Fallback: ~/.local/share/opencode/opencode.db

    Returns:
        Path: caminho absoluto para o arquivo .db do TUI.
    """
    env_path = os.environ.get('OPENCODE_TUI_DB_PATH')
    if env_path:
        return Path(env_path)

    home = Path(os.path.expanduser('~'))

    candidates = {
        'win32': home / '.local' / 'share' / 'opencode' / 'opencode.db',
        'darwin': home / 'Library' / 'Application Support' / 'opencode' / 'opencode.db',
        'linux': home / '.local' / 'share' / 'opencode' / 'opencode.db',
    }

    for plat in [sys.platform, 'linux']:
        path = candidates.get(plat)
        if path and path.exists():
            return path

    return candidates['linux']


def get_portable_path(absolute_path: Path) -> str:
    """
    Converte path absoluto para representacao portatil (~) para armazenamento.

    Args:
        absolute_path: Path absoluto (ex: C:/Users/foo/.local/share/...)

    Returns:
        str: path portatil (ex: ~/.local/share/...)
    """
    absolute_str = str(absolute_path)
    home = os.path.expanduser('~')
    if absolute_str.startswith(home):
        return absolute_str.replace(home, '~', 1)
    return absolute_str


if __name__ == '__main__':
    db = get_tui_db_path()
    exists = db.exists()
    print(f"Path: {db}")
    print(f"Exists: {exists}")
    print(f"Portable: {get_portable_path(db)}")
    print(f"Platform: {sys.platform}")
