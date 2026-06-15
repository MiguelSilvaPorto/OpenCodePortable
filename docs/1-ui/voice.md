# Sistema de Voz

Pipeline completo de reconhecimento de voz do OpenCode Portable.

## Localizacao

```
config/opencode.jsonc  (configuracao do plugin)
data/whisper-models/   (modelos de IA)
data/.voice-setup-done (marker de setup)
```

## Pipeline

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌─────────────┐
│   Usuario    │───▶│  Sox (gravar) │───▶│ Whisper-CLI  │───▶│  LLM (limpar)│
│   Ctrl+R     │    │  audio.wav    │    │  transcrever │    │  texto limpo │
└─────────────┘    └──────────────┘    └─────────────┘    └─────────────┘
```

### 1. Gravacao (sox)

- `sox` captura audio do microfone
- Salva em formato WAV temporario

### 2. Transcricao (whisper-cpp)

- `whisper-cli` converte audio em texto
- Usa modelo `ggml-base.bin` (~148MB)
- Suporta multiplos idiomas

### 3. Normalizacao (LLM)

- Envia texto "sujo" para LLM
- Remove hesitacoes ("eh", "tipo", "sabe")
- Corrige termos tecnicos
- Dois providers possiveis:
  - **Ollama** (local): `http://localhost:11434/v1`
  - **Groq** (cloud): `https://api.groq.com/openai/v1`

## Controles

| Tecla/Comando | Acao |
|---------------|------|
| `Ctrl+R` | Iniciar/parar gravacao |
| `/stt-model` | Trocar modelo Whisper |
| `/stt-mic` | Trocar microfone |

## Dependencias

| Componente | Instalacao | Tamanho |
|------------|------------|---------|
| whisper-cpp | `scoop install whisper-cpp` | ~10MB |
| sox | `scoop install sox` | ~5MB |
| ggml-base.bin | Download automatico | ~148MB |
| Ollama | Instalacao manual | ~500MB |

## Configuracao

### Ollama (Padrao)

```jsonc
["@renjfk/opencode-voice", {
    "endpoint": "http://localhost:11434/v1",
    "model": "llama3.2"
}]
```

Para usar: `ollama serve` em terminal separado.

### Groq (Alternativa)

```jsonc
["@renjfk/opencode-voice", {
    "endpoint": "https://api.groq.com/openai/v1",
    "model": "llama3-8b-8192",
    "apiKeyEnv": "GROQ_API_KEY"
}]
```

Requer variavel de ambiente `GROQ_API_KEY`.

## Troubleshooting

| Problema | Causa | Solucao |
|----------|-------|---------|
| Botao microfone nao aparece | whisper-cpp nao instalado | Rodar `opencode.bat` (health check) |
| Audio nao grava | sox nao encontrado | Rodar `opencode.bat` (health check) |
| Transcricao ruim | Modelo corrompido | Deletar `data/whisper-models/ggml-base.bin` e rebaixar |
| Normalizacao falha | Ollama offline | Rodar `ollama serve` |
| Groq nao autentica | Config errada | Verificar `apiKeyEnv` (nao `apiKey`) |
