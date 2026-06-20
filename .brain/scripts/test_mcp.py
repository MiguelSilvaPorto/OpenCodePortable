#!/usr/bin/env python3
"""
test_mcp.py - Diagnostico rapido dos servidores MCP
Execute para verificar se as dependencias estao instaladas.
"""

import sys
print(f"Python: {sys.version}")
print()

# Testar cada dependencia
deps = [
    ("mcp", "from mcp.server.fastmcp import FastMCP"),
    ("openpyxl", "import openpyxl"),
    ("python-docx", "import docx"),
    ("python-pptx", "import pptx"),
    ("psutil", "import psutil"),
    ("pdf2image", "import pdf2image"),
    ("lxml", "import lxml"),
    ("pywin32", "import win32com.client"),
    ("formulas", "import formulas"),
    ("msal", "import msal"),
]

ok = 0
fail = 0
for name, import_stmt in deps:
    try:
        exec(import_stmt)
        print(f"  OK  {name}")
        ok += 1
    except ImportError as e:
        print(f"  FALHA {name}: {e}")
        fail += 1
    except Exception as e:
        print(f"  FALHA {name}: {type(e).__name__}: {e}")
        fail += 1

print()
print(f"Resultado: {ok} OK, {fail} FALHA")

if fail > 0:
    print(f"\nExecute: python -m pip install {' '.join([name for name, _ in deps if name not in ['pywin32', 'formulas', 'msal']])}")
    print("Ou instale todos: python -m pip install openpyxl python-docx python-pptx mcp psutil pdf2image lxml")
