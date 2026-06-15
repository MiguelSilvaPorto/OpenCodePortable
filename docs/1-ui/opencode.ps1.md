# opencode.ps1

Launcher alternativo do OpenCode Portable em formato PowerShell.

## Localizacao

```
opencode.ps1
```

## Diferencas do BAT

| Recurso | BAT | PowerShell |
|---------|-----|------------|
| Health check | Simples (sequencial) | Idempotente (array de steps) |
| Logs | Append simples | Rotacao automatica + symlinks |
| Download | Invoke-WebRequest basico | Retry com exponential backoff |
| Cache de versao | Nao | Cache 24h em `data/version.cache` |
| Seletor de projetos | Nao | Interface interativa completa |
| Validacao de exe | Tamanho minimo | Tamanho + execucao + version check |

## Funcionalidades Avancadas

### Sistema de Logs com Rotacao

- Logs em JSONL estruturado
- Rotacao automatica apos 10MB
- Mantem ultimos 5 arquivos
- Symlink para `launcher-latest.jsonl`

### Cache de Versao

- Armazena ultima versao consultada em `data/version.cache`
- TTL de 24 horas
- Evita consultas repetidas ao GitHub API

### Download Robusto

- ate 3 tentativas com delay exponencial
- Verificacao de integridade (tamanho minimo 5MB)
- Verificacao pos-extracao (execucao + versao)

### Seletor de Projetos

- Lista projetos em `Projects/`
- Interface interativa para selecao
- Criacao de novos projetos com Git init
- Opcao de criar repositorio GitHub via `gh` CLI

## Uso

```powershell
# Executar com projeto padrao
.\opencode.ps1

# Executar com projeto especifico
.\opencode.ps1 "C:\meu\projeto"

# Passar argumentos adicionais
.\opencode.ps1 --verbose
```

## Variaveis de Ambiente

Herdadas do BAT mais:

| Variavel | Descricao |
|----------|-----------|
| `CACHE_FILE` | Caminho para `data/version.cache` |
| `PROJECTS_ROOT` | Caminho para `Projects/` |
| `TIMEOUT_DOWNLOAD` | Timeout de download (120s) |
| `TIMEOUT_API` | Timeout da API GitHub (15s) |
| `MAX_RETRIES` | Maximo de tentativas (3) |
