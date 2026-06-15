# Configuracao MCP

Como configurar servidores MCP no OpenCode Portable.

## Localizacao

```
config/opencode.jsonc
```

## Formato

```jsonc
"mcp": {
    "nome-do-servidor": {
        "type": "local",           // "local" ou "remote"
        "command": ["python", "scripts/arquivo.py"],  // Array de strings
        "enabled": true,           // true ou false
        "env": {}                  // Variaveis de ambiente (opcional)
    }
}
```

## Adicionar Novo Servidor

1. Crie o script Python/Node do servidor
2. Adicione a entrada em `config/opencode.jsonc`:

```jsonc
"mcp": {
    "office-mcp": { ... },
    "meu-novo-servidor": {
        "type": "local",
        "command": ["python", "scripts/meu_servidor.py"],
        "enabled": true
    }
}
```

3. Reinicie o OpenCode

## Desativar Servidor

```jsonc
"mcp": {
    "office-mcp": {
        "enabled": false  // Servidor sera ignorado
    }
}
```

## Servidor Remoto

```jsonc
"mcp": {
    "api-externa": {
        "type": "remote",
        "url": "https://api.example.com/mcp",
        "headers": {
            "Authorization": "Bearer {env:API_KEY}"
        }
    }
}
```

## Variaveis de Ambiente

Use `{env:VARIAVEL}` para interpolacao em headers:

```jsonc
"headers": {
    "Authorization": "Bearer {env:GITHUB_TOKEN}"
}
```

## Portabilidade

Os caminhos em `command` sao **automaticamente corrigidos** pelo `opencode.bat`/`opencode.ps1`:

- Converte `\` para `/`
- Usa o diretorio atual do projeto

Isso garante que funcione mesmo se a pasta for movida.

## Troubleshooting

| Problema | Causa | Solucao |
|----------|-------|---------|
| Servidor nao inicia | Caminho incorreto | Delete o config e deixe recriar |
| "Command not found" | Python/Node nao no PATH | Instale via Scoop |
| Timeout | Servidor muito lento | Aumente `mcp_timeout` no config |
| Erro de import | Biblioteca nao instalada | `pip install [biblioteca]` |
