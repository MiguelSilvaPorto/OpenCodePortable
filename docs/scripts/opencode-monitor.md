# OpenCode Monitor

Monitor de logs em background do OpenCode Portable.

## Localizacao

```
scripts/opencode-monitor.ps1
```

## Funcionalidade

Monitor persistente que:

1. **Detecta crashes** do opencode.exe
2. **Monitora logs** em busca de erros
3. **Gera relatorios** de falha em Markdown

## Caracteristicas

- **Mutex global**: Apenas uma instancia por vez
- **Grace period**: 30 segundos sem processos antes de encerrar
- **Filtragem**: Ignora erros de `Projects/` e `worktrees`
- **Relatorios**: Gera `data/logs/crash-report.md`

## Fluxo

```
1. Adquirir Mutex global (impede duplicatas)
2. Loop infinito:
   a. Verificar processos opencode.exe
   b. Se nenhum por 30s → encerrar
   c. Monitorar launcher.jsonl por erros
   d. Gerar crash report se necessario
3. Liberar Mutex ao encerrar
```

## Relatorio de Crash

```markdown
# Relatorio de Falha do OpenCode Portable

**Data e Hora:** 2026-06-15 10:30:00
**Componente Afetado:** Erro de Inicializacao
**Arquivo de Origem:** opencode.bat
**Linha do Erro:** 141

## O que aconteceu?
[Descricao do erro]

## Detalhes Tecnicos
[Stack trace]
```

## Uso

O monitor e iniciado automaticamente pelos launchers:

```batch
start /b powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\opencode-monitor.ps1" -LogDir "data\logs" -OpenCodeHome "."
```

## Parametros

| Parametro | Obrigatorio | Descricao |
|-----------|-------------|-----------|
| `-LogDir` | Sim | Pasta de logs |
| `-OpenCodeHome` | Sim | Diretorio raiz do projeto |
