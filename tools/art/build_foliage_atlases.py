"""Foliage atlases and the bark texture array for Stage 4 (vegetation).

  python tools/art/build_foliage_atlases.py

Writes, deterministically (explicit seeds, no timestamps):
  assets/textures/foliage_<species>_albedo.png  2048 px, 2x2 tiles of 1024: four sprays per
      tree species. tools/art/build_trees.mjs maps each leaf card to one tile.
  assets/textures/foliage_understory_albedo.png 2048 px: grass tufts, fern fronds and shrub
      sprays; regions listed in tools/art/foliage_regions.json for the mesh builder.
  assets/textures/bark_albedo.png, bark_normal.png  512 x 3072: six 512 px layers stacked
      vertically, imported as a Texture2DArray (layer order in BARK_LAYERS).

Sources (CC0, Poly Haven, fetched with tools/art/fetch_cc0.py into the shared cache):
  grass_medium_01 2k and fern_02 2k (with --maps Alpha): tuft renders and fronds;
  shrub_02 1k (--maps Alpha): lanceolate leaves, stamped onto drawn twigs and used as photo
  detail inside drawn oak outlines; pine_bark, japanese_cedar_bark, bark_willow,
  bark_brown_02, jolcham_oak_bark_01 (1k, --maps Diffuse,nor_gl).
Needles, scale sprays, oak leaf outlines and twigs are drawn procedurally.
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))
import manifest  # noqa: E402

CACHE = manifest.cache_root() / "polyhaven"
OUT = REPO / "assets" / "textures"
WORK = 2048  # drawing scale; compositions are cropped and fitted into their tile
OFF = WORK // 2  # canvas margin: leaves past the nominal frame are never clipped


def ph(asset: str, res: str, name: str) -> Path:
    path = CACHE / asset / res / name
    if not path.exists():
        path = CACHE / asset / res / "textures" / name
    if not path.exists():
        raise SystemExit("missing %s (fetch it: python tools/art/fetch_cc0.py polyhaven %s %s --maps Alpha)" % (path, asset, res))
    return path


def rgba(asset: str, res: str) -> Image.Image:
    d = Image.open(ph(asset, res, "%s_diff_%s.jpg" % (asset, res))).convert("RGB")
    a = Image.open(ph(asset, res, "%s_alpha_%s.jpg" % (asset, res))).convert("L")
    d.putalpha(a)
    return d


def save_png(img: Image.Image, path: Path) -> None:
    """256-colour palette PNG (with alpha where present), as blender/optimize_textures.py
    stores the terrain sets: about a third of the bytes, dithered so foliage keeps detail."""
    path.parent.mkdir(parents=True, exist_ok=True)
    method = Image.Quantize.FASTOCTREE if img.mode == "RGBA" else Image.Quantize.MEDIANCUT
    img = img.quantize(colors=256, method=method, dither=Image.Dither.FLOYDSTEINBERG)
    img.save(path, optimize=True)  # PIL writes no time chunks: byte-stable output
    print("wrote", path.relative_to(REPO), img.size, "%.2f MB" % (path.stat().st_size / 1e6))


def bleed(img: Image.Image, rgb) -> Image.Image:
    """Transparent texels take the given colour so mipmaps do not darken edges."""
    a = np.asarray(img).astype(np.float32)
    alpha = a[..., 3:4] / 255.0
    a[..., :3] = a[..., :3] * alpha + np.array(rgb, np.float32) * (1 - alpha)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def recolor(leaf: Image.Image, target, contrast=1.0, keep=0.15) -> Image.Image:
    """Keep the photo's luminance detail, move its colour to `target` (sRGB 0-255)."""
    a = np.asarray(leaf).astype(np.float32)
    rgb = a[..., :3]
    lum = rgb @ np.array([.2126, .7152, .0722], np.float32)
    m = lum[a[..., 3] > 128].mean() if (a[..., 3] > 128).any() else 128.0
    rel = np.clip((lum / max(m, 1.0) - 1.0) * contrast + 1.0, 0.0, 3.0)
    out = np.array(target, np.float32) * rel[..., None]
    out = out * (1 - keep) + rgb * (np.array(target, np.float32) / max(m, 1.0)) * keep
    a[..., :3] = out
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def jitter(rgb, rng, amount=0.12, hue=0.06):
    k = 1 + rng.uniform(-amount, amount)
    r, g, b = rgb
    s = rng.uniform(-hue, hue)
    return (r * k * (1 + s), g * k, b * k * (1 - s))


def shaded(rgb, k):
    return tuple(int(max(0, min(255, v * k))) for v in rgb) + (255,)


# ---------------------------------------------------------------- photo leaf sources

def willow_leaves() -> list[Image.Image]:
    """Four clean lanceolate leaves from shrub_02 (tip up, petiole down)."""
    src = rgba("shrub_02", "1k")
    boxes = [(170, 295, 318, 885), (525, 322, 640, 872), (695, 415, 815, 845), (845, 368, 970, 840)]
    leaves = []
    for box in boxes:
        a = np.asarray(src.crop(box)).copy()
        a[..., 3] = np.where(a[..., 3] > 40, a[..., 3], 0)
        leaves.append(Image.fromarray(a, "RGBA"))
    return leaves


def photo_detail(width: int, height: int, rng: random.Random, leaves) -> np.ndarray:
    """A leaf photo stretched over a box: luminance detail for a drawn outline."""
    leaf = leaves[rng.randrange(len(leaves))].resize((width, height), Image.BICUBIC)
    a = np.asarray(leaf).astype(np.float32)
    lum = a[..., :3] @ np.array([.2126, .7152, .0722], np.float32)
    inside = a[..., 3] > 128
    m = lum[inside].mean() if inside.any() else 128.0
    lum = np.where(inside, lum / m, 1.0)
    return np.clip(lum, 0.6, 1.4) ** 0.6


# ---------------------------------------------------------------- drawing helpers

def stamp(canvas: Image.Image, leaf: Image.Image, at_point, angle_deg: float, length: float, width_scale=1.0):
    """Paste a tip-up leaf so its petiole sits at `at_point`, rotated to `angle_deg` (0 = up)."""
    w, h = leaf.size
    scale = length / h
    leaf = leaf.resize((max(2, int(w * scale * width_scale)), max(2, int(h * scale))), Image.LANCZOS)
    w, h = leaf.size
    pad = Image.new("RGBA", (2 * h + 4, 2 * h + 4), (0, 0, 0, 0))
    pad.paste(leaf, (h + 2 - w // 2, 2))  # petiole at the pad centre
    rot = pad.rotate(-angle_deg, resample=Image.BICUBIC, center=(h + 2, h + 2))
    canvas.alpha_composite(rot, (int(at_point[0] - h - 2), int(at_point[1] - h - 2)))


def bezier(p0, p1, p2, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / (n - 1) for i in range(n))]


def twig(draw: ImageDraw.ImageDraw, pts, w0, w1, color):
    for i in range(len(pts) - 1):
        t = i / max(1, len(pts) - 2)
        draw.line([pts[i], pts[i + 1]], fill=color, width=max(1, int(w0 + (w1 - w0) * t)))


def compose(draw_fn, w: int, h: int, seed: int) -> Image.Image:
    """Draw on a large canvas (stem base near the bottom centre), then fit the drawn
    extent into a w x h tile with a small margin: no clipped leaves, full use of the tile."""
    rng = random.Random(seed)
    c = Image.new("RGBA", (WORK * 2, WORK * 2), (0, 0, 0, 0))
    draw_fn(c, ImageDraw.Draw(c), rng, WORK)
    crop = c.crop(c.getbbox() or (0, 0, WORK * 2, WORK * 2))
    m = 0.02
    s = min(w * (1 - 2 * m) / crop.width, h * (1 - m) / crop.height)
    im = crop.resize((max(1, int(crop.width * s)), max(1, int(crop.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(im, ((w - im.width) // 2, h - im.height - 1))
    return out


def stem(rng, S, curve=0.15, top=0.12):
    base = (OFF + S * 0.5, OFF + S * 0.97)
    tip = (OFF + S * rng.uniform(0.42, 0.58), OFF + S * top)
    return bezier(base, (OFF + S * (0.5 + rng.uniform(-curve, curve)), OFF + S * (0.97 + top) / 2), tip, 40)


def at(path, t):
    return path[min(len(path) - 1, max(0, int(t * (len(path) - 1))))]


def heading(path, t):
    i = min(len(path) - 2, max(0, int(t * (len(path) - 1))))
    (x0, y0), (x1, y1) = path[i], path[i + 1]
    return math.degrees(math.atan2(x1 - x0, -(y1 - y0) + 1e-9))


# ---------------------------------------------------------------- tree sprays

def oak_outline(length: float, width: float, rng: random.Random):
    """Deeply lobed, bristle-tipped black-oak leaf; petiole at origin, tip at -y."""
    lobes = rng.choice([3, 3, 4])
    pts_r = []
    for i in range(0, 121):
        s = i / 120
        env = math.sin(math.pi * min(1, s ** 0.85)) ** 0.8
        lobe = 0.5 + 0.5 * math.cos(2 * math.pi * (s * lobes - 0.15))
        depth = 0.38 + 0.62 * lobe ** 1.3
        w = width * env * depth * (0.25 if s < 0.1 else 1)
        sweep = w * 0.3  # lobes point toward the tip
        pts_r.append((w, -(s * length + sweep)))
        if lobe > 0.99 and 0.15 < s < 0.95:  # bristle
            pts_r.append((w + width * 0.04, -(s * length + sweep + width * 0.06)))
    pts_l = [(-x * rng.uniform(0.94, 1.04), y) for x, y in pts_r]
    return pts_r + [(0, -length * 1.02)] + pts_l[::-1]


def oak_leaf(c, d, rng, origin, ang, length, color, shade, leaves):
    shape = oak_outline(length, length * rng.uniform(0.5, 0.62), rng)
    rad = math.radians(ang)
    ca, sa = math.cos(rad), math.sin(rad)
    poly = [(origin[0] + x * ca - y * sa, origin[1] + x * sa + y * ca) for x, y in shape]
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    x0, y0, x1, y1 = int(min(xs)) - 2, int(min(ys)) - 2, int(max(xs)) + 3, int(max(ys)) + 3
    mask = Image.new("L", (x1 - x0, y1 - y0), 0)
    ImageDraw.Draw(mask).polygon([(x - x0, y - y0) for x, y in poly], fill=255)
    detail = photo_detail(x1 - x0, y1 - y0, rng, leaves)
    rgbv = np.array(color, np.float32)[None, None, :] * (detail * shade)[..., None]
    layer = np.dstack([rgbv.clip(0, 255), np.asarray(mask, np.float32)]).astype(np.uint8)
    c.alpha_composite(Image.fromarray(layer, "RGBA"), (x0, y0))
    tip = (origin[0] + 0.9 * length * sa, origin[1] - 0.9 * length * ca)
    d.line([origin, tip], fill=shaded(color, shade * 1.3), width=2)


def oak_tile(seed: int, leaves) -> Image.Image:
    def draw(c, d, rng, S):
        main = stem(rng, S, 0.12, 0.3)
        twig(d, main, 12, 4, (86, 72, 58, 255))
        shoots = [(main[-1], heading(main, 1.0))]
        n = rng.randint(9, 11)
        for k in range(n):
            t = 0.1 + 0.85 * k / (n - 1) + rng.uniform(-0.03, 0.03)
            p = at(main, t)
            side = -1 if k % 2 else 1
            e = (p[0] + side * S * rng.uniform(0.10, 0.2), p[1] - S * rng.uniform(0.02, 0.10))
            br = bezier(p, ((p[0] + e[0]) / 2, p[1] - S * .03), e, 12)
            twig(d, br, 7, 3, (90, 74, 58, 255))
            shoots.append((e, heading(br, 1.0)))
            shoots.append((at(br, 0.55), heading(br, 0.55) + side * 35))
        items = []
        for tip, h in shoots:  # leaves cluster at the shoot tips, fanned outward
            for j in range(rng.randint(5, 7)):
                items.append((rng.random(), tip, h + rng.uniform(-85, 85), S * rng.uniform(0.075, 0.105)))
        items.sort()
        for depth, tip, ang, L in items:
            color = jitter((60, 86, 36), rng, 0.10, 0.08)
            if rng.random() < 0.15: color = (color[0] * 1.3, color[1] * 1.22, color[2] * 1.45)
            oak_leaf(c, d, rng, tip, ang, L, color, 0.70 + 0.4 * depth, leaves)
    return compose(draw, 1024, 1024, seed)


def ponderosa_tile(seed: int) -> Image.Image:
    def draw(c, d, rng, S):
        main = stem(rng, S, 0.1, 0.3)
        bark = (96, 70, 48, 255)
        twig(d, main, 22, 9, bark)
        tufts = [(main[-1], heading(main, 1.0), 1.0)]
        for k, t in enumerate((0.2, 0.42, 0.64)):
            p = at(main, t)
            side = -1 if k % 2 else 1
            e = (p[0] + side * S * rng.uniform(0.2, 0.28), p[1] - S * rng.uniform(0.14, 0.22))
            br = bezier(p, ((p[0] + e[0]) / 2, p[1] - S * .05), e, 10)
            twig(d, br, 14, 8, bark)
            tufts.append((e, heading(br, 1.0), 0.85))
        green = (86, 100, 50)
        for center, h, size in tufts:
            # Foxtail: needles along the last part of the shoot and a brush at its tip.
            for i in range(170):
                spread = rng.gauss(0, 48)
                ang = math.radians(h + spread)
                L = S * size * rng.uniform(0.15, 0.27) * max(0.3, 1 - abs(spread) / 260)
                back = rng.uniform(0, 0.09) * S
                o = (center[0] - math.sin(math.radians(h)) * back, center[1] + math.cos(math.radians(h)) * back)
                p2 = (o[0] + math.sin(ang) * L, o[1] - math.cos(ang) * L)
                p1 = ((o[0] + p2[0]) / 2 + rng.uniform(-.06, .06) * L, (o[1] + p2[1]) / 2 + 0.05 * L)
                twig(d, bezier(o, p1, p2, 6), 7, 3, shaded(jitter(green, rng, 0.18, 0.08), rng.uniform(0.72, 1.15)))
    return compose(draw, 1024, 1024, seed)


def fir_tile(seed: int, cedar: bool) -> Image.Image:
    """Douglas fir: short needles all round drooping branchlets. Incense cedar: flat, lacy
    fans of scale leaves."""
    green = (82, 104, 48) if cedar else (50, 78, 48)
    bark = (82, 62, 46, 255)

    def needles(d, rng, path, S, depth):
        for i in range(len(path) - 1):
            (x0, y0), (x1, y1) = path[i], path[i + 1]
            L = math.hypot(x1 - x0, y1 - y0) or 1
            ux, uy = (x1 - x0) / L, (y1 - y0) / L
            steps = max(1, int(L / (7 if cedar else 6)))
            for s in range(steps):
                t = s / steps
                o = (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
                if cedar:
                    r = rng.uniform(17, 24) * (1.0 if depth < 2 else 0.8)
                    d.ellipse([o[0] - r, o[1] - r * 1.3, o[0] + r, o[1] + r * 1.3],
                              fill=shaded(jitter(green, rng, 0.12, 0.05), rng.uniform(0.8, 1.12)))
                else:
                    for side in (-1, 1):
                        nl = S * rng.uniform(0.022, 0.034)
                        a = rng.uniform(0.6, 1.0)
                        e = (o[0] + (-uy * side * a + ux * 0.45) * nl, o[1] + (ux * side * a + uy * 0.45) * nl)
                        d.line([o, e], fill=shaded(jitter(green, rng, 0.15, 0.06), rng.uniform(0.72, 1.15)), width=6)

    def branch(d, rng, p, ang, L, depth, S):
        droop = 0 if cedar else 0.25
        e = (p[0] + math.sin(math.radians(ang)) * L, p[1] - math.cos(math.radians(ang)) * L + droop * L * 0.6)
        mid = ((p[0] + e[0]) / 2 + rng.uniform(-.08, .08) * L, (p[1] + e[1]) / 2 - (0.08 if cedar else -0.05) * L)
        path = bezier(p, mid, e, 14)
        twig(d, path, 8 if depth == 0 else 5, 3, bark)
        if depth < (3 if cedar else 2):
            n = (rng.randint(4, 6) if depth == 0 else rng.randint(2, 4)) + (1 if cedar else 0)
            for k in range(n):
                t = 0.2 + 0.7 * k / max(1, n - 1) + rng.uniform(-0.05, 0.05)
                side = -1 if (k + depth) % 2 else 1
                branch(d, rng, at(path, t), heading(path, t) + side * rng.uniform(40, 62),
                       L * rng.uniform(0.4, 0.55) * (1.1 - t * 0.5), depth + 1, S)
        needles(d, rng, path, S, depth)

    def draw(c, d, rng, S):
        branch(d, rng, (OFF + S * 0.5, OFF + S * 0.97), rng.uniform(-8, 8), S * 0.8, 0, S)
    return compose(draw, 1024, 1024, seed)


TREE_MEAN = {"ponderosa": (86, 100, 50), "incense_cedar": (82, 104, 48), "douglas_fir": (50, 78, 48), "black_oak": (60, 86, 36)}


def tree_atlas(species: str, leaves) -> Image.Image:
    atlas = Image.new("RGBA", (2048, 2048), (0, 0, 0, 0))
    for t in range(4):
        seed = 18480 + 97 * t + list(TREE_MEAN).index(species) * 1000
        if species == "black_oak": tile = oak_tile(seed, leaves)
        elif species == "ponderosa": tile = ponderosa_tile(seed)
        else: tile = fir_tile(seed, species == "incense_cedar")
        atlas.alpha_composite(tile, ((t % 2) * 1024, (t // 2) * 1024))
    return bleed(atlas, TREE_MEAN[species])


# ---------------------------------------------------------------- understory

def fit(img: Image.Image, w: int, h: int) -> Image.Image:
    """Scale to fit w x h keeping aspect; bottom-centred (stems on the tile's base)."""
    s = min(w / img.width, h / img.height)
    im = img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(im, ((w - im.width) // 2, h - im.height))
    return out


def shrub_spray(seed: int, leaves, color, leaf_len, width_scale, count, bark) -> Image.Image:
    tinted = [recolor(l, color, 1.0) for l in leaves]

    def draw(c, d, rng, S):
        main = stem(rng, S)
        twig(d, main, 16, 5, bark)
        stems = [main]
        for k in range(6):
            p = at(main, 0.22 + 0.13 * k)
            side = -1 if k % 2 else 1
            e = (p[0] + side * S * rng.uniform(0.18, 0.32), p[1] - S * rng.uniform(0.10, 0.24))
            br = bezier(p, ((p[0] + e[0]) / 2, p[1] - S * .05), e, 12)
            twig(d, br, 9, 3, bark)
            stems.append(br)
        items = []
        for i in range(count):
            st = stems[rng.randrange(len(stems))]
            t = rng.uniform(0.2, 1.0) ** 0.7
            ang = heading(st, t) + rng.choice([-1, 1]) * rng.uniform(25, 70)
            items.append((rng.random(), at(st, t), ang, S * leaf_len * rng.uniform(0.75, 1.2)))
        items.sort()
        for depth, p, ang, L in items:
            arr = np.asarray(tinted[rng.randrange(len(tinted))]).astype(np.float32)
            arr[..., :3] *= (0.68 + 0.45 * depth) * rng.uniform(0.9, 1.1)
            stamp(c, Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA"), p, ang, L, width_scale)
    return compose(draw, 512, 512, seed)


def understory_atlas(leaves):
    atlas = Image.new("RGBA", (2048, 2048), (0, 0, 0, 0))
    regions = {}

    def put(name, img, x, y):
        atlas.alpha_composite(img, (x, y))
        regions[name] = [x / 2048, y / 2048, img.width / 2048, img.height / 2048]

    grass = rgba("grass_medium_01", "2k")
    tufts = [(410, 1528, 1015, 1798), (1185, 1545, 1665, 1748), (52, 1772, 402, 1994), (478, 1808, 1012, 1997), (1165, 1790, 1610, 2046)]
    for i, box in enumerate(tufts):
        tuft = recolor(grass.crop(box), (82, 94, 54), 0.85, keep=0.1)
        put("grass_%d" % i, fit(tuft, 512, 256), (i % 4) * 512, (i // 4) * 256)
    # Sedge tufts for wet ground: the same tufts, narrowed, taller and darker.
    for i, box in enumerate(tufts[:3]):
        tuft = recolor(grass.crop(box), (62, 86, 46), 1.0, keep=0.2)
        tuft = tuft.resize((int(tuft.width * 0.55), int(tuft.height * 1.25)), Image.LANCZOS)
        put("sedge_%d" % i, fit(tuft, 512, 256), (1 + i) * 512, 256)
    fern = rgba("fern_02", "2k")
    lab, n = ndimage.label(ndimage.binary_dilation(np.asarray(fern)[..., 3] > 128, iterations=4))
    objs = sorted([s for s in ndimage.find_objects(lab) if (s[0].stop - s[0].start) > 900], key=lambda s: s[1].start)
    for i, sl in enumerate(objs[:4]):
        frond = recolor(fern.crop((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop)), (70, 98, 44), 1.0, keep=0.4)
        put("fern_%d" % i, fit(frond, 256, 1024), i * 256, 512)
    bark_red = (120, 52, 36, 255)
    grey = (96, 84, 62, 255)
    put("willow_0", shrub_spray(501, leaves, (96, 114, 72), 0.20, 0.55, 150, grey), 1024, 512)
    put("willow_1", shrub_spray(502, leaves, (86, 106, 64), 0.18, 0.5, 170, (90, 80, 60, 255)), 1536, 512)
    put("manzanita_0", shrub_spray(503, leaves, (100, 114, 84), 0.075, 2.0, 260, bark_red), 1024, 1024)
    put("toyon_0", shrub_spray(504, leaves, (48, 70, 34), 0.12, 1.0, 190, (82, 66, 50, 255)), 1536, 1024)
    put("deerbrush_0", shrub_spray(505, leaves, (80, 108, 50), 0.065, 1.7, 300, (96, 92, 70, 255)), 0, 1536)
    put("manzanita_1", shrub_spray(506, leaves, (94, 110, 80), 0.08, 2.0, 240, bark_red), 512, 1536)
    put("alder_0", shrub_spray(507, leaves, (58, 90, 44), 0.11, 1.6, 170, (110, 104, 92, 255)), 1024, 1536)
    put("toyon_1", shrub_spray(508, leaves, (52, 74, 36), 0.12, 0.95, 190, (82, 66, 50, 255)), 1536, 1536)
    return bleed(atlas, (80, 98, 48)), regions


# ---------------------------------------------------------------- bark array

BARK_LAYERS = [  # layer order is shared with shaders/bark.gdshader and Assets.BARK_LAYER
    ("pine_bark", "ponderosa"),
    ("japanese_cedar_bark", "incense_cedar"),
    ("bark_willow", "douglas_fir"),
    ("bark_brown_02", "black_oak"),
    ("jolcham_oak_bark_01", "alder, willow"),
    # 5: smooth manzanita bark, derived below
]


def bark_array():
    albedo, normal = [], []
    for asset, _ in BARK_LAYERS:
        albedo.append(Image.open(ph(asset, "1k", "%s_diff_1k.jpg" % asset)).convert("RGB").resize((512, 512), Image.LANCZOS))
        normal.append(Image.open(ph(asset, "1k", "%s_nor_gl_1k.jpg" % asset)).convert("RGB").resize((512, 512), Image.LANCZOS))
    # Layer 5: smooth, red-brown manzanita bark from the cedar's fibres, blurred and reddened.
    arr = np.asarray(albedo[1].filter(ImageFilter.GaussianBlur(3))).astype(np.float32)
    lum = arr @ np.array([.2126, .7152, .0722], np.float32)
    arr = np.array((150, 62, 40), np.float32) * (lum / lum.mean())[..., None] ** 0.6
    albedo.append(Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB"))
    flat = (np.asarray(normal[1].filter(ImageFilter.GaussianBlur(4))).astype(np.float32) - 128) * 0.35 + 128
    normal.append(Image.fromarray(flat.clip(0, 255).astype(np.uint8), "RGB"))
    out_a = Image.new("RGB", (512, 512 * len(albedo)))
    out_n = Image.new("RGB", (512, 512 * len(albedo)))
    for i, (a, n) in enumerate(zip(albedo, normal)):
        out_a.paste(a, (0, i * 512)); out_n.paste(n, (0, i * 512))
    return out_a, out_n


def main():
    only = sys.argv[1:]
    leaves = willow_leaves()
    for species in TREE_MEAN:
        if not only or species in only:
            save_png(tree_atlas(species, leaves), OUT / ("foliage_%s_albedo.png" % species))
    if not only or "understory" in only:
        atlas, regions = understory_atlas(leaves)
        save_png(atlas, OUT / "foliage_understory_albedo.png")
        (HERE / "foliage_regions.json").write_text(json.dumps(regions, indent=1, sort_keys=True) + "\n")
    if not only or "bark" in only:
        a, n = bark_array()
        save_png(a, OUT / "bark_albedo.png")
        save_png(n, OUT / "bark_normal.png")


if __name__ == "__main__":
    main()
