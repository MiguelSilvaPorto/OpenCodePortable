#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
advanced_logger.py - Sistema de Logs e Diagnósticos Avançados para OpenCode Portable
"""

import os
import sys
import re
import json
import time
import zipfile
import traceback
from pathlib import Path
from datetime import datetime

# Configurações de caminhos portáteis
OPENCODE_HOME = Path(os.getcwd())
LOG_DIR = OPENCODE_HOME / "data" / "logs"
LAUNCHER_LOG = LOG_DIR / "launcher.jsonl"
LOCK_FILE = LOG_DIR / "advanced_logger.lock"

# Logs unificados de saída
FULL_LOG_PATH = LOG_DIR / "advanced_full.log"
ERRORS_LOG_PATH = LOG_DIR / "advanced_errors.log"

# Relatórios em Markdown
CRASH_REPORT_PATH = LOG_DIR / "crash-report.md"
ERRORS_HISTORY_PATH = LOG_DIR / "errors-history.md"

# Arquivo ZIP de transferência
ZIP_PATH = LOG_DIR / "opencode-diagnostics.zip"


# ==========================================
# UTILITÁRIOS DE AMBIENTE E PROCESSO
# ==========================================

def get_native_log_path() -> Path:
    """Resolve o caminho do log nativo de acordo com o SO."""
    home = Path.home()
    if sys.platform == "win32":
        return home / ".local" / "share" / "opencode" / "log" / "opencode.log"
    elif sys.platform == "darwin":
        return home / "Library" / "Logs" / "opencode" / "opencode.log"
    else:
        return home / ".local" / "share" / "opencode" / "log" / "opencode.log"


def is_pid_running(pid: int) -> bool:
    """Verifica se um PID específico está rodando."""
    try:
        import psutil
        return psutil.pid_exists(pid)
    except ImportError:
        try:
            import subprocess
            if sys.platform == "win32":
                output = subprocess.check_output(
                    f'tasklist /FI "PID eq {pid}" /FO CSV',
                    shell=True,
                    text=True,
                    stderr=subprocess.DEVNULL
                )
                return str(pid) in output
            else:
                os.kill(pid, 0)
                return True
        except Exception:
            return True  # Fallback conservador


def is_opencode_running(home_dir: str) -> bool:
    """Verifica se processos do OpenCode portáteis estão em execução."""
    # 1. Tentar via psutil
    try:
        import psutil
        for proc in psutil.process_iter(['name', 'exe']):
            try:
                name = proc.info['name']
                exe = proc.info['exe']
                if name and 'opencode' in name.lower():
                    if exe and home_dir.lower() in exe.lower():
                        return True
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
    except ImportError:
        # 2. Fallback via tasklist no Windows
        try:
            import subprocess
            if sys.platform == "win32":
                output = subprocess.check_output(
                    'tasklist /FI "IMAGENAME eq opencode.exe" /FO CSV',
                    shell=True,
                    text=True,
                    stderr=subprocess.DEVNULL
                )
                return "opencode.exe" in output.lower()
        except Exception:
            pass
    return False


def acquire_lock() -> bool:
    """Tenta adquirir lock de instância única para o monitor."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    if LOCK_FILE.exists():
        try:
            with open(LOCK_FILE, 'r', encoding='utf-8') as f:
                old_pid = int(f.read().strip())
            if is_pid_running(old_pid):
                return False
        except Exception:
            pass
    try:
        with open(LOCK_FILE, 'w', encoding='utf-8') as f:
            f.write(str(os.getpid()))
        return True
    except Exception:
        return False


def release_lock():
    """Libera o lock do monitor."""
    try:
        if LOCK_FILE.exists():
            LOCK_FILE.unlink()
    except Exception:
        pass


# ==========================================
# PARSERS DE LOGS
# ==========================================

# Regex para parsear o formato logfmt da aplicação nativa
LOGFMT_REGEX = re.compile(r'([a-zA-Z0-9_\-]+)=(?:\"([^\"]*)\"|([^\s]*))')

def parse_logfmt(line: str) -> dict:
    """Converte uma linha de logfmt em um dicionário."""
    parts = {}
    for match in LOGFMT_REGEX.finditer(line):
        key = match.group(1)
        val = match.group(2) if match.group(2) is not None else match.group(3)
        parts[key] = val
    return parts


def format_timestamp(ts_str: str) -> str:
    """Formata um timestamp ISO 8601 para AAAA-MM-DD HH:MM:SS.mmm."""
    if not ts_str:
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S.000")
    try:
        ts_str = ts_str.replace('Z', '').replace('T', ' ')
        if '.' in ts_str:
            base, frac = ts_str.split('.')
            # Limita milissegundos a 3 dígitos
            frac = frac.split('+')[0].split('-')[0][:3]
            return f"{base}.{frac}"
        return ts_str[:19] + ".000"
    except Exception:
        return ts_str


# ==========================================
# GERADORES DE RELATÓRIO E ZIP
# ==========================================

class DiagnosticsLogger:
    def __init__(self):
        self.errors_list = []
        self.launcher_offset = 0
        self.native_offset = 0
        self.last_crash = None

    def read_launcher_log(self):
        """Lê incrementalmente o log do launcher."""
        if not LAUNCHER_LOG.exists():
            return
        
        try:
            with open(LAUNCHER_LOG, 'r', encoding='utf-8', errors='ignore') as f:
                f.seek(self.launcher_offset)
                lines = f.readlines()
                self.launcher_offset = f.tell()

            for line in lines:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    ts = data.get("ts", "")
                    level = data.get("level", "INFO").upper()
                    stage = data.get("stage", "SYSTEM")
                    event = data.get("event", "")
                    context = data.get("context", {})

                    # Montar mensagem de log
                    ctx_str = ", ".join([f"{k}={v}" for k, v in context.items()])
                    msg = f"Event: {event} | Context: {{{ctx_str}}}"
                    
                    self.process_entry(ts, level, "LAUNCHER", stage, msg, context)
                except Exception as e:
                    # Se falhar no JSON, joga como texto cru
                    self.process_entry("", "ERROR", "LAUNCHER", "PARSING_FAIL", f"Raw: {line} | Error: {e}", {})
        except Exception as e:
            print(f"[advanced-logger] Erro ao ler launcher.jsonl: {e}", file=sys.stderr)

    def read_native_log(self):
        """Lê incrementalmente o log nativo."""
        native_path = get_native_log_path()
        if not native_path.exists():
            return

        try:
            with open(native_path, 'r', encoding='utf-8', errors='ignore') as f:
                f.seek(self.native_offset)
                lines = f.readlines()
                self.native_offset = f.tell()

            for line in lines:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = parse_logfmt(line)
                    ts = data.get("timestamp", data.get("ts", ""))
                    level = data.get("level", "INFO").upper()
                    message = data.get("message", "")
                    
                    # Filtra outros campos
                    extra = {k: v for k, v in data.items() if k not in ["timestamp", "ts", "level", "message"]}
                    extra_str = ", ".join([f"{k}={v}" for k, v in extra.items()])
                    
                    msg = message
                    if extra_str:
                        msg += f" | {extra_str}"

                    self.process_entry(ts, level, "NATIVE", "APP", msg, data)
                except Exception as e:
                    self.process_entry("", "ERROR", "NATIVE", "PARSING_FAIL", f"Raw: {line} | Error: {e}", {})
        except Exception as e:
            print(f"[advanced-logger] Erro ao ler opencode.log: {e}", file=sys.stderr)

    def process_entry(self, ts: str, level: str, source: str, component: str, msg: str, raw_data: dict):
        """Processa e armazena cada linha de log formatada."""
        formatted_ts = format_timestamp(ts)
        log_line = f"[{formatted_ts}] [{level}] [{source}] [{component}] {msg}\n"

        # 1. Escrever no log completo
        with open(FULL_LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(log_line)

        # 2. Verificar se é erro/aviso
        is_error = level in ["ERROR", "CRITICAL", "FATAL"]
        is_warn = level == "WARN"

        if is_error or is_warn:
            # Escrever no log de erros
            with open(ERRORS_LOG_PATH, 'a', encoding='utf-8') as f:
                f.write(log_line)

            # Guardar histórico estruturado
            error_entry = {
                "ts": formatted_ts,
                "level": level,
                "source": source,
                "component": component,
                "msg": msg,
                "raw": raw_data
            }
            self.errors_list.append(error_entry)

            # Se for erro crítico (não apenas aviso), atualizar último crash
            if is_error:
                self.last_crash = error_entry

    def write_crash_report(self):
        """Escreve o arquivo crash-report.md com a falha mais recente."""
        if not self.last_crash:
            return

        date_str = self.last_crash["ts"]
        comp = f"{self.last_crash['source']} - {self.last_crash['component']}"
        raw = self.last_crash["raw"]
        
        # Tentar isolar o erro real
        reason = raw.get("error", raw.get("msg", "Erro indefinido na aplicação"))
        details = ""
        for k, v in raw.items():
            if k not in ["ts", "timestamp", "level", "source", "component", "error"]:
                details += f"{k}: {v}\n"

        err_file = "Desconhecido"
        err_line = "N/A"
        
        # Extrair linha e arquivo por regex
        trace = raw.get("script_trace", "")
        if trace:
            details += f"\nTrace:\n{trace}\n"
            m_line = re.search(r'linha\s+(\d+)', trace, re.IGNORECASE)
            if m_line:
                err_line = m_line.group(1)
            m_file = re.search(r"file\s+'([^']+)'", trace, re.IGNORECASE)
            if m_file:
                err_file = os.path.basename(m_file.group(1))
        else:
            m_line = re.search(r'linha\s+(\d+)', reason, re.IGNORECASE)
            if m_line:
                err_line = m_line.group(1)
            m_file = re.search(r"file\s+'([^']+)'", reason, re.IGNORECASE)
            if m_file:
                err_file = os.path.basename(m_file.group(1))

        report_md = f"""# Relatório de Falha do OpenCode Portable

**Data e Hora:** {date_str}
**Componente Afetado:** {comp}
**Arquivo de Origem:** {err_file}
**Linha do Erro:** {err_line}

## O que aconteceu?
{reason}

## Detalhes Técnicos / Variáveis de Contexto
```text
{details.strip()}
```

---
*Este relatório foi gerado em tempo real pelo Monitor de Logs do OpenCode em Python.*
"""
        with open(CRASH_REPORT_PATH, 'w', encoding='utf-8') as f:
            f.write(report_md)

    def write_errors_history(self):
        """Gera o arquivo errors-history.md com todos os erros agregados."""
        if not self.errors_list:
            # Cria histórico vazio coerente
            history_md = """# Histórico de Erros e Alertas do OpenCode Portable

*Nenhum erro registrado nesta sessão.*
"""
            with open(ERRORS_HISTORY_PATH, 'w', encoding='utf-8') as f:
                f.write(history_md)
            return

        table_rows = []
        for err in reversed(self.errors_list):
            ts = err["ts"]
            src = err["source"]
            lvl = err["level"]
            comp = err["component"]
            msg = err["msg"].replace("\n", " ").replace("|", "\\|")
            
            # Formatar nível com badge
            if lvl in ["ERROR", "CRITICAL", "FATAL"]:
                lvl_str = f"🔴 `{lvl}`"
            else:
                lvl_str = f"🟡 `{lvl}`"

            table_rows.append(f"| {ts} | {src} | {lvl_str} | {comp} | {msg} |")

        table_content = "\n".join(table_rows)
        history_md = f"""# Histórico de Erros e Alertas do OpenCode Portable

Tabela cronológica reversa de todos os eventos de erro ou alertas críticos capturados.

| Data e Hora | Origem | Nível | Componente | Descrição do Erro / Contexto |
| :--- | :--- | :--- | :--- | :--- |
{table_content}

---
*Atualizado dinamicamente pelo Monitor de Logs.*
"""
        with open(ERRORS_HISTORY_PATH, 'w', encoding='utf-8') as f:
            f.write(history_md)

    def make_zip(self):
        """Compacta todos os arquivos de logs para transferência."""
        files_to_zip = [
            FULL_LOG_PATH,
            ERRORS_LOG_PATH,
            CRASH_REPORT_PATH,
            ERRORS_HISTORY_PATH,
            LAUNCHER_LOG
        ]

        try:
            with zipfile.ZipFile(ZIP_PATH, 'w', zipfile.ZIP_DEFLATED) as zipf:
                for file_path in files_to_zip:
                    if file_path.exists():
                        zipf.write(file_path, arcname=file_path.name)
        except Exception as e:
            print(f"[advanced-logger] Falha ao criar zip: {e}", file=sys.stderr)


# ==========================================
# CONTROLE DE EXECUÇÃO
# ==========================================

def clean_old_sessions():
    """Remove logs gerados de sessões anteriores para evitar duplicações."""
    for path in [FULL_LOG_PATH, ERRORS_LOG_PATH, CRASH_REPORT_PATH, ERRORS_HISTORY_PATH]:
        if path.exists():
            try:
                path.unlink()
            except Exception:
                pass


def run_single_generation():
    """Executa o parser de logs uma única vez (modo --generate)."""
    print("[advanced-logger] Iniciando compilação de logs única...")
    clean_old_sessions()
    
    logger = DiagnosticsLogger()
    logger.read_launcher_log()
    logger.read_native_log()
    
    logger.write_crash_report()
    logger.write_errors_history()
    logger.make_zip()
    print("[advanced-logger] Compilação finalizada com sucesso! ZIP criado.")


def run_monitor_loop():
    """Executa em segundo plano monitorando o ciclo de vida do OpenCode (modo --monitor)."""
    if not acquire_lock():
        print("[advanced-logger] Outra instância do monitor já está em execução. Encerrando.")
        sys.exit(0)

    print("[advanced-logger] Monitor iniciado em segundo plano.")
    clean_old_sessions()
    
    logger = DiagnosticsLogger()
    
    grace_period_max = 30
    no_process_timer = 0
    home_dir_str = str(OPENCODE_HOME)

    try:
        while True:
            # Ler logs dinamicamente
            logger.read_launcher_log()
            logger.read_native_log()
            
            # Atualizar os Markdowns e ZIP se detectou alguma novidade
            if logger.errors_list:
                logger.write_crash_report()
                logger.write_errors_history()
                logger.make_zip()

            # Monitorar ciclo de vida do processo opencode
            running = is_opencode_running(home_dir_str)
            if not running:
                no_process_timer += 2
                if no_process_timer >= grace_period_max:
                    print("[advanced-logger] OpenCode inativo por 30s. Finalizando monitor de forma limpa.")
                    break
            else:
                no_process_timer = 0

            time.sleep(2)
            
        # Uma última leitura final de fechamento antes de sair
        logger.read_launcher_log()
        logger.read_native_log()
        logger.write_crash_report()
        logger.write_errors_history()
        logger.make_zip()
        
    except KeyboardInterrupt:
        print("[advanced-logger] Interrompido pelo usuário.")
    except Exception as e:
        # Se crashar o monitor por algum bug, salvar a stack trace no log de erro
        tb = traceback.format_exc()
        with open(ERRORS_LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(f"\n[MONITOR CRASH] {datetime.now()} | {e}\nTrace:\n{tb}\n")
    finally:
        release_lock()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--generate":
        run_single_generation()
    else:
        run_monitor_loop()


if __name__ == "__main__":
    main()
