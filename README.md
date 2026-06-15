# Opencode Portable

Versão portátil do OpenCode com suporte a voz integrado.

## Início Rápido

```cmd
opencode.bat
```

**Na primeira execução**, o script automaticamente:
1. Verifica se `opencode.exe` existe e está íntegro (>10MB, executa `--version`)
2. Se faltar ou estiver corrompido → baixa a versão mais recente do GitHub
3. Sincroniza plugins npm com a versão do binário
4. Instala dependências via Scoop: `whisper-cpp`, `sox`, `python`, `pip deps`
5. Baixa modelo de transcrição (~148 MB)
6. Configura o plugin de voz

### Arquitetura

```
opencode.bat (wrapper 1 linha)
    └─► opencode.ps1 (orquestrador completo)
            ├─► Sistema de logs JSONL (AI-readable)
            ├─► Verificação inteligente do executável
            ├─► Cache de versão (24h) + GitHub API + fallback v1.17.7
            ├─► Download robusto com retry (3x, backoff exponencial)
            ├─► Sincronização automática de plugins npm
            ├─► Setup idempotente (só instala o que falta)
            ├─► Seletor de projetos interativo
            └─► Executa opencode.exe
```

### Uso com argumento (pula seletor)

```cmd
opencode.bat D:\MeuProjeto
```

## Como Usar o Microfone

```cmd
# 1. Iniciar Ollama (para normalização por IA)
ollama serve

# 2. Iniciar OpenCode
opencode.bat

# 3. No prompt do OpenCode:
#    Ctrl+R → Falar → Ctrl+R → Texto aparece
```

### O que acontece:

1. **Gravação**: Sox captura áudio do microfone
2. **Transcrição**: Whisper converte áudio em texto
3. **Normalização**: LLM corrige erros automaticamente
   - Remove "ééé", "tipo", "sabe"
   - Corrige "Jason"→"JSON", "bullion"→"boolean"
   - Formata código ditado
4. **Inserção**: Texto limpo vai para o prompt

### Atalhos

| Tecla | Ação |
|-------|------|
| `Ctrl+R` | Iniciar/parar gravação |
| `/stt-model` | Trocar modelo whisper |
| `/stt-mic` | Trocar microfone |

## Estrutura

```
OpencodePortable/
├── bin/                           # Executável opencode.exe
├── config/                        # Configurações
│   ├── opencode.jsonc             # Config principal (providers, plugins)
│   ├── package.json               # Dependências npm
│   └── node_modules/              # Pacotes npm instalados
├── data/
│   ├── logs/                      # Logs JSONL (AI-readable)
│   │   ├── launcher.jsonl         # Log principal (rotaciona 10MB)
│   │   └── launcher-latest.jsonl  # Última execução
│   ├── version.cache              # Cache da versão (24h TTL)
│   ├── .plugin-version            # Versão dos plugins npm instalados
│   ├── whisper-models/            # Modelos de transcrição
│   └── .voice-setup-done          # Marker de setup concluído
├── Projects/                      # TODOS os projetos ficam aqui
│   ├── MeuProjeto/
│   │   ├── .opencode/
│   │   │   └── workspace.json     # Modo (Local, Nuvem, Desativado)
│   │   └── multitask-worktrees/
├── opencode.bat                   # Wrapper → chama opencode.ps1
├── opencode.ps1                   # Orquestrador principal
├── scripts/                       # Scripts auxiliares
├── tests/                         # Testes
└── README.md
```

## Sistema de Logs

Logs em formato **JSONL** (JSON Lines) para consumo por IA:

```json
{"ts":"2026-06-12T10:30:00.123Z","level":"INFO","stage":"DOWNLOAD","event":"START","context":{"url":"...","attempt":1}}
{"ts":"2026-06-12T10:30:05.456Z","level":"SUCCESS","stage":"DOWNLOAD","event":"COMPLETED","context":{"bytes":155196296}}
```

**Stages**: `SYSTEM`, `VERSION`, `DOWNLOAD`, `EXTRACT`, `SETUP`, `PROJECT`, `LAUNCH`

**Levels**: `DEBUG`, `INFO`, `WARN`, `ERROR`, `SUCCESS`

**Logs ficam em**: `data/logs/launcher.jsonl`

## Seletor de Projetos

Ao executar `opencode.bat` sem argumentos:
- Lista projetos existentes em `Projects/`
- Opção `[0]` criar novo projeto (com `git init` + opcional repo GitHub privado)
- Opção `[Q]` sair

## Scripts

| Script | Descrição |
|--------|-----------|
| `opencode.bat` | Wrapper que chama `opencode.ps1` |
| `opencode.ps1` | Orquestrador completo |
| `scripts\install.bat` | Instalação manual |
| `scripts\cleanup.bat` | Limpa cache e logs |
| `scripts\export-import.bat` | Exporta/importa config |
| `scripts\package.bat` | Empacota em ZIP |

## Configuração

Edite `config/opencode.jsonc`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    ["@renjfk/opencode-voice", {
      "endpoint": "http://localhost:11434/v1",
      "model": "llama3.2"
    }]
  ]
}
```

### Configuração Groq

Para usar Groq como provider de voz, defina a variável de ambiente:

```cmd
set GROQ_API_KEY=sua-chave-aqui
```

O plugin usará automaticamente a chave via `apiKeyEnv`.

### Alternativas de LLM

| Provider | Endpoint | Autenticação |
|----------|----------|--------------|
| **Ollama** | `http://localhost:11434/v1` | Nenhuma |
| **OpenAI** | `https://api.openai.com/v1` | `OPENAI_API_KEY` |
| **Anthropic** | `https://api.anthropic.com/v1` | `ANTHROPIC_API_KEY` |
| **Groq** | `https://api.groq.com/openai/v1` | `GROQ_API_KEY` |

## Sincronização de Plugins

Os plugins npm são sincronizados automaticamente com a versão do binário:

1. `opencode.bat` e `opencode.ps1` verificam a versão do `opencode.exe`
2. Comparam com a versão registrada em `data/.plugin-version`
3. Se houver diferença, executam `npm install` para atualizar
4. Retry automático (3x) em caso de falha

## Requisitos

- Windows 10/11
- PowerShell 5.1+
- Scoop (instalado automaticamente)
- npm (para plugins)
- Ollama (para normalização por IA)

## Solução de Problemas

```cmd
# Reinstalar tudo (remove marker de setup)
del data\.voice-setup-done
opencode.bat

# Forçar reinstalação dos plugins
del data\.plugin-version
opencode.bat

# Ver logs da última execução
type data\logs\launcher.jsonl

# Forçar nova versão (apaga cache)
del data\version.cache
opencode.bat
```

## Portabilidade

- Caminhos relativos
- Sem instalação
- Dados em `data/`
