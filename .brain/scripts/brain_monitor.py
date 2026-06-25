#!/usr/bin/env python3
"""
brain_monitor.py - Monitor de contexto para auto-checkpoint

Roda em background e monitora o tamanho do contexto.
Quando detecta overflow, dispara checkpoint automaticamente.

Uso:
    python brain_monitor.py --session {UUID} --context {window_size}
"""

import os
import sys
import json
import time
import signal
import argparse
from pathlib import Path
from datetime import datetime

# Adicionar scripts ao path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from brain_checkpoint import BrainCheckpoint
from tui_sync import sync_once

# Configuração
BRAIN_DIR = os.path.join(os.getcwd(), ".brain")
STATUS_FILE = os.path.join(BRAIN_DIR, "brain_status.json")
CHECK_INTERVAL = 30  # segundos
TUI_SYNC_INTERVAL = 60  # segundos - sync do TUI SQLite
MAX_FAILURES = 3


class BrainMonitor:
    def __init__(self, session_id: str, context_window: int):
        self.session_id = session_id
        self.context_window = context_window
        self.checkpoint = BrainCheckpoint(session_id)
        self.running = True
        self.checkpoints_saved = 0
        self.last_check_time = None
        self.last_tui_sync = 0.0
        self.tui_sync_stats = {"scanned": 0, "added": 0, "updated": 0}

        # Registrar PID
        self.pid = os.getpid()
        self._write_pid()

        # Setup signal handlers
        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)
    
    def _write_pid(self):
        """Escreve PID para controle."""
        pid_file = os.path.join(BRAIN_DIR, "monitor.pid")
        with open(pid_file, "w") as f:
            f.write(str(self.pid))
    
    def _handle_signal(self, signum, frame):
        """Handle graceful shutdown."""
        self.running = False
    
    def read_status(self) -> dict:
        """Lê status atual do contexto."""
        if not os.path.exists(STATUS_FILE):
            return {
                "token_count": 0,
                "message_count": 0,
                "last_update": None
            }
        
        try:
            with open(STATUS_FILE, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return {
                "token_count": 0,
                "message_count": 0,
                "last_update": None
            }
    
    def check_and_checkpoint(self):
        """Verifica se precisa de checkpoint e executa."""
        status = self.read_status()
        token_count = status.get("token_count", 0)

        if token_count == 0:
            return False

        # Verificar se deve checkpoint
        if not self.checkpoint.should_checkpoint(token_count, self.context_window):
            return False

        # Calcular pressão
        pressure = self.checkpoint.compute_pressure(token_count, self.context_window)

        # Salvar checkpoint
        try:
            result = self.checkpoint.save_checkpoint(
                token_count=token_count,
                context_window=self.context_window,
                conversation_summary=f"Auto-checkpoint at {pressure} pressure level"
            )

            self.checkpoints_saved += 1
            self.last_check_time = datetime.now().isoformat()

            # Log
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Checkpoint saved: {token_count}/{self.context_window} tokens (pressure: {pressure})")

            return True

        except Exception as e:
            self.checkpoint.writer_failures += 1
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Checkpoint failed: {e}", file=sys.stderr)

            if self.checkpoint.writer_failures >= MAX_FAILURES:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Max failures reached, stopping monitor", file=sys.stderr)
                self.running = False

            return False

    def check_and_sync_tui(self):
        """Sincroniza TUI SQLite para .brain/ a cada TUI_SYNC_INTERVAL segundos."""
        now = time.time()
        if now - self.last_tui_sync < TUI_SYNC_INTERVAL:
            return False
        try:
            stats = sync_once()
            self.tui_sync_stats = stats
            self.last_tui_sync = now
            if stats['scanned'] > 0 or stats['added'] > 0 or stats['updated'] > 0:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] [tui-sync] "
                      f"scanned={stats['scanned']} +{stats['added']} "
                      f"~{stats['updated']} moved={stats['moved_to_deleted']}")
            if stats['errors']:
                for err in stats['errors'][:3]:
                    print(f"[tui-sync] ERR: {err}", file=sys.stderr)
            return True
        except Exception as e:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [tui-sync] failed: {e}",
                  file=sys.stderr)
            self.last_tui_sync = now
            return False
    
    def run(self):
        """Loop principal do monitor."""
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Monitor started (PID: {self.pid})")
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Session: {self.session_id}")
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Context window: {self.context_window}")
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Check interval: {CHECK_INTERVAL}s")
        print(f"[{datetime.now().strftime('%H:%M:%S')}] TUI sync interval: {TUI_SYNC_INTERVAL}s")

        while self.running:
            try:
                self.check_and_checkpoint()
                self.check_and_sync_tui()
            except Exception as e:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Error: {e}", file=sys.stderr)

            time.sleep(CHECK_INTERVAL)

        # Cleanup
        self._cleanup()
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Monitor stopped (saved {self.checkpoints_saved} checkpoints)")
    
    def _cleanup(self):
        """Cleanup ao parar."""
        pid_file = os.path.join(BRAIN_DIR, "monitor.pid")
        if os.path.exists(pid_file):
            try:
                os.remove(pid_file)
            except:
                pass


def main():
    parser = argparse.ArgumentParser(description="Brain Monitor - Auto-checkpoint daemon")
    parser.add_argument("--session", required=True, help="UUID da sessão")
    parser.add_argument("--context", type=int, default=128000, help="Tamanho do contexto (tokens)")
    parser.add_argument("--interval", type=int, default=30, help="Intervalo de verificação (segundos)")
    
    args = parser.parse_args()
    
    # Override interval se especificado
    global CHECK_INTERVAL
    CHECK_INTERVAL = args.interval
    
    # Criar e rodar monitor
    monitor = BrainMonitor(args.session, args.context)
    monitor.run()


if __name__ == "__main__":
    main()
