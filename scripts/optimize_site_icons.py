#!/usr/bin/env python3
"""Make lightweight display-only WebP derivatives of original Frogdadday PNG icons.

Source PNG files are NEVER edited. The website's rendered <img> elements
point to WebP derivatives while original PNGs remain for branding,
social previews, and future regeneration.

Requires: pip install Pillow
"""
from __future__ import annotations

import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
OUTPUT = ASSETS / "optimized"
HTML_FILES = [ROOT / "index.html", ROOT / "frog-pond.html", ROOT / "404.html"]
HTML_FILES += sorted((ROOT / "apps").glob("*.html"))

# Match only browser-rendered <img src="...png"> references. Don't rewrite
# og:image, structured data, CSS, SVG, or private app assets.
IMG_SOURCE = re.compile(
    r'(<img\b[^>]*?\bsrc=")((?:\.\./|/)?assets/([a-zA-Z0-9_-]+)\.png)(")',
    re.IGNORECASE | re.DOTALL,
)

def build_webps() -> dict[str, tuple[int, int]]:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    products = {}
    for original in sorted(ASSETS.glob("*.png")):
        target = OUTPUT / f"{original.stem}.webp"
        with Image.open(original) as image:
            # Display dimensions: cards <= 98 CSS px, detail hero <= 190,
            # big Frogdadday logo <= 360. Keep >2x resolution for DPR screens.
            limit = 768 if original.stem == "frogdadday-logo-transparent" else 512
            image = image.convert("RGBA")
            image.thumbnail((limit, limit), Image.Resampling.LANCZOS)
            image.save(target, format="WEBP", lossless=True, method=6, exact=True)
        old_bytes, new_bytes = original.stat().st_size, target.stat().st_size
        if new_bytes >= old_bytes:
            # Never transfer more bytes than the original just to say "WebP".
            target.unlink()
            print(f"KEEP PNG {original.name}: derivative is not smaller")
            continue
        products[original.stem] = (old_bytes, new_bytes)
        print(f"WEBP {target.name}: {old_bytes:,} -> {new_bytes:,} bytes")
    return products

def update_markup(images: dict[str, tuple[int, int]]) -> None:
    for path in HTML_FILES:
        if not path.exists():
            continue
        source = path.read_text(encoding="utf-8")
        def replace(match: re.Match[str]) -> str:
            prefix, src, stem, quote = match.groups()
            if stem not in images:
                return match.group(0)
            # Preserve relative paths; never change alt text or <img> layout.
            return f'{prefix}{src.replace("assets/", "assets/optimized/", 1)[:-4]}.webp{quote}'
        updated = IMG_SOURCE.sub(replace, source)
        if updated != source:
            path.write_text(updated, encoding="utf-8")
            print(f"HTML {path.relative_to(ROOT)}: optimized visible icon sources")

def main() -> None:
    images = build_webps()
    update_markup(images)
    total_before = sum(x[0] for x in images.values())
    total_after = sum(x[1] for x in images.values())
    print(f"Transfer-ready icons: {len(images)}. Original bytes {total_before:,}, optimized bytes {total_after:,}. Original PNGs unchanged.")

if __name__ == "__main__":
    main()
