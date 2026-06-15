# opencode.bat

Launcher principal do OpenCode Portable em formato batch.

## Localizacao

```
opencode.bat
```

## Funcionalidades

### 1. Health Check Automatico

A cada execucao, verifica e instala automaticamente dependencias faltantes:

| Dependencia | Comando de Verificacao | Instalacao |
|-------------|------------------------|------------|
| Scoop | `where scoop` | `Invoke-RestMethod -Uri https://get.scoop.sh` |
| whisper-cpp | `where whisper-cli` | `scoop install whisper-cpp` |
| sox | `where sox` | `scoop install sox` |
| Modelo Whisper | `exist %MODELS_DIR%\ggml-base.bin` | Download do HuggingFace |
| Python | `where python` | `scoop install python` |
| Bibliotecas Python | `python -c "import openpyxl..."` | `pip install openpyxl...` |
| Azure CLI | `where az` | `scoop install azure-cli` |

### 2. Download do Executavel

- Verifica se `bin/opencode.exe` existe e esta integro
- Se ausente ou corrompido, baixa da versao 1.17.7
- Extrai automaticamente

### 3. Verificacao de Atualizacoes

- Consulta GitHub API para ultima versao
- Oferece atualizacao interativa (S/N)

### 4. Correcao de Caminhos MCP

- Detecta se caminhos no `opencode.jsonc` estao desatualizados
- Reescreve com o diretorio atual (portabilidade)

### 5. Gerenciamento de Logs

- Cria logs em formato JSONL (`data/logs/launcher.jsonl`)
- Monitor de background via PowerShell

## Fluxo

```
1. Definir variaveis de ambiente
2. Adicionar shims do Scoop ao PATH
3. Iniciar monitor de logs (background)
4. Verificar/Baixar opencode.exe
5. Verificar atualizacoes
6. Health check de dependencias
7. Se marker nao existe: setup inicial completo
8. Corrigir caminhos MCP
9. Criar juncao multitask-worktrees
10. Iniciar opencode.exe
```

## Erros Comuns

| Erro | Causa | Solucao |
|------|-------|---------|
| "Falha ao baixar opencode.exe" | Sem internet ou GitHub offline | Verificar conexao |
| "Falha ao instalar Scoop" | PowerShell com ExecutionPolicy restrito | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| "whisper-cli nao encontrado" | Scoop shims nao no PATH | Reiniciar terminal apos instalar Scoop |
