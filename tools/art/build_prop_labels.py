"""Lettered source images for the Stage 6 prop kit (Wave C).

  python tools/art/build_prop_labels.py

Writes, into the shared CC0 cache (<cache>/generated/prop_labels/, git-ignored like
every other texture source), the images blender/prop_kit.py turns into kit materials:

  stencil.png  1024x512 L   painted shipping marks for sacks, crates and kegs, 2 x 4
                           cells of 512x128 (alpha mask; worn, dry-brushed edges)
  labels.png   1024x512 RGB printed paper labels for tins, boxes and jars, 4 x 4
                           cells of 256x128 (aged paper, ruled borders, serif type)
  sign.png     1024x256 L   the hand-painted LAMBERT / FRENCH CAMP lettering of the
                           stall's canvas sign (ink mask; letters jitter like a brush)

Type: a Computer Modern-style serif (KaTeX_Main, SIL OFL, found in any local
site-packages; only rendered pixels are kept) with the project's PatrickHand as a
fallback. Seeds are fixed, so the output is reproducible.
"""
import glob
import math
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
HAND = ROOT / "assets" / "fonts" / "PatrickHand-Regular.ttf"


def cache_root() -> Path:
    for base in [ROOT, *ROOT.parents]:
        c = base / ".tools" / "cc0_cache"
        if c.exists():
            return c
    raise SystemExit("CC0 cache not found")


def serif(bold=True):
    pattern = "KaTeX_Main-Bold*.ttf" if bold else "KaTeX_Main-Regular*.ttf"
    roots = [p for p in sys.path if p.endswith("site-packages")]
    for r in roots:
        hits = glob.glob(os.path.join(r, "**", pattern), recursive=True)
        if hits:
            return sorted(hits)[0]
    return str(HAND)


def noise(w, h, scale, seed, octaves=3):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp = 1.0
    for o in range(octaves):
        s = max(2, int(scale * 2 ** o))
        small = rng.random((s * h // w + 2, s + 2))
        img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64) / 255 * amp
        amp *= .5
    out -= out.min()
    return out / max(out.max(), 1e-9)


def text_width(font, text, spacing=0):
    return sum(font.getlength(c) for c in text) + spacing * max(0, len(text) - 1)


def draw_line(img, text, font, cx, y, spacing=0, jitter=0.0, rng=None, fill=255):
    """Centred line, letter by letter (letter-spacing and a sign-writer's wobble)."""
    draw = ImageDraw.Draw(img)
    x = cx - text_width(font, text, spacing) / 2
    for c in text:
        if jitter and rng is not None and c != " ":
            # Each letter is painted on its own: small offsets, sizes and turns.
            layer = Image.new("L", (int(font.size * 2), int(font.size * 2)), 0)
            ImageDraw.Draw(layer).text((font.size * .5, font.size * .3), c, font=font, fill=fill)
            layer = layer.rotate(rng.uniform(-2.5, 2.5) * jitter, resample=Image.BICUBIC)
            img.paste(fill, (int(x - font.size * .5 + rng.uniform(-1.5, 1.5) * jitter),
                             int(y - font.size * .3 + rng.uniform(-2, 2) * jitter)), layer)
        else:
            draw.text((x, y), c, font=font, fill=fill)
        x += font.getlength(c) + spacing


def fit(path, text, width, height, spacing=0):
    size = int(height)
    while size > 8:
        f = ImageFont.truetype(path, size)
        if text_width(f, text, spacing) <= width:
            return f
        size -= 2
    return ImageFont.truetype(path, 8)


def stencil(out):
    """Painted marks: each cell holds one or two centred lines."""
    W, H, cw, ch = 1024, 512, 512, 128
    marks = [("SUPERFINE", "FLOUR"), ("", "SALT"), ("RIO", "COFFEE"), ("", "BEANS"),
             ("CUT", "NAILS 10d"), ("RIFLE", "POWDER"), ("J. L.", "FRENCH CAMP"), ("", "MESS PORK")]
    img = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(71)
    bold = serif(True)
    for k, (small, big) in enumerate(marks):
        x0, y0 = (k % 2) * cw, (k // 2) * ch
        if small:
            fs = fit(bold, small, cw * .5, ch * .28, 6)
            draw_line(img, small, fs, x0 + cw / 2, y0 + ch * .06, 6, 1.0, rng)
            fb = fit(bold, big, cw * .86, ch * .46, 8)
            draw_line(img, big, fb, x0 + cw / 2, y0 + ch * .40, 8, 1.0, rng)
        else:
            fb = fit(bold, big, cw * .8, ch * .62, 10)
            draw_line(img, big, fb, x0 + cw / 2, y0 + ch * .12, 10, 1.0, rng)
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float64) / 255
    # Dry brush and wear: the stencil paint is patchy and fades toward cell edges.
    wear = noise(W, H, 40, 72) * .55 + noise(W, H, 6, 73) * .45
    a = np.clip(a * (.55 + .75 * wear), 0, 1)
    Image.fromarray((a * 255).astype(np.uint8)).save(out / "stencil.png")


LABELS = [
    ("FINEST", "TEA", "Canton"), ("SPERM", "CANDLES", "Six to the lb."), ("FAMILY", "SOAP", "Bar"),
    ("CAVENDISH", "TOBACCO", "Plug"), ("FRENCH", "SARDINES", "in Oil"), ("FRESH", "OYSTERS", "Hermetically Sealed"),
    ("LUCIFER", "MATCHES", "Warranted"), ("GROUND", "PEPPER", "Pure"), ("BEST", "SALERATUS", "1 lb."),
    ("PERCUSSION", "CAPS", "Waterproof"), ("DURHAM", "MUSTARD", "Superfine"), ("VANILLA", "CHOCOLATE", "No. 1"),
    ("LEAF", "LARD", "Kettle Rendered"), ("PICKLED", "ONIONS", "Quart"), ("GINGER", "SNAPS", "Biscuit"),
    ("GUN", "FLINTS", "Doz."),
]
PAPERS = [(.86, .80, .64), (.80, .84, .82), (.88, .82, .58), (.84, .72, .62), (.78, .80, .86), (.90, .86, .74),
          (.72, .64, .50), (.86, .78, .70)]
INKS = [(.10, .07, .05), (.42, .08, .06), (.08, .12, .30), (.10, .22, .10)]


def labels(out):
    W, H, cw, ch = 1024, 512, 256, 128
    rng = np.random.default_rng(81)
    img = Image.new("RGB", (W, H), (210, 200, 170))
    draw = ImageDraw.Draw(img)
    bold, regular = serif(True), serif(False)
    for k, (top, main, bottom) in enumerate(LABELS):
        x0, y0 = (k % 4) * cw, (k // 4) * ch
        paper = tuple(int(255 * c) for c in PAPERS[k % len(PAPERS)])
        ink = tuple(int(255 * c) for c in INKS[(k * 3) % len(INKS)])
        draw.rectangle([x0, y0, x0 + cw - 1, y0 + ch - 1], fill=paper)
        draw.rectangle([x0 + 6, y0 + 6, x0 + cw - 7, y0 + ch - 7], outline=ink, width=3)
        draw.rectangle([x0 + 12, y0 + 12, x0 + cw - 13, y0 + ch - 13], outline=ink, width=1)
        ft = fit(regular, top, cw * .6, ch * .16, 3)
        draw_line(img, top, ft, x0 + cw / 2, y0 + 17, 3, fill=ink)
        fm = fit(bold, main, cw * .8, ch * .36, 2)
        draw_line(img, main, fm, x0 + cw / 2, y0 + ch * .33, 2, fill=ink)
        fb = fit(regular, bottom, cw * .7, ch * .14, 1)
        draw_line(img, bottom, fb, x0 + cw / 2, y0 + ch * .73, 1, fill=ink)
        for s in (-1, 1):  # printer's rules either side of the small lines
            draw.line([x0 + cw / 2 + s * cw * .33, y0 + ch * .22, x0 + cw / 2 + s * cw * .42, y0 + ch * .22], fill=ink, width=1)
    a = np.asarray(img, dtype=np.float64) / 255
    fox = noise(W, H, 10, 82)
    fade = noise(W, H, 3, 83)
    a = a * (.9 + .1 * fade)[..., None]
    stain = np.clip((fox - .62) * 3, 0, 1)[..., None]
    a = a * (1 - stain * .35) + np.array([.55, .40, .22]) * stain * .35
    grain = np.random.default_rng(84).normal(0, .02, a.shape[:2])[..., None]
    a = np.clip(a + grain, 0, 1)
    Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.5)).save(out / "labels.png")


def sign(out):
    W, H = 1024, 256
    img = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(91)
    bold = serif(True)
    big = fit(bold, "LAMBERT", W * .62, H * .5, 22)
    draw_line(img, "LAMBERT", big, W / 2, H * .08, 22, 1.4, rng)
    small = fit(bold, "FRENCH CAMP", W * .5, H * .22, 12)
    draw_line(img, "FRENCH CAMP", small, W / 2, H * .66, 12, 1.4, rng)
    for s in (-1, 1):  # painted rules and lozenges either side of the second line
        y = H * .77
        draw.line([W / 2 + s * W * .28, y, W / 2 + s * W * .43, y], fill=255, width=5)
        x = W / 2 + s * W * .455
        draw.polygon([(x - 9, y), (x, y - 9), (x + 9, y), (x, y + 9)], fill=255)
    draw.rectangle([18, 14, W - 19, H - 15], outline=255, width=6)
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float64) / 255
    # Brush streaks along the strokes' length and a sun-faded, flaking coat.
    streak = noise(W, H, 90, 92, 2)
    flake = np.clip((noise(W, H, 12, 93) - .2) * 2.5, 0, 1)
    a = np.clip(a * (.62 + .38 * streak) * (.45 + .55 * flake), 0, 1)
    Image.fromarray((a * 255).astype(np.uint8)).save(out / "sign.png")


def chalk(out):
    """Ghosts of wiped-off sums on the counter slate: faint cursive lines and smears."""
    W = 512
    img = Image.new("L", (W, W), 0)
    rng = np.random.default_rng(101)
    hand = str(ROOT / "assets" / "fonts" / "Cedarville-Cursive.ttf")
    f = ImageFont.truetype(hand, 30)
    words = ["Flour 4 lb", "Coffee 1", "Pork 2 lb", "Beans", "Total", "Rec'd", "dust 1 oz", "Salt", "Hooks 6", "Line"]
    for row in range(12):
        txt = " ".join(rng.choice(words, 2)) + "  $" + "%d.%02d" % (rng.integers(1, 30), rng.integers(0, 99))
        draw_line(img, txt, f, W * rng.uniform(.4, .6), 12 + row * 41, 0, fill=int(rng.uniform(70, 150)))
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(2.2)), dtype=np.float64) / 255
    smear = noise(W, W, 4, 102) * noise(W, W, 9, 103)
    a = np.clip(a * .55 + smear * .35, 0, 1)
    Image.fromarray((a * 255).astype(np.uint8)).save(out / "chalk.png")


def main():
    out = cache_root() / "generated" / "prop_labels"
    out.mkdir(parents=True, exist_ok=True)
    stencil(out)
    labels(out)
    sign(out)
    chalk(out)
    print("WROTE", out, "serif:", Path(serif(True)).name)


if __name__ == "__main__":
    main()
