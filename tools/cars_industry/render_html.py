"""render_html.py — Constrói HTML fiel ao design para preview Playwright.

Por que HTML e não só PPTX:
- Sem LibreOffice no sistema
- Playwright renderiza HTML idêntico ao design proposto
- Iteração rápida: edita HTML, vê resultado, ajusta PPTX correspondente
- Permite revisão visual ANTES de salvar PPTX
"""
from pathlib import Path
import json
import tomllib

ROOT = Path(__file__).parent
PREVIEW_DIR = ROOT / "preview" / "cars"
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)


def load_theme() -> dict:
    with open(ROOT / "themes" / "cars_industry.toml", "rb") as f:
        return tomllib.load(f)


def render_slide_html(theme: dict, slide_def: dict, total: int) -> str:
    """Renderiza HTML para um slide. slide_def vem de slides/cars/*.json"""
    fs = theme["font_sizes"]
    c = theme["colors"]
    layout = theme["layout"]
    w_px = int(layout["slide_width_in"] * 96)
    h_px = int(layout["slide_height_in"] * 96)

    body_html = ""

    if slide_def["type"] == "cover":
        body_html = f"""
        <div class="accent-bar"></div>
        <div class="cover-eyebrow">{slide_def['eyebrow']}</div>
        <h1 class="cover-title">{slide_def['title']}</h1>
        <p class="cover-subtitle">{slide_def['subtitle']}</p>
        <div class="cover-divider"></div>
        <div class="cover-footer">{slide_def['footer']}</div>
        """

    elif slide_def["type"] == "panorama":
        metrics_html = ""
        col_w = 4.0
        gap = 0.13
        total_w_in = col_w * 3 + gap * 2
        start_x_in = (layout["slide_width_in"] - total_w_in) / 2
        for i, m in enumerate(slide_def["metrics"]):
            x_in = start_x_in + i * (col_w + gap)
            metrics_html += f"""
            <div class="metric" style="left: {x_in}in; top: 3.0in; width: {col_w}in;">
                <div class="big-number">{m['number']}</div>
                <div class="big-label">{m['label']}</div>
                <div class="big-context">{m['context']}</div>
                <div class="big-source">Fonte: {m['source']}</div>
            </div>
            """
        body_html = f"""
        <div class="eyebrow">{slide_def['eyebrow']}</div>
        <h1 class="slide-title">{slide_def['title']}</h1>
        <p class="slide-subtitle">{slide_def['subtitle']}</p>
        {metrics_html}
        """

    elif slide_def["type"] == "table":
        rows_html = ""
        for i, row in enumerate(slide_def["rows"]):
            is_h = row.get("highlight", False)
            cls = "table-row highlight" if is_h else "table-row"
            cells = "".join(
                f'<td class="{"right" if j > 1 else "left"}">{v}</td>'
                for j, v in enumerate(row["values"])
            )
            rows_html += f'<tr class="{cls}">{cells}</tr>'
        body_html = f"""
        <div class="eyebrow">{slide_def['eyebrow']}</div>
        <h1 class="slide-title">{slide_def['title']}</h1>
        <p class="slide-subtitle">{slide_def['subtitle']}</p>
        <table class="data-table">
            <thead>
                <tr>{''.join(f'<th class="{"right" if j > 1 else "left"}">{h}</th>' for j, h in enumerate(slide_def['headers']))}</tr>
            </thead>
            <tbody>{rows_html}</tbody>
        </table>
        <div class="caption-source">{slide_def['source']}</div>
        """

    elif slide_def["type"] == "bars":
        rows_html = ""
        bar_max_w = 6.5
        max_share = max(r["share"] for r in slide_def["regions"])
        for r in slide_def["regions"]:
            w = bar_max_w * (r["share"] / max_share)
            cls = "bar-row highlight" if r.get("highlight") else "bar-row"
            bar_color = c["accent"] if r.get("highlight") else c["text_muted"]
            rows_html += f"""
            <div class="{cls}">
                <div class="bar-label">{r['name']}</div>
                <div class="bar-track" style="left: 4.0in; width: {w}in; background: {bar_color};"></div>
                <div class="bar-value">{r['value']}  ({r['share']}%)</div>
            </div>
            """
        body_html = f"""
        <div class="eyebrow">{slide_def['eyebrow']}</div>
        <h1 class="slide-title">{slide_def['title']}</h1>
        <p class="slide-subtitle">{slide_def['subtitle']}</p>
        <div class="bar-chart">{rows_html}</div>
        <div class="caption-source">{slide_def['source']}</div>
        """

    elif slide_def["type"] == "timeline":
        cards_html = ""
        card_w = 1.85
        card_h = 3.2
        gap = 0.1
        total_w_in = card_w * 6 + gap * 5
        start_x_in = (layout["slide_width_in"] - total_w_in) / 2
        for i, d in enumerate(slide_def["data"]):
            x_in = start_x_in + i * (card_w + gap)
            is_last = i == len(slide_def["data"]) - 1
            cls = "tl-card highlight" if is_last else "tl-card"
            growth_html = ""
            if i > 0:
                prev_pct = float(slide_def["data"][i - 1]["pct"].rstrip("%"))
                curr_pct = float(d["pct"].rstrip("%"))
                growth = ((curr_pct - prev_pct) / prev_pct) * 100
                growth_html = f'<div class="tl-growth">+{growth:.0f}% a.a.</div>'
            cards_html += f"""
            <div class="{cls}" style="left: {x_in}in; top: 3.0in; width: {card_w}in; height: {card_h}in;">
                <div class="tl-year">{d['year']}</div>
                <div class="tl-pct">{d['pct']}</div>
                {growth_html}
            </div>
            """
        body_html = f"""
        <div class="eyebrow">{slide_def['eyebrow']}</div>
        <h1 class="slide-title">{slide_def['title']}</h1>
        <p class="slide-subtitle">{slide_def['subtitle']}</p>
        <div class="tl-container">{cards_html}</div>
        <div class="caption-source">{slide_def['source']}</div>
        """

    css = f"""
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    body {{
        font-family: '{theme['fonts']['body_family']}', 'Inter', -apple-system, sans-serif;
        background: {c['background']};
        color: {c['text_primary']};
    }}
    .slide {{
        width: {w_px}px;
        height: {h_px}px;
        position: relative;
        background: {c['background']};
        overflow: hidden;
        padding: {layout['margin_y_in']}in {layout['margin_x_in']}in;
    }}
    .accent-bar {{
        position: absolute;
        left: 0; top: 0;
        width: 0.25in;
        height: 100%;
        background: {c['accent']};
    }}
    .cover-eyebrow {{
        margin-top: 0.5in;
        font-size: {fs['caption'] + 1}pt;
        font-weight: 600;
        color: {c['accent']};
        letter-spacing: 0.05em;
    }}
    .cover-title {{
        margin-top: 0.4in;
        font-size: {fs['cover_title']}pt;
        font-weight: 700;
        color: {c['text_primary']};
        line-height: 1.05;
        white-space: pre-line;
    }}
    .cover-subtitle {{
        margin-top: 0.4in;
        font-size: {fs['cover_subtitle']}pt;
        font-weight: 400;
        color: {c['text_secondary']};
        line-height: 1.3;
    }}
    .cover-divider {{
        margin-top: 0.6in;
        width: 1.5in;
        height: 2px;
        background: {c['text_primary']};
    }}
    .cover-footer {{
        margin-top: 0.15in;
        font-size: {fs['caption'] + 1}pt;
        font-weight: 500;
        color: {c['text_muted']};
    }}
    .eyebrow {{
        margin-top: 0.45in;
        font-size: {fs['caption'] + 1}pt;
        font-weight: 600;
        color: {c['accent']};
        letter-spacing: 0.05em;
    }}
    .slide-title {{
        margin-top: 0.15in;
        font-size: {fs['slide_title']}pt;
        font-weight: 700;
        color: {c['text_primary']};
        line-height: 1.1;
    }}
    .slide-subtitle {{
        margin-top: 0.15in;
        font-size: {fs['body']}pt;
        font-weight: 400;
        color: {c['text_secondary']};
    }}
    .metric {{
        position: absolute;
    }}
    .big-number {{
        font-size: {fs['big_number']}pt;
        font-weight: 700;
        color: {c['accent']};
        line-height: 1.0;
        letter-spacing: -0.02em;
    }}
    .big-label {{
        margin-top: 0.15in;
        font-size: {fs['body']}pt;
        font-weight: 600;
        color: {c['text_primary']};
    }}
    .big-context {{
        margin-top: 0.05in;
        font-size: {fs['body_small']}pt;
        font-weight: 400;
        color: {c['text_secondary']};
    }}
    .big-source {{
        margin-top: 0.05in;
        font-size: {fs['caption']}pt;
        font-weight: 400;
        color: {c['text_muted']};
    }}
    .data-table {{
        margin-top: 0.5in;
        width: 9.1in;
        margin-left: auto;
        margin-right: auto;
        border-collapse: collapse;
        font-size: 16pt;
    }}
    .data-table th {{
        text-align: left;
        font-weight: 700;
        color: {c['text_secondary']};
        font-size: 14pt;
        padding: 0.06in 0.15in;
        border-bottom: 2px solid {c['text_primary']};
    }}
    .data-table th.right, .data-table td.right {{ text-align: right; }}
    .data-table td {{
        padding: 0.05in 0.15in;
        font-weight: 400;
        color: {c['text_primary']};
        border-bottom: 1px solid {c['divider']};
    }}
    .data-table tr.highlight td {{
        color: {c['accent']};
        font-weight: 700;
    }}
    .caption-source {{
        position: absolute;
        left: 0.6in;
        bottom: 0.6in;
        font-size: {fs['caption']}pt;
        color: {c['text_muted']};
    }}
    .bar-chart {{
        position: absolute;
        left: 0.6in;
        right: 0.6in;
        top: 2.9in;
    }}
    .bar-row {{
        position: relative;
        height: 0.5in;
    }}
    .bar-row.highlight .bar-label {{
        font-weight: 700;
    }}
    .bar-label {{
        position: absolute;
        left: 0; top: 0.05in;
        width: 3.3in;
        font-size: {fs['body']}pt;
        color: {c['text_primary']};
    }}
    .bar-track {{
        position: absolute;
        top: 0.10in;
        height: 0.30in;
    }}
    .bar-value {{
        position: absolute;
        right: 0.6in;
        top: 0.05in;
        font-size: {fs['body_small']}pt;
        color: {c['text_primary']};
    }}
    .bar-row.highlight .bar-value {{
        font-weight: 700;
    }}
    .tl-container {{
        position: absolute;
        left: 0; right: 0; top: 0; height: 7.5in;
    }}
    .tl-card {{
        position: absolute;
        background: {c['surface']};
        border: 0.5pt solid {c['divider']};
        display: flex;
        flex-direction: column;
        align-items: center;
        padding-top: 0.3in;
    }}
    .tl-card.highlight {{
        background: {c['accent']};
        border: none;
    }}
    .tl-card.highlight .tl-year,
    .tl-card.highlight .tl-growth {{
        color: #FFFFFF;
    }}
    .tl-card.highlight .tl-pct {{
        color: #FFFFFF;
    }}
    .tl-year {{
        font-size: {fs['body']}pt;
        font-weight: 600;
        color: {c['text_secondary']};
    }}
    .tl-pct {{
        font-size: 44pt;
        font-weight: 700;
        color: {c['text_primary']};
        margin-top: 0.5in;
        line-height: 1;
    }}
    .tl-growth {{
        margin-top: auto;
        padding-bottom: 0.4in;
        font-size: {fs['caption']}pt;
        font-weight: 600;
        color: {c['text_secondary']};
    }}
    .footer-bar {{
        position: absolute;
        bottom: 0.35in;
        left: {layout['margin_x_in']}in;
        right: {layout['margin_x_in']}in;
        display: flex;
        justify-content: space-between;
        font-size: {fs['footer']}pt;
        color: {c['text_muted']};
    }}
    """

    footer_html = f"""
    <div class="footer-bar">
        <span>{theme['footer']['left']}</span>
        <span>{theme['footer']['right_format'].format(n=slide_def.get('n', 1), total=total)}</span>
    </div>
    """

    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<style>{css}</style>
</head>
<body>
<div class="slide">
{body_html}
{footer_html}
</div>
</body>
</html>"""


def build_cover_def() -> dict:
    return {
        "type": "cover",
        "n": 1,
        "eyebrow": "RELATÓRIO SETORIAL  ·  2024-2025",
        "title": "Indústria\nAutomobilística\nGlobal",
        "subtitle": "Panorama de mercado, revolução elétrica e geopolítica",
        "footer": "OpenCode Studio  ·  Análise Setorial",
    }


def build_panorama_def() -> dict:
    return {
        "type": "panorama",
        "n": 2,
        "eyebrow": "PANORAMA  ·  NÚMEROS-CHAVE",
        "title": "A indústria em três números",
        "subtitle": "Produção, frota ativa e valor de mercado em 2024",
        "metrics": [
            {"number": "90M", "label": "veículos produzidos", "context": "por ano no mundo", "source": "OICA / ACEA"},
            {"number": "1.5bi", "label": "carros em circulação", "context": "1 para cada 5 pessoas", "source": "Hedges & Company"},
            {"number": "3T", "label": "em receita (US$)", "context": "setor + cadeia", "source": "BloombergNEF"},
        ],
    }


def build_top_oem_def() -> dict:
    rows = [
        {"values": ["1", "Toyota",       "10.5",  "11.7%"]},
        {"values": ["2", "Volkswagen",   " 9.0",  "10.0%"]},
        {"values": ["3", "Hyundai-Kia",  " 7.2",  " 8.0%"]},
        {"values": ["4", "Stellantis",   " 6.0",  " 6.7%"]},
        {"values": ["5", "GM",           " 5.9",  " 6.6%"]},
        {"values": ["6", "BYD",          " 4.3",  " 4.8%"], "highlight": True},
        {"values": ["7", "Honda",        " 3.8",  " 4.2%"]},
        {"values": ["8", "Ford",         " 3.5",  " 3.9%"]},
    ]
    return {
        "type": "table",
        "n": 3,
        "eyebrow": "FABRICANTES  ·  RANKING 2024",
        "title": "Os 8 maiores fabricantes globais",
        "subtitle": "Toyota lidera; BYD cresce 41% e ultrapassa Honda em vendas",
        "headers": ["#", "Fabricante", "Vendas (M)", "Share"],
        "rows": rows,
        "source": "Fonte: Focus2Move / OICA 2024 (estimativa anual)",
    }


def build_regiao_def() -> dict:
    return {
        "type": "bars",
        "n": 4,
        "eyebrow": "GEOGRAFIA  ·  PRODUÇÃO GLOBAL",
        "title": "China fabrica 1 em cada 3 carros do mundo",
        "subtitle": "Produção de veículos por região, 2024 (milhões de unidades / share global)",
        "regions": [
            {"name": "China",               "value": "29.0M", "share": 32, "highlight": True},
            {"name": "Europa",              "value": "17.0M", "share": 19},
            {"name": "América do Norte",    "value": "15.5M", "share": 17},
            {"name": "Japão + Coreia",      "value": "12.0M", "share": 13},
            {"name": "Índia",               "value": " 5.5M", "share":  6},
            {"name": "Brasil + Mercosul",   "value": " 4.0M", "share":  4},
            {"name": "Outros",              "value": " 7.0M", "share":  9},
        ],
        "source": "Fonte: OICA 2024 — produção total estimada em 90M unidades",
    }


def build_ev_def() -> dict:
    return {
        "type": "timeline",
        "n": 5,
        "eyebrow": "REVOLUÇÃO ELÉTRICA  ·  EV NAS VENDAS GLOBAIS",
        "title": "EVs saltam de 2% para 22% em 6 anos",
        "subtitle": "Participação de EVs (BEV + PHEV) nas vendas globais de carros novos",
        "data": [
            {"year": 2019, "pct": "2.5%"},
            {"year": 2020, "pct": "4.2%"},
            {"year": 2021, "pct": "8.9%"},
            {"year": 2022, "pct": "13.7%"},
            {"year": 2023, "pct": "17.5%"},
            {"year": 2024, "pct": "22.0%"},
        ],
        "source": "Fonte: IEA Global EV Outlook 2024 / BloombergNEF",
    }


def main():
    theme = load_theme()
    slides = [
        (build_cover_def(),     "slide-01-cover.html"),
        (build_panorama_def(),  "slide-02-panorama.html"),
        (build_top_oem_def(),   "slide-03-top-oem.html"),
        (build_regiao_def(),    "slide-04-regiao.html"),
        (build_ev_def(),        "slide-05-ev-growth.html"),
    ]
    for slide_def, fname in slides:
        html = render_slide_html(theme, slide_def, total=12)
        out = PREVIEW_DIR / fname
        out.write_text(html, encoding="utf-8")
        print(f"OK: {out}")


if __name__ == "__main__":
    main()
