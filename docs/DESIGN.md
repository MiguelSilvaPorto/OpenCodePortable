# DESIGN.md — Princípios de Apresentação Profissional

> **Origem:** Síntese de Garr Reynolds (*Presentation Zen*, 2008/2011), Nancy Duarte (*Slide:ology*, 2008; *Resonate*, 2010) e Chip & Dan Heath (*Made to Stick*, 2007).
>
> **Propósito:** Este documento define as regras que separam um PPTX profissional de um PPTX amador. Todo slide gerado por código deve respeitar estas regras. Se um slide viola uma regra, há motivo — não acidente.

---

## 1. Princípios Fundamentais (a filosofia)

### 1.1 Restrição > Liberdade (Zen)
A beleza nasce da restrição, não da abundância. Limite opções, remova o desnecessário, abrace o vazio.

**Aplicação prática:**
- 1 ideia por slide
- 1 fonte (ou no máximo 2: títulos + corpo)
- 1 cor de destaque (mais neutros)
- Sem gradientes, sombras ou efeitos 3D
- Sem transições decorativas (apenas fade ou corte seco)

### 1.2 Sinal > Ruído (Duarte — Slide:ology)
Cada elemento deve amplificar a mensagem ou é ruído. Elementos decorativos competem pela atenção cognitiva do espectador.

**Aplicação prática:**
- Bordas, fundos, ícones devem ter **função**, não decoração
- Se um elemento pode ser removido sem perda de informação, remova-o
- Texto repetido (cabeçalho + corpo dizendo a mesma coisa) é ruído

### 1.3 Contraste cria hierarquia (Reynolds)
Hierarquia visual guia o olho. Sem hierarquia, o olho vagueia.

**Aplicação prática:**
- **Tamanho** diferencia níveis: título grande, subtítulo médio, corpo pequeno
- **Peso** diferencia: bold para ênfase, regular para texto base
- **Cor** diferencia: 1 cor saturada para destaque, neutros para base
- **Espaço** diferencia: muito espaço ao redor do elemento importante

---

## 2. Tipografia (Regra das Fontes)

### 2.1 Regra da Família Única
**Máximo 2 famílias de fonte** em toda a apresentação. Ideal: 1.

**Padrão recomendado (Neutro Profissional):**
- **Títulos:** Montserrat Bold (sans-serif geométrica, transmite modernidade)
- **Corpo:** Open Sans Regular (legibilidade alta, neutra)
- **Alternativas:** Roboto, Lato, Inter, Calibri (nativas)

**Tamanhos (slide 16:9, 13.33in × 7.5in):**
| Elemento       | Tamanho | Peso     |
|----------------|---------|----------|
| Título capa    | 54-72pt | Bold     |
| Título slide   | 32-44pt | Bold     |
| Subtítulo      | 20-28pt | Semibold |
| Corpo          | 18-22pt | Regular  |
| Caption/rodapé | 12-14pt | Regular  |
| **Mínimo**     | **14pt**| —        |

> **Regra inegociável:** Nada abaixo de 14pt. Texto menor é ilegível em sala de reunião.

### 2.2 Alinhamento Consistente
- **Esquerda** para corpo de texto (legível, ocidental-friendly)
- **Centro** APENAS para títulos curtos (capa, seções)
- **Nunca** justificado (cria rios de espaço irregulares)

### 2.3 Largura de Linha
- **50-75 caracteres por linha** (corpo de texto)
- Linhas longas cansam, linhas curtas demais fragmentam

---

## 3. Cor (Regra da Paleta)

### 3.1 Paleta de 3-5 Cores
**Estrutura obrigatória:**
1. **1 cor neutra escura** (texto principal) → #1F2937, #0F172A
2. **1 cor neutra clara** (fundo) → #FFFFFF, #F8FAFC
3. **1 cor de destaque** (ênfase) → 1 tom saturado
4. **1 cor de apoio** (opcional, dados) → complementar ao destaque
5. **1 cor de alerta** (opcional, negativo) → tom quente

**Exemplo A — Paleta "Dramática" (alto contraste, fundo escuro):**
- Texto: `#0B1020` (azul quase preto, profundo)
- Fundo: `#0F172A` (azul muito escuro, noite)
- Destaque: `#F59E0B` (âmbar, quente)
- Apoio: `#3B82F6` (azul, frio)
- Alerta: `#EF4444` (vermelho)

**Exemplo B — Paleta "Clean Corporate" (fundo claro, sóbria):**
- Texto: `#1F2937`
- Fundo: `#FFFFFF`
- Destaque: `#F59E0B`
- Apoio: `#64748B`
- Alerta: `#DC2626`

### 3.2 Contraste Mínimo WCAG AA
- **Texto normal:** contraste 4.5:1
- **Texto grande (>24pt):** contraste 3:1
- **Nunca:** texto claro sobre claro, escuro sobre escuro

### 3.3 Uso da Cor de Destaque
- **≤ 10% da área do slide** (regra do acento)
- Usada para: 1 palavra de ênfase, 1 número-chave, 1 ícone principal
- **Nunca** como fundo inteiro (esgota o impacto)

---

## 4. Espaço em Branco (Regra do Vazio)

### 4.1 Margens Generosas
**Margens mínimas do slide (16:9, 13.33in × 7.5in):**
- Superior: 0.6in
- Inferior: 0.5in
- Esquerda: 0.6in
- Direita: 0.6in
- **Área útil:** 12.13in × 6.4in

### 4.2 Regra dos Terços (Grid)
Divida o slide em uma grade 3×3. Posicione os elementos-chave **nas interseções** ou **ao longo das linhas**, nunca centralizado burro.

```
+----------+----------+----------+
|          |          |          |
| (1,1)    | (1,2)    | (1,3)    |
|          |          |          |
+----------+----------+----------+
|          |          |          |
| (2,1)    | (2,2)    | (2,3)    |  ← Olho pousa aqui primeiro
|          |          |          |
+----------+----------+----------+
|          |          |          |
| (3,1)    | (3,2)    | (3,3)    |
|          |          |          |
+----------+----------+----------+
```

### 4.3 Espaço Entre Elementos
- **Padding interno** de shapes com texto: ≥ 0.1in
- **Gap entre elementos** relacionados: 0.2-0.4in
- **Gap entre blocos** não relacionados: 0.6-1.0in
- **Respiração ao redor** do elemento principal: ≥ 1.0in de cada lado

---

## 5. Estrutura do Conteúdo (Regra da Narrativa — Resonate)

### 5.1 Estrutura "What Is → What Could Be → What Is"
Toda apresentação persuasiva alterna entre:
- **What Is:** a realidade atual (o problema, o status quo)
- **What Could Be:** a visão do futuro (a solução, o ideal)
- **What Is (novo):** a ação (a ponte entre os dois)

### 5.2 Pirâmide de Minto (Regra de Ouro)
- 1 tese principal (1 slide)
- 3 argumentos de apoio (3 slides)
- Evidências/dados para cada argumento (1-2 slides cada)
- Conclusão/CTA (1 slide)

**Total típico:** 10-15 slides para 20min de apresentação.

### 5.3 Regra do "Six-Word Slide"
- **Máximo 6 palavras por slide** (ideal para slides de impacto)
- Se precisar de mais, use uma sequência de slides
- **Exceção:** slides de dados comparativos (tabelas, gráficos)

---

## 6. Tipos de Slide e Suas Regras

### 6.1 Slide de Capa
- **1 imagem dominante** (full-bleed OU 60% da área)
- **1 título** (≤ 6 palavras, bold, 54-72pt)
- **1 subtítulo** (opcional, ≤ 12 palavras, 20-28pt)
- **Sem logo pequeno no canto** (anti-padrão amador)
- **Sem "Apresentação por..."** (isso vai no rodapé ou último slide)

### 6.2 Slide de Conteúdo (Texto)
- **1 título** curto (≤ 6 palavras, 32-40pt)
- **3-5 bullets curtos** (≤ 8 palavras cada)
- OU **1 parágrafo de 2-3 linhas** (≤ 50 palavras)
- **Sem parágrafos longos** (leitor não vai ler)

### 6.3 Slide de Dados (Gráfico/Tabela)
- **1 título** declarativo (afirmação, não pergunta)
- **1 visual** que responda a pergunta do título
- **1 frase de destaque** (a conclusão do dado)
- **Fonte dos dados** no rodapé (10-12pt, cinza)

### 6.4 Slide de Citação
- **Aspas grandes decorativas** (1 par de, 120pt+, cinza claro)
- **Citação** (24-32pt, 2-4 linhas)
- **Autor + contexto** (16-18pt, abaixo da citação)

### 6.5 Slide de Seção/Divisor
- **Fundo da cor de destaque** (sólido)
- **Texto branco** sobre fundo saturado
- **1 número grande** (capítulo/seção) opcional
- **1 título** curto (≤ 3 palavras)

### 6.6 Slide de Imagem Full-Bleed
- Imagem ocupa **100% do slide**
- **Texto overlay** (caixa semitransparente ou texto branco com sombra)
- **1 ideia** apenas

### 6.7 Slide de Comparação
- **2 colunas** lado a lado
- **Título simétrico** em cada coluna
- **3-5 pontos** em cada (paralelos)
- **Separação visual** clara (linha ou espaço)

---

## 7. Imagens (Regra do Significado)

### 7.1 Imagem > Texto (Duarte)
Uma imagem que **reforça** a mensagem vale por 100 palavras. Uma imagem **decorativa** vale por 0.

**Aplicação prática:**
- Foto real > ilustração genérica > ícone > emoji
- Nunca: fotos de banco genéricas (pessoas olhando para câmera, aperto de mão)

### 7.2 Regra do "Show, Don't Tell"
- **Em vez de:** "Nosso time é diverso" + foto genérica de pessoas
- **Faça:** "Time de 12 pessoas, 5 nacionalidades" + foto REAL do time
- **Em vez de:** "Espaço é bonito" + paisagem genérica
- **Faça:** "Mercúrio: 4.880 km de diâmetro" + foto REAL de Mercúrio (NASA, domínio público)

### 7.3 Tratamento de Imagens
- **Alta resolução:** ≥ 1920×1080 (full-HD mínimo)
- **Sem distorção de proporção**
- **Filtro opcional:** preto e branco OU cor dessaturada para consistência
- **Sem bordas decorativas**

---

## 8. Animações e Transições (Regra do Invisível)

### 8.1 Animação: Só Quando Comunica
- **Permitido:** Aparecer (fade) para construção sequencial de ideia
- **Permitido:** Apontar/destacar (highlight) para chamar atenção a uma parte
- **Proibido:** Girar, saltar, voar, zoom (cinemark, 1995)
- **Proibido:** Áudio (sons de palmas, transições)

**Regra prática:** Se a animação não está ensinando algo (sequência, causa-efeito), não use.

### 8.2 Transição de Slide
- **Padrão:** Nenhuma (corte seco)
- **Aceitável:** Fade (200-400ms)
- **Proibido:** Slide da direita, cubo, olho mágico, etc.

### 8.3 Timing
- **Aparecer/fade in:** 300-500ms
- **Saída:** 200-300ms
- **Trigger:** on click (manual) para apresentações, after 2s para auto-run

---

## 9. Layout e Grid (Regra do Sistema)

### 9.1 Slide Master Consistente
Todos os slides da apresentação devem compartilhar:
- **Mesma fonte** (títulos e corpo)
- **Mesma paleta** de cores
- **Mesmo rodapé** (logo, número de página)
- **Mesma posição** de elementos recorrentes

### 9.2 Slides de Conteúdo: 5 Layouts Canônicos
1. **Título + 1 bloco de texto** (capa, divisor)
2. **Título + lista de bullets** (3-5 itens)
3. **Título + visual único** (imagem/gráfico à direita, texto à esquerda)
4. **Título + 2 colunas** (comparação, before/after)
5. **Título + grid 2×2 ou 3×2** (cards, features)

**Se precisar de outro layout:** pare e reavalie. 90% das apresentações cabem nesses 5.

### 9.3 Slide de Conteúdo — Anatomia Padrão
```
┌─────────────────────────────────────────────────────┐
│                                                     │  ← margem sup 0.6in
│   Título (32-40pt, bold, escuro)                    │
│                                                     │
│   Subtítulo (opcional, 20pt, neutro)                │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│                                                     │
│        [Área de conteúdo - 70% do slide]            │
│                                                     │
│                                                     │
│                                                     │
├─────────────────────────────────────────────────────┤
│   Logo                14pt neutro   14pt neutro    │  ← rodapé
└─────────────────────────────────────────────────────┘
```

---

## 10. Dados e Números (Regra do "Big Number")

### 10.1 O Número-Feature
- 1 número grande, **1 palavra de contexto**
- Fonte 80-120pt, peso bold
- Cor: destaque
- **Exemplo:** "**2.4bi** usuários ativos"

### 10.2 Gráficos: Mínimo Ruído
- **Sem:** bordas, gridlines, legendas redundantes, 3D
- **Mínimo:** 1 cor de destaque, 1 cor neutra, eixos limpos
- **Título declarativo** (não "Vendas 2024" mas "Vendas cresceram 47% em 2024")

### 10.3 Tabelas
- **Sem:** linhas verticais, fundos alternados cinza, bordas grossas
- **Mínimo:** cabeçalho bold, 1 linha de destaque, zebrado opcional
- **Alinhamento:** números à direita, texto à esquerda

---

## 11. Checklist Final (Auditoria de Cada Slide)

Antes de aprovar qualquer slide, percorra esta lista:

- [ ] **1 ideia** principal clara em 3 segundos?
- [ ] **Hierarquia visual:** título > corpo > caption? (tamanho + peso)
- [ ] **Whitespace:** ≥ 30% da área do slide está vazia?
- [ ] **Cor:** ≤ 1 cor saturada, resto neutros?
- [ ] **Fonte:** ≤ 2 famílias, ≥ 14pt em tudo?
- [ ] **Alinhamento:** consistente (esquerda ou centro)?
- [ ] **Imagem** (se houver): reforça a mensagem, não decora?
- [ ] **Animação** (se houver): ensina, não decora?
- [ ] **Slide master:** mesmo rodapé, mesma fonte, mesma cor?
- [ ] **Total slides:** 10-15 para 20min? (1 slide/min em média)

---

## 12. Referências Canônicas

| Obra | Autor(es) | Ano | Contribuição Principal |
|------|-----------|-----|------------------------|
| *Presentation Zen* | Garr Reynolds | 2008 (rev. 2011) | Restrição, simplicidade, design japonês minimalista |
| *Slide:ology* | Nancy Duarte | 2008 | Design de slides como arte, hierarquia visual, sinal vs. ruído |
| *Resonate* | Nancy Duarte | 2010 | Estrutura narrativa "What Is → What Could Be" |
| *Made to Stick* | Chip & Dan Heath | 2007 | SUCCESs: Simple, Unexpected, Concrete, Credible, Emotional, Stories |
| *The Non-Designer's Design Book* | Robin Williams | 2014 | Contraste, repetição, alinhamento, proximidade (CRAP) |

**Regras CRAP (Williams):**
- **Contraste:** elementos diferentes devem ser VISUALMENTE diferentes
- **Repetição:** elementos iguais devem ser VISUALMENTE iguais
- **Alinhamento:** cada elemento deve ter conexão visual com outro
- **Proximidade:** elementos relacionados devem estar próximos

---

## 13. Aplicação em python-pptx

| Princípio | Implementação |
|-----------|---------------|
| Fonte única | `font.name = 'Montserrat'` em todos os runs |
| Hierarquia | `font.size = Pt(54)` título, `Pt(20)` corpo, `Pt(12)` rodapé |
| Cor destaque | `font.color.rgb = RGBColor(0xF5, 0x9E, 0x0B)` em 1 elemento |
| Margem | `left = Inches(0.6)`, `top = Inches(0.6)` em todo textbox |
| Whitespace | `width = Inches(12)`, `height = Inches(6)` para área de conteúdo (não encher) |
| Sem sombra | Não aplicar `shadow` |
| Sem 3D | Não usar `bevel`, `extrusion` |
| Fade animation | `slide.animations.add_entrance(preset='fade', shape, trigger=ON_CLICK)` |
| Slide master | Usar `slide_layouts` (mesma família de layouts) |

---

## 14. Aplicação por Tema (sob demanda)

Este documento é **agnóstico de tema**. As regras acima se aplicam a qualquer apresentação profissional, independentemente do assunto.

Para cada projeto novo, criar um arquivo `theme.toml` (ou similar) com as decisões de tema. Estrutura sugerida:

```toml
[theme]
name = "Sistema Solar"           # Nome do tema
tone = "cosmos"                  # cosmos, corporate, minimal, bold, etc.

[colors]
background = "#0B1020"           # Cor de fundo
text_primary = "#F8FAFC"         # Texto principal
text_secondary = "#94A3B8"       # Texto secundário / rodapé
accent = "#F59E0B"               # Cor de destaque (≤ 10% do slide)
accent_secondary = "#3B82F6"     # Apoio
alert = "#EF4444"                # Alerta (opcional)

[fonts]
title_family = "Montserrat"
title_weight = "Bold"
title_size = 44                  # pt
body_family = "Open Sans"
body_weight = "Regular"
body_size = 20                   # pt
caption_size = 12                # pt
min_size = 14                    # pt — mínimo absoluto

[layout]
slide_count_target = 12          # Meta de slides
aspect_ratio = "16:9"            # Padrão

[content]
images_source = "NASA Public Domain"  # Fonte de imagens
images_style = "real_photo"      # real_photo, illustration, icon
narrative = "what_is_what_could_be"   # Estrutura narrativa
```

**Exemplos de temas pré-configurados** (criar sob demanda):

| Tema | Paleta | Fontes | Tom |
|------|--------|--------|-----|
| Cosmos | azul noite + âmbar | Montserrat + Open Sans | dramático, educativo |
| Corporate | branco + azul corporativo | Inter + Inter | profissional, neutro |
| Minimal | preto + branco + 1 cor | Helvetica + Helvetica | sóbrio, elegante |
| Bold | amarelo + preto | Bebas + Roboto | enérgico, vendas |
| Nature | verde + terra + creme | Lora + Source Sans | orgânico, calmo |

Para usar: criar `themes/<nome>.toml` e referenciar na geração do PPTX.

---
