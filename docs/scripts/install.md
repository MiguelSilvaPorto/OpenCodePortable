# Install BAT

Script de instalacao do OpenCode Portable.

## Localizacao

```
scripts/install.bat
```

## Funcionalidade

Instalador interativo que configura o pacote portatil para uso.

## Fluxo

```
1. Verificar se opencode.exe existe em bin/
2. Criar estrutura de diretorios (config/, data/)
3. Criar arquivo de configuracao padrao
4. [Opcional] Criar atalho na area de trabalho
5. [Opcional] Adicionar ao PATH do usuario
```

## Uso

```batch
cd OpenCodePortable
scripts\install.bat
```

## Perguntas Interativas

| Pergawa | Opcoes | Descricao |
|---------|--------|-----------|
| Criar atalho? | S/N | Atalho na area de trabalho |
| Adicionar ao PATH? | S/N | Acessar `opencode` de qualquer lugar |

## Notas

- Requer `opencode.exe` ja presente em `bin/`
- Usa PowerShell para criar atalho e modificar PATH
- Referencia `scripts/add-to-path.ps1` (pode nao existir)
