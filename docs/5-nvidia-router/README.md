# NVIDIA Model Router

Proxy server local que roteia requisições do opencode entre múltiplos modelos gratuitos da NVIDIA (build.nvidia.com), com roteamento inteligente, fallback automático e monitoramento de RPM.

## Visão Geral

```
opencode → "nvidia-router/auto"
              ↓
     Proxy local (localhost:9393)
              ↓
     Modelo ativo responde rápido? → CONTINUA nele
     Modelo demora? → Troca pro próximo
     Todos falham? → Tenta fallback models
     RPM atingido? → Avisa no chat
              ↓
     Resposta retorna para opencode
```

## Características

- **Roteamento inteligente**: mantém o modelo que responde rápido, troca quando ele fica lento
- **Fallback automático**: se o modelo ativo falhar, tenta o próximo na fila
- **7 modelos fallback**: se todos os 5 primários falharem, tenta mais 7 modelos
- **Monitoramento de RPM**: detecta quando o limite de 40 RPM é atingido e avisa no chat
- **Rate limit handling**: se receber 429, pula para o próximo modelo imediatamente
- **Chave API automática**: lê do `~/.local/share/opencode/auth.json` (a mesma chave do `/connect`)

## Modelos Primários (5)

| Modelo | Tipo | Descrição |
|--------|------|-----------|
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | Omni-modal | Otimizado pela NVIDIA, suporta imagem/vídeo/fala/texto |
| `google/gemma-4-31b-it` | Multimodal | Denso, rápido, suporta imagens |
| `mistralai/mistral-medium-3.5-128b` | Geral | Equilíbrio qualidade/velocidade |
| `meta/llama-3.3-70b-instruct` | Geral | NIM otimizado, 2x throughput |
| `deepseek-ai/deepseek-v4-flash` | Coding | Rápido para código |

## Modelos Fallback (7)

| Modelo | Descrição |
|--------|-----------|
| `qwen/qwen3-next-80b-a3b-instruct` | Qwen3 Next |
| `moonshotai/kimi-k2-instruct` | Kimi K2 |
| `meta/llama-3.1-70b-instruct` | Llama 3.1 |
| `microsoft/phi-4-mini-instruct` | Phi-4 Mini |
| `mistralai/mixtral-8x22b-instruct` | Mixtral 8x22B |
| `minimaxai/minimax-m2.7` | MiniMax M2.7 |
| `stepfun-ai/step-3-5-flash` | Step 3.5 Flash |

## Comportamento

### Modelo Auto (recommended)

Quando você seleciona `auto` no model selector, o router usa roteamento inteligente:

1. **Modelo responde rápido (< 30s)** → continua usando ele
2. **Modelo demora (> 30s)** → marca como "slow", vai pro fim da fila, troca pro próximo
3. **Modelo volta a responder rápido** → reativa como prioritário
4. **Erro 429 (rate limit)** → pula imediatamente pro próximo modelo
5. **Todos os 5 primários falham** → tenta 7 modelos fallback
6. **Tudo falha** → verifica RPM, se >= 30/40 avisa no chat

### Modelo Específico

Você também pode selecionar um modelo específico (ex: `google/gemma-4-31b-it`). Nesse caso, o router faz proxy direto para aquele modelo sem roteamento inteligente.

## Configuração

### 1. Provider no opencode.jsonc

```jsonc
"provider": {
    "nvidia-router": {
        "npm": "@ai-sdk/openai-compatible",
        "name": "NVIDIA Router (local)",
        "options": {
            "baseURL": "http://localhost:9393/v1",
            "apiKey": "nvidia-router-local"
        },
        "models": {
            "auto": { "name": "Auto-Router (intelligent)" },
            "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning": { "name": "Nemotron 3 Nano Omni 30B" },
            "google/gemma-4-31b-it": { "name": "Gemma 4 31B" },
            "mistralai/mistral-medium-3.5-128b": { "name": "Mistral Medium 3.5 128B" },
            "meta/llama-3.3-70b-instruct": { "name": "Llama 3.3 70B" },
            "deepseek-ai/deepseek-v4-flash": { "name": "DeepSeek V4 Flash" },
            "qwen/qwen3-next-80b-a3b-instruct": { "name": "Qwen3 Next 80B" },
            "moonshotai/kimi-k2-instruct": { "name": "Kimi K2 Instruct" }
        }
    }
}
```

**Campo obrigatório**: `"npm": "@ai-sdk/openai-compatible"` — sem ele, o opencode não sabe como conectar ao provider.

### 2. Instalar dependência npm

```powershell
cd ~/.config/opencode
npm install @ai-sdk/openai-compatible
```

### 3. Chave API

O router lê a chave NVIDIA automaticamente de `~/.local/share/opencode/auth.json` (a mesma chave que você colou no `/connect` do opencode).

Se precisar usar outra chave, defina a variável de ambiente:

```powershell
$env:NVIDIA_API_KEY = 'nvapi-sua-chave'
```

Ou crie um arquivo `.env` na raiz do projeto:

```
NVIDIA_API_KEY=nvapi-sua-chave
```

### 4. Iniciar o router

O router inicia **automaticamente** quando você executa `opencode.bat`. Ele roda em background (sem janela) e persiste entre sessões.

Se precisar iniciar manualmente:

```powershell
# Terminal separado
python D:/Miguel/Github/OpenCodePortable/scripts/nvidia_router.py
```

Ou use o script batch:

```cmd
D:\Miguel\Github\OpenCodePortable\scripts\start_nvidia_router.bat
```

### 5. Conectar no opencode

1. Abra o opencode
2. Abra o model selector (Ctrl+K ou clique no nome do modelo)
3. Selecione **NVIDIA Router (local)** → **auto** (ou um modelo específico)

## Endpoints HTTP

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/v1/models` | GET | Lista modelos disponíveis |
| `/v1/chat/completions` | POST | Proxy para NVIDIA API |
| `/health` | GET | Health check |
| `/status` | GET | Diagnósticos (modelo ativo, RPM, latência) |

## Variáveis de Ambiente

| Variável | Default | Descrição |
|----------|---------|-----------|
| `NVIDIA_API_KEY` | (do auth.json) | Chave da API NVIDIA |
| `NVIDIA_ROUTER_PORT` | `9393` | Porta do servidor |
| `NVIDIA_ROUTER_MAX_RPM` | `40` | Limite de RPM |

## Solução de Problemas

### Router não aparece no model selector

1. Verifique se o router está rodando: `curl http://localhost:9393/health`
2. Se não estiver, reinicie o opencode (o `opencode.bat` inicia o router automaticamente)
3. Verifique se `@ai-sdk/openai-compatible` está instalado: `cd ~/.config/opencode && npm list @ai-sdk/openai-compatible`

### "NVIDIA_API_KEY not set"

O router não encontrou a chave. Opções:
1. Execute `/connect` no opencode e cole a chave NVIDIA
2. Defina `$env:NVIDIA_API_KEY = 'nvapi-...'`
3. Crie `.env` na raiz do projeto com `NVIDIA_API_KEY=nvapi-...`

### Modelo responde vazio

Alguns modelos da NVIDIA usam API assíncrona (202 → polling). O router faz polling automaticamente, mas pode haver atraso. Tente um modelo síncrono como `meta/llama-3.3-70b-instruct`.

### RPM atingido

A NVIDIA limita a 40 RPM por chave. O router avisa no chat quando o limite está próximo. Soluções:
1. Aguarde ~60 segundos
2. Solicite upgrade para 200 RPM em https://build.nvidia.com
3. Use modelos diferentes (分散 a carga)

## Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `scripts/nvidia_router.py` | Servidor proxy (Starlette + Uvicorn + httpx) |
| `scripts/start_nvidia_router.bat` | Script de inicialização |
| `.env` | Chave API (opcional) |
| `config/opencode.jsonc` | Config do provider |
