# cars_industry — Pipeline de Apresentação Setorial

Pipeline para gerar a apresentação **"Indústria Automobilística Global"** a partir de código Python, com preview HTML/PNG para revisão visual.

## Estrutura

```
tools/cars_industry/
├── README.md             # Este arquivo
├── build_cars_pptx.py    # Gera o .pptx final (python-pptx)
├── render_html.py        # Gera HTML dos slides para preview
├── preview.py            # Converte HTML → PNG via Playwright
├── themes/
│   ├── cars_industry.toml  # Paleta, fontes, layout
│   └── outline_cars.md     # Roteiro dos 12 slides
├── output/               # Gerado — PPTX final (gitignored)
└── preview/              # Gerado — HTML/PNG de preview (gitignored)
```

## Pipeline (ordem de execução)

```
1. render_html.py    → preview/cars/slide-*.html
2. preview.py        → preview/cars/slide-*.png
3. build_cars_pptx.py → output/cars_industry.pptx
```

### 1. Renderizar HTML

```bash
cd tools/cars_industry
python render_html.py
```

Gera 5 arquivos HTML em `preview/cars/`, um por slide (cover, panorama, top OEM, regiões, EV timeline).

### 2. Converter para PNG (preview visual)

Requer Playwright instalado:

```bash
pip install playwright
playwright install chromium
python preview.py
```

Gera os PNGs correspondentes. Use para revisar o visual antes de gerar o PPTX final.

Argumento opcional: `python preview.py cover` renderiza só o slide cujo nome contém "cover".

### 3. Gerar PPTX final

```bash
python build_cars_pptx.py
```

Gera `output/cars_industry.pptx` aplicando o tema de `themes/cars_industry.toml` e o conteúdo de cada slide (5 slides implementados; outline prevê 12).

## Customização

- **Cores/fontes/layout**: edite `themes/cars_industry.toml`
- **Conteúdo dos slides**: edite os dados nas funções `build_*_def()` em `render_html.py` (preview) e nas funções `slide_*()` em `build_cars_pptx.py` (PPTX)
- **Adicionar slides**: criar nova função `build_*_def()` em `render_html.py` + `slide_*()` em `build_cars_pptx.py` + adicionar à lista em `main()`

## Saída

- `output/cars_industry.pptx` (~38 KB) — apresentação final
- `preview/cars/slide-*.html` — HTML intermediário (~260-290 KB cada)
- `preview/cars/slide-*.png` — previews visuais (~100-150 KB cada)

## Dependências

```bash
pip install python-pptx lxml playwright
playwright install chromium
```

## Notas

- `output/` e `preview/` são **gitignored** — outputs são regeneráveis
- O tema usa fontes **Inter** (com fallback para system fonts)
- Slides são 16:9 (13.333 × 7.5 inches)
