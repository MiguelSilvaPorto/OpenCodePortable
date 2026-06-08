# Opencode Portable

Versão portátil do OpenCode com suporte a voz integrado.

## Início Rápido

```cmd
opencode.bat
```

**Na primeira execução**, o script automaticamente:
- Instala dependências (whisper-cpp, sox) via Scoop
- Baixa modelo de transcrição (~142 MB)
- Configura o plugin de voz

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
opencode-portable/
├── bin/
│   └── opencode.exe          # Executável
├── config/
│   └── opencode.jsonc         # Configuração (plugin de voz)
├── data/                      # Dados locais
├── scripts/
│   ├── cleanup.bat
│   ├── export-import.bat
│   ├── install.bat
│   └── package.bat
├── opencode.bat               # Launcher unificado
├── opencode.ps1               # Launcher PowerShell
└── README.md
```

## Scripts

| Script | Descrição |
|--------|-----------|
| `opencode.bat` | Launcher unificado (instala + configura + inicia) |
| `scripts\install.bat` | Instalação inicial |
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
      "endpoint": "http://localhost:11434/v1",  // Ollama
      "model": "llama3.2"
    }]
  ]
}
```

### Alternativas de LLM

| Provider | Endpoint |
|----------|----------|
| **Ollama** | `http://localhost:11434/v1` |
| **OpenAI** | `https://api.openai.com/v1` |
| **Anthropic** | `https://api.anthropic.com/v1` |
| **Groq** | `https://api.groq.com/openai/v1` |

## Requisitos

- Windows 10/11
- Scoop (instalado automaticamente)
- Ollama (para normalização por IA)

## Solução de Problemas

```cmd
# Reinstalar tudo
del data\.voice-setup-done
opencode.bat

# Verificar dependências
scripts\test.bat
```

## Portabilidade

- Caminhos relativos
- Sem instalação
- Dados em `data/`
