# 3. Ferramentas MCP

Esta secao documenta os servidores MCP (Model Context Protocol) do OpenCode Portable.

## Arquivos

| Arquivo | Descricao |
|---------|-----------|
| [office-mcp.md](office-mcp.md) | Servidor MCP para documentos Office (51 tools) |
| [project-mcp.md](project-mcp.md) | Servidor MCP para criacao de projetos |
| [brain-mcp.md](brain-mcp.md) | Servidor MCP para memoria portatil com busca vetorial |
| [configuracao.md](configuracao.md) | Como configurar servidores MCP |

## O que e MCP?

MCP (Model Context Protocol) e um protocolo que permite ao OpenCode interagir com ferramentas externas. Os servidores MCP rodam como subprocessos e expoe ferramentas que o LLM pode usar.

## Servidores Disponiveis

| Servidor | Tipo | Descricao |
|----------|------|-----------|
| `office-mcp` | Local (Python) | Word, Excel, PowerPoint, PDF, OCR |
| `project-mcp` | Local (Python) | Criacao de projetos isolados |
| `brain-mcp` | Local (Python) | Memoria portatil com busca vetorial |

## Como Funciona

```
┌─────────────────────────────────────────────────┐
│  OpenCode (opencode.exe)                        │
│      │                                          │
│      ├──▶ office-mcp.py (subprocesso)           │
│      │    └── 51 tools: Word, Excel, PPT, PDF   │
│      │                                          │
│      ├──▶ project_generator.py (subprocesso)    │
│      │    └── Ferramenta: create_isolated_project│
│      │                                          │
│      └──▶ brain_mcp.py (subprocesso)            │
│           └── 6 tools: memoria vetorial         │
└─────────────────────────────────────────────────┘
```

## Configuracao

Os servidores MCP sao configurados em `config/opencode.jsonc`:

```jsonc
"mcp": {
    "office-mcp": {
        "type": "local",
        "command": ["python", "scripts/office_mcp.py"],
        "enabled": true
    }
}
```

## Dependencias Python

| Pacote | Funcao |
|--------|--------|
| `mcp` | SDK MCP Python |
| `openpyxl` | Manipulacao Excel |
| `python-docx` | Manipulacao Word |
| `python-pptx` | Manipulacao PowerPoint |
| `pywin32` | Automacao COM (Windows) |
| `psutil` | Utilitarios de processo |
| `PyMuPDF` | Extracao de texto PDF |
| `easyocr` | Reconhecimento de caracteres |

## Portabilidade

Os caminhos MCP sao **automaticamente corrigidos** a cada execucao do `opencode.bat` ou `opencode.ps1`. Isso garante que funcione em qualquer localizacao.
