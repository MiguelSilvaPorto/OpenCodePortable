"""preview.py — Renderiza HTML dos slides para PNG via Playwright.

Uso: python preview.py [slide_id]
Saída: preview/cars/slide-XX-name.png
"""
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright
import tomllib

ROOT = Path(__file__).parent
PREVIEW_DIR = ROOT / "preview" / "cars"


def get_slide_dimensions(theme: dict) -> dict:
    layout = theme["layout"]
    return {
        "width": int(layout["slide_width_in"] * 96),
        "height": int(layout["slide_height_in"] * 96),
    }


def render_html_to_png(html_path: Path, out_path: Path, dims: dict):
    with sync_playwright() as p:
        browser = p.chromium.launch()
        context = browser.new_context(
            viewport={"width": dims["width"], "height": dims["height"]},
            device_scale_factor=2,
        )
        page = context.new_page()
        page.goto(f"file:///{html_path.as_posix()}")
        page.wait_for_load_state("networkidle")
        page.screenshot(path=str(out_path), full_page=False, clip={
            "x": 0, "y": 0, "width": dims["width"], "height": dims["height"]
        })
        browser.close()


def main():
    with open(ROOT / "themes" / "cars_industry.toml", "rb") as f:
        theme = tomllib.load(f)
    dims = get_slide_dimensions(theme)

    htmls = sorted(PREVIEW_DIR.glob("slide-*.html"))
    if not htmls:
        print("Nenhum HTML em preview/cars/. Rode render_html.py primeiro.")
        return

    target = sys.argv[1] if len(sys.argv) > 1 else None
    for html_path in htmls:
        if target and target not in html_path.name:
            continue
        png_path = html_path.with_suffix(".png")
        print(f"Renderizando {html_path.name} -> {png_path.name}")
        render_html_to_png(html_path, png_path, dims)
        print(f"  OK: {png_path.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()
