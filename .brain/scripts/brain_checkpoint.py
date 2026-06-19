#!/usr/bin/env python3
"""
brain_checkpoint.py - Auto-checkpoint engine para OpenCode Portable

Implementa:
- Threshold-based checkpointing (20%, 40%, 60%, 80% do contexto)
- Pressure-based pruning (soft trim, hard compact, strip)
- Boundary computation (não quebra tool_use/tool_result pairs)
- Context reconstruction (checkpoint + MEMORY.md + notes)
- SQLite FTS5 para memória persistente
"""

import os
import sys
import json
import math
import time
import sqlite3
import re
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, List, Tuple

# Configuração
BRAIN_DIR = os.path.join(os.getcwd(), ".brain")
TEMPLATES_DIR = os.path.join(BRAIN_DIR, "templates")
MEMORY_DIR = os.path.join(BRAIN_DIR, "memory")
SESSIONS_DIR = os.path.join(BRAIN_DIR, "sessions")
DB_PATH = os.path.join(BRAIN_DIR, "memory.db")
STATUS_FILE = os.path.join(BRAIN_DIR, "brain_status.json")

# Thresholds de tokens para checkpoints
CHECKPOINT_THRESHOLDS = {
    25000: [],  # < 25K: desabilitado
    200000: [0.20, 0.40, 0.60, 0.80],  # 25K-200K: 4 triggers
    500000: [0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90],  # 200K-500K: 9 triggers
}
DEFAULT_THRESHOLDS = [0.05 * i for i in range(1, 19)]  # > 500K: 18 triggers

# Budgets de seções (tokens)
CHECKPOINT_SECTION_BUDGETS = {
    "§1 Active intent": 500,
    "§2 Next concrete action": 1000,
    "§3 Directives (this session)": 800,
    "§4 Task tree": 1000,
    "§5 Current work": 2000,
    "§6 Files and code sections": 1500,
    "§7 Discovered knowledge (cross-task)": 2000,
    "§8 Errors and fixes": 1500,
    "§9 Live resources": 1000,
    "§10 Design decisions and discussion outcomes": 3000,
    "§11 Open notes": 800,
}

MEMORY_SECTION_BUDGETS = {
    "Project context": 1000,
    "Rules": 2000,
    "Architecture decisions": 3000,
    "Discovered durable knowledge": 4000,
}

# Rebuild context push caps
REBUILD_PUSH_CAPS = {
    "checkpoint": 11000,
    "memory": 10000,
    "global": 6000,
    "notes": 6000,
    "tasks_ledger": 2000,
    "memory_titles": 500,
    "actor_ledger": 500,
}

# Tools compactáveis
COMPACTABLE_TOOLS = {
    "read", "bash", "grep", "glob", "webfetch", "websearch",
    "edit", "write", "multiedit", "apply_patch", "codesearch"
}

# Constants
TAIL_MIN_TOKENS = 10000
TAIL_MAX_TOKENS = 20000
TAIL_MIN_TEXT_BLOCK_MESSAGES = 5
CHECKPOINT_RESERVED = 13000
COMPACTION_BUFFER = 20000
OUTPUT_CAP = 20000


class BrainCheckpoint:
    def __init__(self, session_id: str):
        self.session_id = session_id
        self.session_dir = os.path.join(SESSIONS_DIR, session_id)
        self.checkpoint_path = os.path.join(self.session_dir, "checkpoint.md")
        self.notes_path = os.path.join(self.session_dir, "notes.md")
        self.memory_path = os.path.join(MEMORY_DIR, "MEMORY.md")
        self.global_memory_path = os.path.join(MEMORY_DIR, "global", "MEMORY.md")
        
        # Garantir diretórios
        os.makedirs(self.session_dir, exist_ok=True)
        os.makedirs(MEMORY_DIR, exist_ok=True)
        os.makedirs(os.path.join(MEMORY_DIR, "global"), exist_ok=True)
        
        # Inicializar arquivos se não existirem
        self._init_files()
        
        # Estado
        self.last_checkpoint_tokens = 0
        self.crossed_thresholds = set()
        self.writer_failures = 0
        self.max_writer_failures = 3
    
    def _init_files(self):
        """Inicializa arquivos de checkpoint e memória com templates."""
        # checkpoint.md
        if not os.path.exists(self.checkpoint_path):
            template = os.path.join(TEMPLATES_DIR, "checkpoint.md")
            if os.path.exists(template):
                with open(template, "r", encoding="utf-8") as f:
                    content = f.read()
            else:
                content = self._default_checkpoint_template()
            with open(self.checkpoint_path, "w", encoding="utf-8") as f:
                f.write(content)
        
        # notes.md
        if not os.path.exists(self.notes_path):
            template = os.path.join(TEMPLATES_DIR, "notes.md")
            if os.path.exists(template):
                with open(template, "r", encoding="utf-8") as f:
                    content = f.read()
            else:
                content = "# Session notes\n\n(none yet)\n"
            with open(self.notes_path, "w", encoding="utf-8") as f:
                f.write(content)
        
        # MEMORY.md
        if not os.path.exists(self.memory_path):
            template = os.path.join(TEMPLATES_DIR, "MEMORY.md")
            if os.path.exists(template):
                with open(template, "r", encoding="utf-8") as f:
                    content = f.read()
            else:
                content = self._default_memory_template()
            with open(self.memory_path, "w", encoding="utf-8") as f:
                f.write(content)
        
        # global MEMORY.md
        if not os.path.exists(self.global_memory_path):
            template = os.path.join(TEMPLATES_DIR, "MEMORY.md")
            if os.path.exists(template):
                with open(template, "r", encoding="utf-8") as f:
                    content = f.read()
            else:
                content = self._default_memory_template()
            with open(self.global_memory_path, "w", encoding="utf-8") as f:
                f.write(content)
    
    def _default_checkpoint_template(self) -> str:
        return """# Session checkpoint

## §1 Active intent
(none yet)

## §2 Next concrete action
(none yet)

## §3 Directives (this session)
(none)

## §4 Task tree
(none yet)

## §5 Current work
(none yet)

## §6 Files and code sections
(none yet)

## §7 Discovered knowledge (cross-task)
(none yet)

## §8 Errors and fixes
(none)

## §9 Live resources
(none yet)

## §10 Design decisions and discussion outcomes
(none yet)

## §11 Open notes
(none yet)
"""
    
    def _default_memory_template(self) -> str:
        return """# Project memory

## Project context
(none yet)

## Rules
(none yet)

## Architecture decisions
(none yet)

## Discovered durable knowledge
(none yet)
"""
    
    def get_thresholds(self, context_window: int) -> List[float]:
        """Retorna thresholds baseado no tamanho do contexto."""
        if context_window < 25000:
            return []
        
        for threshold, percentages in sorted(CHECKPOINT_THRESHOLDS.items()):
            if context_window <= threshold:
                return percentages
        
        return DEFAULT_THRESHOLDS
    
    def resolve_thresholds(self, context_window: int) -> List[int]:
        """Calcula thresholds absolutos em tokens."""
        percentages = self.get_thresholds(context_window)
        if not percentages:
            return []
        
        max_allowed = context_window - CHECKPOINT_RESERVED
        if max_allowed <= 0:
            return []
        
        thresholds = []
        capped = False
        
        for pct in percentages:
            value = int(context_window * pct)
            if value <= max_allowed:
                thresholds.append(value)
            elif not capped:
                thresholds.append(max_allowed)
                capped = True
            # else: drop (already clamped)
        
        # Sort e deduplicate
        return sorted(set(thresholds))
    
    def compute_pressure(self, token_count: int, context_window: int) -> int:
        """Calcula nível de pressão (0-3)."""
        usable = context_window - CHECKPOINT_RESERVED
        if usable <= 0:
            return 0
        
        ratio = token_count / usable
        
        if ratio < 0.50:
            return 0
        elif ratio < 0.70:
            return 1
        elif ratio < 0.85:
            return 2
        else:
            return 3
    
    def should_checkpoint(self, token_count: int, context_window: int) -> bool:
        """Verifica se deve disparar checkpoint."""
        thresholds = self.resolve_thresholds(context_window)
        if not thresholds:
            return False
        
        for threshold in thresholds:
            if token_count >= threshold and threshold not in self.crossed_thresholds:
                return True
        
        return False
    
    def save_checkpoint(self, token_count: int, context_window: int, conversation_summary: str = ""):
        """Salva checkpoint atual."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Ler checkpoint atual
        with open(self.checkpoint_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Atualizar §9 Live resources com timestamp
        content = re.sub(
            r'## §9 Live resources\n.*?\n',
            f'## §9 Live resources\n_Last checkpoint: {timestamp} | Tokens: {token_count}/{context_window}_\n',
            content,
            flags=re.DOTALL
        )
        
        # Adicionar resumo da conversa se fornecido
        if conversation_summary:
            content = re.sub(
                r'## §11 Open notes\n.*?\n',
                f'## §11 Open notes\n{conversation_summary}\n',
                content,
                flags=re.DOTALL
            )
        
        # Escrever
        with open(self.checkpoint_path, "w", encoding="utf-8") as f:
            f.write(content)
        
        # Atualizar estado
        self.last_checkpoint_tokens = token_count
        self.crossed_thresholds.add(token_count)
        
        # Log no SQLite
        self._log_checkpoint(token_count, context_window)
        
        return {
            "status": "ok",
            "checkpoint_path": self.checkpoint_path,
            "token_count": token_count,
            "context_window": context_window,
            "timestamp": timestamp
        }
    
    def _log_checkpoint(self, token_count: int, context_window: int):
        """Loga checkpoint no SQLite."""
        conn = sqlite3.connect(DB_PATH)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS checkpoint_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                threshold REAL NOT NULL,
                token_count INTEGER NOT NULL,
                context_window INTEGER NOT NULL,
                created_at TEXT DEFAULT (datetime('now'))
            )
        """)
        conn.execute(
            "INSERT INTO checkpoint_log (session_id, threshold, token_count, context_window) VALUES (?, ?, ?, ?)",
            (self.session_id, token_count / context_window if context_window > 0 else 0, token_count, context_window)
        )
        conn.commit()
        conn.close()
    
    def prune_messages(self, messages: List[Dict], pressure: int) -> List[Dict]:
        """Aplica pruning baseado na pressão."""
        if pressure == 0:
            return messages
        
        # Clone para não modificar original
        pruned = [msg.copy() for msg in messages]
        
        if pressure >= 1:
            # Soft trim: mantém primeiros e últimos 1536 chars de tool outputs grandes
            for msg in pruned[:-2]:  # skip last 2 turns
                if msg.get("role") == "tool" and len(msg.get("content", "")) > 4096:
                    content = msg["content"]
                    msg["content"] = content[:1536] + f"\n[... trimmed — kept first and last 1.5K of {len(content)} chars ...]\n" + content[-1536:]
        
        if pressure >= 2:
            # Hard compact: limpa resultados de tools compactáveis
            for msg in pruned[:-2]:
                if msg.get("role") == "tool" and msg.get("name") in COMPACTABLE_TOOLS:
                    msg["content"] = "[Old tool result content cleared]"
                    msg["compacted"] = True
        
        if pressure >= 3:
            # Strip: remove media e reasoning de mensagens antigas
            for msg in pruned[:-2]:
                if msg.get("role") == "assistant":
                    # Remove reasoning/thinking
                    if "reasoning" in msg:
                        msg["reasoning"] = ""
                elif msg.get("role") == "user":
                    # Remove media attachments
                    if "attachments" in msg:
                        msg["attachments"] = []
        
        return pruned
    
    def compute_boundary(self, messages: List[Dict]) -> int:
        """Calcula boundary para rebuild (onde cortar mensagens antigas)."""
        if not messages:
            return 0
        
        # Encontrar última mensagem assistant finalizada
        last_asst_idx = -1
        for i in range(len(messages) - 1, -1, -1):
            if messages[i].get("role") == "assistant" and messages[i].get("finish"):
                last_asst_idx = i
                break
        
        if last_asst_idx <= 0:
            return 0
        
        # Estimar tokens por mensagem (simplificado: ~4 chars por token)
        def estimate_tokens(msg):
            content = msg.get("content", "")
            if isinstance(content, list):
                content = " ".join(str(c) for c in content)
            return len(str(content)) // 4
        
        # Calcular tail
        start_idx = last_asst_idx - 1
        tail_tokens = sum(estimate_tokens(messages[i]) for i in range(start_idx, len(messages)))
        text_blocks = sum(1 for i in range(start_idx, len(messages)) if messages[i].get("content"))
        
        # Se tail já é grande o suficiente, manter
        if tail_tokens >= TAIL_MAX_TOKENS:
            return start_idx
        
        # Caminhar para trás até ter tokens/textos suficientes
        while start_idx > 0 and tail_tokens < TAIL_MAX_TOKENS:
            if tail_tokens >= TAIL_MIN_TOKENS and text_blocks >= TAIL_MIN_TEXT_BLOCK_MESSAGES:
                break
            start_idx -= 1
            tail_tokens += estimate_tokens(messages[start_idx])
            if messages[start_idx].get("content"):
                text_blocks += 1
        
        return start_idx
    
    def adjust_boundary_for_pairs(self, messages: List[Dict], boundary: int) -> int:
        """Ajusta boundary para não quebrar tool_use/tool_result pairs."""
        if boundary <= 0 or boundary >= len(messages):
            return boundary
        
        # Coletar tool_result IDs no tail
        tail_tool_results = set()
        tail_tool_uses = set()
        
        for i in range(boundary, len(messages)):
            msg = messages[i]
            if msg.get("role") == "tool":
                tail_tool_results.add(msg.get("tool_call_id", ""))
            elif msg.get("role") == "assistant":
                # Extrair tool_use IDs
                content = msg.get("content", "")
                if isinstance(content, list):
                    for part in content:
                        if isinstance(part, dict) and part.get("type") == "tool_use":
                            tail_tool_uses.add(part.get("id", ""))
        
        # Encontrar tool_results órfãos (sem tool_use correspondente no tail)
        orphans = tail_tool_results - tail_tool_uses
        
        if not orphans:
            return boundary
        
        # Caminhar para trás para encontrar tool_uses correspondentes
        for i in range(boundary - 1, -1, -1):
            if messages[i].get("role") != "assistant":
                continue
            
            content = messages[i].get("content", "")
            if isinstance(content, list):
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "tool_use":
                        use_id = part.get("id", "")
                        if use_id in orphans:
                            boundary = i
                            orphans.discard(use_id)
            
            if not orphans:
                break
        
        return boundary
    
    def rebuild_context(self, messages: List[Dict], boundary: int) -> str:
        """Constrói contexto de rebuild após overflow."""
        sections = []
        
        # Header
        sections.append("The following blocks are auto-loaded from your session memory. They are already in your context — do not Read them as whole files. Use Grep for specific facts instead.")
        sections.append("")
        
        # Tasks ledger (simplificado)
        sections.append("## Tasks ledger")
        sections.append("(none yet)")
        sections.append("")
        
        # Session checkpoint
        sections.append("## Session checkpoint")
        checkpoint_content = self._read_budgeted(self.checkpoint_path, REBUILD_PUSH_CAPS["checkpoint"])
        sections.append(checkpoint_content)
        sections.append("")
        
        # Active actors
        sections.append("## Active actors")
        sections.append("(none)")
        sections.append("")
        
        # Project memory
        sections.append("## Project memory")
        memory_content = self._read_budgeted(self.memory_path, REBUILD_PUSH_CAPS["memory"])
        sections.append(memory_content)
        sections.append("")
        
        # Global memory
        sections.append("## Global memory")
        global_content = self._read_budgeted(self.global_memory_path, REBUILD_PUSH_CAPS["global"])
        sections.append(global_content)
        sections.append("")
        
        # Session notes
        sections.append("## Session notes")
        notes_content = self._read_budgeted(self.notes_path, REBUILD_PUSH_CAPS["notes"])
        sections.append(notes_content)
        sections.append("")
        
        # Footer
        sections.append("This session is being continued from a previous conversation that hit a checkpoint. The session checkpoint and project memory above cover the earlier portion of the conversation.")
        sections.append("")
        sections.append("Recent messages are preserved verbatim below — the assistant turn (and any tool results) you'll see is real history, not pseudo-content. Continue your task by responding to the most recent state.")
        sections.append("")
        sections.append("Resume directly. Do not acknowledge this memory dump, do not recap, do not preface with \"I'll continue\" or similar. Pick up the last task as if the break never happened.")
        
        return "\n".join(sections)
    
    def _read_budgeted(self, file_path: str, budget_tokens: int) -> str:
        """Lê arquivo com budget de tokens."""
        if not os.path.exists(file_path):
            return "(file not found)"
        
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Estimativa: ~4 chars por token
        estimated_tokens = len(content) // 4
        
        if estimated_tokens <= budget_tokens:
            return content
        
        # Truncar proporcionalmente
        ratio = budget_tokens / estimated_tokens
        truncated = content[:int(len(content) * ratio * 0.95)]
        
        # Cortar no último newline
        last_newline = truncated.rfind("\n")
        if last_newline > 0:
            truncated = truncated[:last_newline]
        
        hint = f"\n\n️ Truncated at ~{budget_tokens} tokens. {file_path} is ~{estimated_tokens} tokens total."
        return truncated + hint
    
    def get_status(self) -> Dict:
        """Retorna status atual do checkpoint."""
        return {
            "session_id": self.session_id,
            "last_checkpoint_tokens": self.last_checkpoint_tokens,
            "crossed_thresholds": sorted(list(self.crossed_thresholds)),
            "writer_failures": self.writer_failures,
            "checkpoint_path": self.checkpoint_path,
            "memory_path": self.memory_path,
            "notes_path": self.notes_path,
        }


def main():
    """CLI para testar o engine de checkpoint."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Brain Checkpoint Engine")
    subparsers = parser.add_subparsers(dest="command")
    
    # Status
    status_parser = subparsers.add_parser("status", help="Mostrar status do checkpoint")
    status_parser.add_argument("--session", required=True, help="UUID da sessão")
    
    # Thresholds
    thresholds_parser = subparsers.add_parser("thresholds", help="Calcular thresholds")
    thresholds_parser.add_argument("--context", type=int, default=128000, help="Tamanho do contexto")
    
    # Pressure
    pressure_parser = subparsers.add_parser("pressure", help="Calcular pressão")
    pressure_parser.add_argument("--tokens", type=int, required=True, help="Tokens atuais")
    pressure_parser.add_argument("--context", type=int, default=128000, help="Tamanho do contexto")
    
    # Save
    save_parser = subparsers.add_parser("save", help="Salvar checkpoint")
    save_parser.add_argument("--session", required=True, help="UUID da sessão")
    save_parser.add_argument("--tokens", type=int, required=True, help="Tokens atuais")
    save_parser.add_argument("--context", type=int, default=128000, help="Tamanho do contexto")
    save_parser.add_argument("--summary", default="", help="Resumo da conversa")
    
    args = parser.parse_args()
    
    if args.command == "status":
        engine = BrainCheckpoint(args.session)
        print(json.dumps(engine.get_status(), indent=2, ensure_ascii=False))
    
    elif args.command == "thresholds":
        engine = BrainCheckpoint("test")
        thresholds = engine.resolve_thresholds(args.context)
        print(f"Context window: {args.context}")
        print(f"Thresholds: {thresholds}")
    
    elif args.command == "pressure":
        engine = BrainCheckpoint("test")
        pressure = engine.compute_pressure(args.tokens, args.context)
        print(f"Tokens: {args.tokens}/{args.context}")
        print(f"Pressure level: {pressure}")
    
    elif args.command == "save":
        engine = BrainCheckpoint(args.session)
        result = engine.save_checkpoint(args.tokens, args.context, args.summary)
        print(json.dumps(result, indent=2, ensure_ascii=False))
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
