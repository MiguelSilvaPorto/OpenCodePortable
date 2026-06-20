# 4. Plugins

Esta secao documenta os plugins do OpenCode Portable.

## Arquivos

| Arquivo | Descricao |
|---------|-----------|
| [voice-plugin.md](voice-plugin.md) | Plugin de reconhecimento de voz |
| [workspace-plugin.md](workspace-plugin.md) | Plugin de workspaces |
| [auto-switch-plugin.md](auto-switch-plugin.md) | Plugin de troca automatica |

## Lista de Plugins

| Plugin | Tipo | Descricao |
|--------|------|-----------|
| `@renjfk/opencode-voice` | Externo (npm) | Reconhecimento de voz |
| `workspace-tui.tsx` | Interno | Interface TUI workspaces |
| `auto-switch-mode.ts` | Interno | Troca automatica de modo |

## Configuracao

Plugins sao listados em `config/opencode.jsonc`:

```jsonc
"plugin": [
    ["@renjfk/opencode-voice", {
        "endpoint": "http://localhost:11434/v1",
        "model": "llama3.2"
    }],
    "workspace-tui.tsx",
    "auto-switch-mode.ts"
]
```

## Plugins vs MCP Servers

| Caracteristica | Plugin | MCP Server |
|----------------|--------|------------|
| Execucao | Dentro do OpenCode | Subprocesso separado |
| Comunicacao | Hooks internos | Protocolo MCP |
| Uso | UI, integracao | Ferramentas externas |
| Exemplo | Voice | Office, Projects |
