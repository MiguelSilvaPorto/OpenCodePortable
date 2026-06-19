# Regras do Agente Portatil - Sistema .brain

Voce opera em um ambiente 100% portatil. O projeto pode ser movido entre particoes de disco e maquinas a qualquer momento.

---

## 1. LEI DO CAMINHO RELATIVO

E EXPRESSAMENTE PROIBIDO ler, escrever ou referenciar caminhos absolutos baseados no sistema operacional hospedeiro.

Toda referencia a arquivos DEVE utilizar caminhos relativos baseados na raiz do workspace (`./`).

---

## 2. SISTEMA BRAIN (MCP) — OBRIGATORIO

O sistema de memoria portatil esta disponivel via ferramentas MCP. **VOCE DEVE USAR ESTAS FERRAMENTAS EM TODA CONVERSA.**

### Ferramentas disponiveis

- **`brain_init`** — Inicializa sessao. **CHAME PRIMEIRO ANTES DE QUALQUER COISA.**
- **`brain_add`** — Armazena memoria com embedding vetorial
- **`brain_search`** — Busca semantica por similaridade
- **`brain_list`** — Lista memorias da sessao
- **`brain_status`** — Mostra UUID ativo e estatisticas
- **`brain_sync`** — Sincroniza SQLite para Markdown legivel

### FLUXO OBRIGATORIO (siga SEMPRE)

**PASSO 1 — Toda conversa comeca assim:**
```
Chame brain_init()
```
Isso cria a sessao e retorna o UUID. **NUNCA pule este passo.**

**PASSO 2 — Sempre que o usuario enviar algo relevante:**
```
Chame brain_add(text="resumo do que o usuario pediu ou fez", turn=X)
```
Onde X e o numero do turno (1, 2, 3...)

**PASSO 3 — Antes de responder perguntas sobre o passado:**
```
Chame brain_search("pergunta do usuario")
```

**PASSO 4 — No final de cada interacao importante:**
```
Chame brain_sync()
```

### Exemplo de como voce deve agir

Usuario: "crie uma calculadora"

Voce faz:
1. `brain_init()` → retorna UUID
2. `brain_add(text="Criacao de calculadora - Desktop Electron com operacoes basicas", turn=1)`
3. `brain_add(text="Decisao: usar Python com interface grafica", turn=1)` (se aplicavel)
4. Cria o codigo
5. `brain_add(text="Calculadora criada em calculator.py com operacoes: +, -, x, /, %, raiz quadrada", turn=2)`
6. `brain_sync()`

### QuandO usar brain_add

Sempre que ocorrer um destes eventos:
- Decisao de arquitetura ou design
- Descricao de imagem enviada pelo usuario
- Codigo importante criado ou alterado
- Erro encontrado e/ou solucao aplicada
- Contexto de escopo do trabalho atual
- Mudanca de direcao na conversa

### Quando usar brain_search

Antes de responder perguntas que exigem contexto de sessoes anteriores ou historico. Se houver resultados relevantes (score > 0.5), integre-os na resposta.

### Imagens

Quando o usuario enviar imagem:
1. Descreva visualmente o conteudo em texto denso
2. Armazene via `brain_add` com prefixo `[IMAGEM]`:
   - `text: "[IMAGEM] nome_arquivo.png: descricao visual detalhada"`

---

## 3. CONTAGEM DE TURNOS

Use **Contador Numerico de Turnos** (`[Turno X]`), nunca timestamps como fonte de verdade.

Para descobrir o ultimo turno apos um reset:
1. Chame `brain_list` para ver as ultimas memorias
2. Identifique o maior turno existente
3. Proximo turno = maior + 1

---

## 4. MITIGACAO DE TOKEN BLOAT

- Mantenha `session_memory.md` abaixo de **200 linhas**
- Quando ultrapassar, mova entradas antigas para `session_history.md` em formato condensado
- Chame `brain_sync` periodicamente para manter o Markdown atualizado

---

## 5. PREVENCAO DE SOBRESCRITA

Antes de propor atualizacao do `session_memory.md`:
1. Leia o conteudo fisico do arquivo
2. Compare com o que voce sabe da conversa
3. Se identificar linhas editadas manualmente pelo usuario, integre-as no novo resumo

---

## 6. ALERTA DE AUSENCIA DO .brain

Se a pasta `./.brain/` nao existe no workspace, alerte imediatamente:

> **[ALERTA DE PORTABILIDADE]** A pasta `./.brain/` nao foi encontrada. Deseja inicializar a estrutura de memoria portatil do zero?

---

## 7. ISOLAMENTO DE SESSAO

- Nunca acesse pastas de outros Conversation_ID alem da sessao ativa
- Valide que qualquer caminho sob `./.brain/sessions/` deve ser literalmente a pasta da sessao atual
- Bloqueie caminhos relativos como `../` que tentem navegar para pastas irmas

---

## 8. COMANDOS DO USUARIO

- **`!nova-sessao`** — Arquive a sessao atual, delete `current_session.txt`, gere novo UUID via `brain_init`
- **`!sessoes`** — Liste todas as pastas em `./.brain/sessions/` mostrando UUID, titulo e status
- **`!carregar {UUID}`** — Atualize `current_session.txt` com o UUID informado
- **`!status`** — Chame `brain_status` para mostrar situacao atual

---

## RESUMO EXECUTIVO (LEIA PRIMEIRO)

1. **Toda conversa comeca com `brain_init()`** — SEMPRE, sem excecao
2. **Informacao relevante?** `brain_add` com descricao concisa
3. **Pergunta contextual?** `brain_search` antes de responder
4. **Imagem?** Descreva em texto e armazene com prefixo `[IMAGEM]`
5. **Caminhos?** Sempre `./` relativos. Nunca absolutos.
6. **Ferramentas MCP?** Use SEMPRE. Nao e opcional.
