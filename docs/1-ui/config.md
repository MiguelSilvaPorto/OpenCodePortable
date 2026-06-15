# Configuracao (opencode.jsonc)

Arquivo de configuracao principal do OpenCode Portable.

## Localizacao

```
config/opencode.jsonc
```

## Estrutura

```jsonc
{
    "$schema": "https://opencode.ai/config.json",  // Schema para validacao
    "plugin": [...],                                  // Plugins habilitados
    "mcp": {...}                                      // Servidores MCP
}
```

## Plugins Configurados

| Plugin | Tipo | Descricao |
|--------|------|-----------|
| `@renjfk/opencode-voice` | Externo | Reconhecimento de voz via Ollama/Groq |
| `multitask` | Interno | Agent para tarefas em background |
| `multitask-tui.tsx` | Interno | Interface TUI do multitask |
| `workspace-tui.tsx` | Interno | Interface TUI de workspaces |
| `auto-switch-mode.ts` | Interno | Troca automatica de modo |

### Configuracao do Voice Plugin

```jsonc
["@renjfk/opencode-voice", {
    "endpoint": "http://localhost:11434/v1",  // Ollama (padrao)
    "model": "llama3.2"
}]
```

Se `GROQ_API_KEY` estiver configurada, usa Groq:
```jsonc
["@renjfk/opencode-voice", {
    "endpoint": "https://api.groq.com/openai/v1",
    "model": "llama3-8b-8192",
    "apiKeyEnv": "GROQ_API_KEY"
}]
```

## Servidores MCP

```jsonc
"mcp": {
    "office-mcp": {
        "type": "local",
        "command": ["python", "scripts/office_mcp.py"],
        "enabled": true
    },
    "project-mcp": {
        "type": "local",
        "command": ["python", "scripts/project_generator.py"],
        "enabled": true
    }
}
```

## Portabilidade

Os caminhos MCP sao **automaticamente corrigidos** a cada execucao:
- `opencode.bat` verifica se os caminhos estao corretos
- Se estiverem desatualizados, reescreve com o diretorio atual
- Converte backslashes para forward slashes (requisito JSON)

## Como Modificar

1. Edite `config/opencode.jsonc`
2. Reinicie o OpenCode para aplicar mudancas
3. Os caminhos serao corrigidos automaticamente na proxima execucao

## Erros Comuns

| Erro | Causa | Solucao |
|------|-------|---------|
| "ConfigInvalidError" | JSON invalido | Valide o JSON com `$schema` |
| MCP servers nao iniciam | Caminhos incorretos | Delete o config e deixe recriar |
| Plugin nao carrega | Plugin nao encontrado | Verifique se esta na lista `plugin` |
