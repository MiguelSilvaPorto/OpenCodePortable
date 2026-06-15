# Voice Plugin

Plugin de reconhecimento de voz para o OpenCode.

## Localizacao

```
Plugin: @renjfk/opencode-voice (npm)
Config: config/opencode.jsonc
```

## Funcionalidade

Permite ao usuario dictar texto via microfone, que e transcrito e inserido no prompt.

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌─────────────┐
│   Ctrl+R     │───▶│  Gravar audio │───▶│  Transcrever │───▶│  Inserir no │
│   Ativar     │    │  (sox)        │    │  (whisper)   │    │  prompt     │
└─────────────┘    └──────────────┘    └─────────────┘    └─────────────┘
```

## Configuracao

### Ollama (Local - Padrao)

```jsonc
["@renjfk/opencode-voice", {
    "endpoint": "http://localhost:11434/v1",
    "model": "llama3.2"
}]
```

### Groq (Cloud - Alternativa)

```jsonc
["@renjfk/opencode-voice", {
    "endpoint": "https://api.groq.com/openai/v1",
    "model": "llama3-8b-8192",
    "apiKeyEnv": "GROQ_API_KEY"
}]
```

**Importante:** Use `apiKeyEnv` (nome da variavel), nao `apiKey` (valor).

## Dependencias

| Componente | Instalacao | Obrigatorio |
|------------|------------|-------------|
| whisper-cpp | `scoop install whisper-cpp` | Sim |
| sox | `scoop install sox` | Sim |
| ggml-base.bin | Download automatico | Sim |
| Ollama | Instalacao manual | Apenas para normalizacao |

## Comandos

| Tecla | Acao |
|-------|------|
| `Ctrl+R` | Iniciar/parar gravacao |
| `/stt-model` | Trocar modelo Whisper |
| `/stt-mic` | Trocar microfone |

## Troubleshooting

| Problema | Causa | Solucao |
|----------|-------|---------|
| Botao microfone nao aparece | whisper-cpp nao instalado | Rodar `opencode.bat` |
| Audio nao grava | sox nao encontrado | Rodar `opencode.bat` |
| Transcricao ruim | Modelo corrompido | Rebaixar `ggml-base.bin` |
| Normalizacao falha | Ollama offline | Rodar `ollama serve` |
| Groq erro 401 | Config errada | Verificar `apiKeyEnv` |
