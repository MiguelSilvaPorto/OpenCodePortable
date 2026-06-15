# Framework de Testes

Documentacao do sistema de testes automatizados do OpenCode Portable.

## Localizacao

```
tests/run-tests.js
```

## Funcionalidade

Suite de testes de integracao que valida o funcionamento basico do OpenCode Portable.

## Testes

### Test 1: Portability Directory Isolation

Verifica que todos os arquivos sao criados localmente na pasta do projeto.

```
- Roda: opencode.exe agent list
- Verifica: data/opencode/opencode.db existe
- Resultado: Todos os arquivos isolados localmente
```

### Test 2: Agent Division Validation

Verifica que os agents estao disponiveis.

```
- Roda: opencode.exe agent list
- Verifica: "agent", "multitask", "ask" na saida
- Resultado: Agents divididos corretamente
```

### Test 3: Plan Mode Static Path

Verifica que o Plan Mode cria arquivos de plano.

```
- Roda: opencode.exe run ... --agent plan
- Verifica: .opencode/plans/temp_plan.md existe
- Resultado: Arquivo de plano criado
```

## Uso

```batch
cd tests
node run-tests.js
```

## Requisitos

- Node.js instalado
- opencode.exe em `bin/`
- Git instalado

## Avisos

- Os testes **deletam** `data/` e `config/` antes de rodar
- Nao execute em ambiente de producao
- Cria repositorio temporario em `tests/sandbox/`

## Variaveis de Ambiente

```javascript
OPENCODE_PORTABLE = '1'
OPENCODE_HOME = portableDir
OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = 'true'
OPENCODE_EXPERIMENTAL_PLAN_MODE = 'true'
```

## Estrutura

```
tests/
├── run-tests.js           # Framework principal
├── test_office_mcp.py     # Testes do MCP Office
├── test.bat               # Script de teste BAT
├── test-voice-correction.js  # Teste de correcao de voz
└── sandbox/               # Repositorio temporario (criado durante testes)
```
