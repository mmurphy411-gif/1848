"""Shared kit for the Stage 6 parametric props (camp, store, shelf goods).

Run directly to build `assets/props/kit_materials.glb`:

  blender --background --python blender/prop_kit.py

Built props carry placeholder materials named `kit_*` (base colour only, no images);
`scripts/prop_kit.gd` swaps in the textured materials from `kit_materials.glb` at load,
so bark, sawn wood, canvas, burlap, rope, iron and the rest are stored once and tile
in real-world units. Photo textures come from the CC0 cache (Poly Haven, 1k JPG; rows
in assets/CC0_MANIFEST.json); the small ones are procedural (numpy, fixed seeds).

Builders import this module for: `MeshBuilder` (per-loop UVs, per-vertex grey dirt
in COLOR_0), tubes along polylines, lathes, boxes and planks, catenary ropes, a
seeded 3D value noise for organic displacement, and `export_glb`.
Geometry is authored in Blender coordinates (Z up, -Y is Godot +Z); `gd(x, y, z)`
converts a Godot point.
"""
import math
import sys
import tempfile
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
sys.path.insert(0, str(ROOT / "blender"))
from common import GLTF_EXPORT  # noqa: E402


def cache_root() -> Path:
    for base in [ROOT, *ROOT.parents]:
        c = base / ".tools" / "cc0_cache"
        if c.exists():
            return c
    raise SystemExit("CC0 cache not found; run tools/art/fetch_cc0.py first")


def gd(x, y, z):
    """Godot (x, y up, z toward the viewer) to Blender (x, -z, y)."""
    return Vector((x, -z, y))


# ---------------------------------------------------------------- textures

def _lin(c):
    return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)


def _srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= .0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - .055)


def smooth_noise(n, scale, seed, octaves=1):
    """Tileable smooth noise in [0,1], n x n, feature size ~ n/scale px."""
    rng = np.random.default_rng(seed)
    out = np.zeros((n, n))
    amp = 1.0
    for o in range(octaves):
        white = rng.standard_normal((n, n))
        f = np.fft.fftfreq(n)
        fx, fy = np.meshgrid(f, f)
        sigma = scale * (2 ** o) / n
        kernel = np.exp(-(fx ** 2 + fy ** 2) / (2 * sigma ** 2))
        layer = np.real(np.fft.ifft2(np.fft.fft2(white) * kernel))
        layer = (layer - layer.mean()) / (layer.std() + 1e-9)
        out += layer * amp
        amp *= .5
    out = (out - out.min()) / (out.max() - out.min() + 1e-9)
    return out


def height_to_normal(h, strength):
    """Tileable OpenGL (+Y) tangent-space normal map from a height field."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * .5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * .5 * strength
    # Image rows run top to bottom; glTF UV v runs bottom to top.
    nrm = np.stack([-dx, dy, np.ones_like(h)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    return nrm * .5 + .5


def voronoi_cells(n, cells, seed, squash=1.0):
    """Tileable jittered-grid Voronoi: (distance to nearest, edge distance, cell id)."""
    rng = np.random.default_rng(seed)
    pts = (np.arange(cells)[:, None, None] + rng.random((cells, cells, 2)) * np.array([1, 1])) / cells
    gx = np.arange(cells)
    pts[..., 0] = (gx[:, None] + rng.random((cells, cells))) / cells
    pts[..., 1] = (gx[None, :] + rng.random((cells, cells))) / cells
    y, x = (np.mgrid[:n, :n] + .5) / n
    best = np.full((n, n), 9.0)
    second = np.full((n, n), 9.0)
    ident = np.zeros((n, n))
    cx = np.floor(x * cells).astype(int)
    cy = np.floor(y * cells).astype(int)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            ix, iy = (cx + ox) % cells, (cy + oy) % cells
            p = pts[ix, iy]
            dxv = x - p[..., 0]
            dyv = y - p[..., 1]
            dxv -= np.round(dxv)
            dyv -= np.round(dyv)
            d = np.sqrt(dxv ** 2 + (dyv * squash) ** 2) * cells
            closer = d < best
            second = np.where(closer, best, np.minimum(second, d))
            ident = np.where(closer, ix * cells + iy, ident)
            best = np.where(closer, d, best)
    return best, second - best, ident


def _proc(name, n, seed):
    """Procedural albedo (sRGB 0..1), roughness, metallic, height for the small kit."""
    y, x = (np.mgrid[:n, :n] + .5) / n
    lo = smooth_noise(n, 3, seed)
    mid = smooth_noise(n, 10, seed + 1)
    hi = smooth_noise(n, 48, seed + 2)
    metal = np.zeros((n, n))
    if name == "endgrain":
        r = np.hypot(x - .5, y - .5) * 2 + (mid - .5) * .05
        rings = .5 + .5 * np.sin(r * 2 * math.pi * 14 + lo * 3)
        ang = np.arctan2(y - .5, x - .5)
        crack = np.exp(-((np.sin(ang * 3 + 1.3) * r * 40) ** 2)) * (r > .15) * (r < .85)
        wood = np.array([.70, .56, .38]) * (.82 + .18 * rings)[..., None]
        bark = np.array([.20, .14, .09]) * (.8 + .4 * hi)[..., None]
        t = np.clip((r - .86) / .06, 0, 1)[..., None]
        alb = wood * (1 - t) + bark * t
        alb *= (1 - .55 * crack)[..., None]
        alb *= (.85 + .15 * lo)[..., None]
        rough = .82 + .1 * hi
        h = rings * .3 - crack + hi * .3
        return alb, rough, metal, h, 2.0
    if name == "rope":
        s = .5 + .5 * np.sin(2 * math.pi * (x * 3 + y * 8))
        fib = .5 + .5 * np.sin(2 * math.pi * (x * 30 + y * 80) + hi * 6)
        alb = np.array([.56, .47, .33]) * (.62 + .3 * s + .08 * fib)[..., None]
        alb *= (.9 + .1 * lo)[..., None]
        return alb, .9 + .05 * hi, metal, s * .8 + fib * .2, 4.0
    if name == "iron":
        rust = np.clip((smooth_noise(n, 6, seed + 5, 3) - .55) * 5, 0, 1) * .8
        base = np.array([.085, .083, .080]) * (.8 + .4 * mid)[..., None]
        rst = np.array([.30, .16, .085]) * (.75 + .5 * hi)[..., None]
        alb = base * (1 - rust[..., None]) + rst * rust[..., None]
        rough = .55 + .25 * hi + .2 * rust
        metal = .75 * (1 - rust)
        return alb, rough, metal, hi * .4 + rust * .4, 1.5
    if name == "brass":
        tarn = np.clip((smooth_noise(n, 5, seed + 6, 2) - .4) * 2, 0, 1)
        alb = np.array([.66, .50, .24]) * (1 - .45 * tarn)[..., None] + np.array([.10, .10, .06]) * tarn[..., None]
        return alb, .32 + .3 * tarn + .08 * hi, .95 - .2 * tarn, hi * .2, 1.0
    if name == "slate":
        chalk = np.clip((smooth_noise(n, 4, seed + 7, 3) - .45) * 1.6, 0, 1) * .5
        alb = np.array([.075, .092, .095]) * (.85 + .3 * hi)[..., None] + np.array([.10, .10, .10]) * (chalk * .35)[..., None]
        return alb, .86 + .08 * hi, metal, hi * .3, 1.0
    if name == "leather":
        pebble = voronoi_cells(n, 40, seed + 8)[1]
        alb = np.array([.30, .17, .09]) * (.75 + .25 * mid + .15 * np.clip(pebble * 3, 0, 1))[..., None]
        return alb, .62 + .15 * lo, metal, np.clip(pebble * 2, 0, 1), 2.0
    if name == "paper":
        fox = np.clip((smooth_noise(n, 8, seed + 9, 2) - .6) * 3, 0, 1)
        alb = np.array([.82, .76, .62]) * (.94 + .06 * hi)[..., None] * (1 - .25 * fox)[..., None]
        return alb, .92 + .04 * hi, metal, hi * .2, .8
    if name == "daub":
        straw = np.clip((np.sin(2 * math.pi * (x * 40 + mid * 6)) - .93) * 12, 0, 1) * (hi > .55)
        alb = np.array([.46, .37, .27]) * (.75 + .3 * mid + .1 * hi)[..., None]
        alb = alb * (1 - straw[..., None] * .5) + np.array([.62, .52, .30]) * (straw[..., None] * .5)
        return alb, .95, metal, mid * .5 + hi * .5, 3.0
    if name in ("beans", "coffee", "salt", "flour"):
        if name in ("flour", "salt"):
            grain = smooth_noise(n, 90 if name == "salt" else 30, seed + 10)
            col = np.array([.90, .88, .82]) if name == "flour" else np.array([.86, .87, .87])
            alb = col * (.88 + .12 * grain + .05 * lo)[..., None]
            return alb, .95, metal, grain * .5, 1.5 if name == "salt" else .5
        d, edge, ident = voronoi_cells(n, 22 if name == "beans" else 26, seed + 11, 1.6)
        rng = np.random.default_rng(seed + 12)
        tint = rng.random(int(ident.max()) + 1)[ident.astype(int)]
        if name == "beans":  # pinto-type field beans: buff with brown mottle
            base = np.array([.62, .45, .30]) * (.8 + .3 * tint)[..., None]
            mott = (smooth_noise(n, 60, seed + 13) > .6)[..., None]
            base = np.where(mott, base * .55, base)
        else:  # green (unroasted) coffee, as shipped in 1848
            base = np.array([.48, .47, .33]) * (.8 + .3 * tint)[..., None]
        bump = np.clip(1 - d * 1.2, 0, 1)
        alb = base * (.35 + .65 * np.clip(edge * 6, 0, 1))[..., None]
        return alb, .6, metal, bump, 3.0
    if name == "pork":
        band = .5 + .5 * np.sin(2 * math.pi * (y * 3 + mid * .6))
        lean = np.clip((band - .55) * 4, 0, 1)
        alb = np.array([.82, .72, .60]) * (1 - lean)[..., None] + np.array([.62, .34, .27]) * lean[..., None]
        alb *= (.9 + .1 * hi)[..., None]
        return alb, .55, metal, band * .3, 1.0
    if name == "tin":  # tinplate: bright, mottled where the tin coat is thin, a few rust pits
        mottle = smooth_noise(n, 14, seed + 20, 3)
        rust = np.clip((smooth_noise(n, 9, seed + 21, 2) - .78) * 6, 0, 1)
        alb = np.array([.66, .66, .64]) * (.78 + .3 * mottle)[..., None]
        alb = alb * (1 - rust[..., None]) + np.array([.36, .19, .09]) * rust[..., None]
        rough = .28 + .22 * mottle + .4 * rust
        metal = .9 * (1 - rust)
        return alb, rough, metal, hi * .15 + rust * .4, 1.0
    if name == "crock":
        # Salt-glazed stoneware: buff body with orange-peel glaze below, dark brown
        # Albany slip on the shoulder running down in drips. v = 1 - y is up the pot.
        v = 1 - y
        peel = smooth_noise(n, 70, seed + 22)
        body = np.array([.66, .58, .44]) * (.82 + .2 * mid + .08 * peel)[..., None]
        flash = np.clip((smooth_noise(n, 4, seed + 23, 2) - .45) * 2, 0, 1)  # kiln flashing
        body = body * (1 - .25 * flash[..., None]) + np.array([.55, .36, .20]) * (.25 * flash[..., None])
        drips = np.zeros(n)
        rng = np.random.default_rng(seed + 24)
        for _ in range(16):
            c, w, d = rng.random(), rng.uniform(.008, .025), rng.uniform(.04, .2)
            dx = np.minimum(np.abs(x[0] - c), 1 - np.abs(x[0] - c))
            drips = np.maximum(drips, d * np.clip(1 - (dx / w) ** 2, 0, 1) ** .5)
        edge = .6 - .02 * np.sin(x * 2 * math.pi * 3) - drips[None, :] - .02 * mid
        slip = np.clip((v - edge) / .012, 0, 1)
        brown = np.array([.20, .11, .055]) * (.8 + .4 * hi)[..., None]
        alb = body * (1 - slip[..., None]) + brown * slip[..., None]
        rough = .42 - .2 * slip + .06 * peel
        return alb, rough, metal, peel * .25 + slip * .2, 1.5
    if name == "ash":  # a sooty, charcoal-black pit floor with pale ash drifts and burnt bits
        blot = smooth_noise(n, 9, seed + 25, 3)
        fine = smooth_noise(n, 40, seed + 26, 2)
        pale = np.clip((blot * .6 + fine * .4 - .55) * 4, 0, 1)
        soot = np.array([.075, .07, .065]) * (.75 + .5 * fine + .3 * hi)[..., None]
        ash = np.array([.42, .41, .39]) * (.75 + .3 * mid)[..., None]
        brown = np.clip((smooth_noise(n, 14, seed + 27) - .6) * 4, 0, 1)
        alb = soot * (1 - pale[..., None]) + ash * pale[..., None]
        alb = alb * (1 - .4 * brown[..., None]) + np.array([.22, .15, .1]) * (.4 * brown[..., None])
        h = .3 * mid + .2 * hi + .3 * (1 - pale)
        return alb, .95 - .15 * (1 - pale), metal, h, 2.0
    raise KeyError(name)


# (source, tile metres, saturation, value, tint rgb or None, tint strength, size, double sided)
PHOTO = {
    "kit_bark": ("bark_brown_02", .85, .95, None, 0, 1024, False),
    "kit_wood": ("weathered_planks", .8, 1.55, None, 0, 1024, False),
    "kit_split": ("weathered_planks", .7, 2.3, (.62, .50, .36), .5, 1024, False),
    "kit_canvas": ("cotton_jersey", 1.0, 1.0, (.70, .66, .55), 1.0, 1024, True),
    "kit_cotton": ("cotton_jersey", 1.0, 1.0, (.66, .62, .53), 1.0, 512, False),
    "kit_burlap": ("hessian_230", 1.0, .95, None, 0, 1024, False),
    "kit_wool": ("poly_wool_herringbone", 1.0, 1.0, (.40, .14, .10), 1.0, 512, False),
    # Wave C: osnaburg (coarse unbleached cotton) for flour and salt sacks, a striped trade
    # blanket, the price board's dark paint over weathered planks, and the painted sign.
    "kit_osnaburg": ("hessian_230", .8, 1.0, (.74, .68, .55), 1.0, 1024, False),
    "kit_blanket": ("poly_wool_herringbone", 1.0, 1.0, (.76, .72, .62), 1.0, 512, False),
    "kit_paint": ("weathered_planks", 1.0, 1.0, (.30, .085, .06), .9, 512, False),
    "kit_sign": ("cotton_jersey", 1.0, 1.0, (.80, .76, .64), 1.0, 1024, True),
}
PROC = {
    "kit_endgrain": ("endgrain", 512), "kit_rope": ("rope", 256), "kit_iron": ("iron", 512),
    "kit_brass": ("brass", 256), "kit_slate": ("slate", 512), "kit_leather": ("leather", 256),
    "kit_paper": ("paper", 256), "kit_daub": ("daub", 512), "kit_beans": ("beans", 256),
    "kit_coffee": ("coffee", 256), "kit_flour": ("flour", 256), "kit_salt": ("salt", 256),
    "kit_pork": ("pork", 256), "kit_tin": ("tin", 256), "kit_crock": ("crock", 512), "kit_ash": ("ash", 256),
}
# Lettered sources from tools/art/build_prop_labels.py (in the cache's generated/ folder).
LABELS = "generated/prop_labels"
# Placeholder base colours (sRGB), close to each texture's mean, for the props' own GLBs.
BASE = {
    "kit_bark": (.33, .29, .22), "kit_wood": (.40, .34, .29), "kit_split": (.62, .50, .36),
    "kit_canvas": (.70, .66, .55), "kit_cotton": (.66, .62, .53), "kit_burlap": (.53, .45, .33),
    "kit_wool": (.40, .14, .10), "kit_endgrain": (.62, .49, .33), "kit_rope": (.47, .39, .28),
    "kit_iron": (.11, .10, .09), "kit_brass": (.58, .44, .21), "kit_slate": (.08, .095, .10),
    "kit_leather": (.28, .16, .09), "kit_paper": (.80, .74, .60), "kit_daub": (.44, .35, .26),
    "kit_beans": (.42, .30, .20), "kit_coffee": (.38, .37, .26), "kit_flour": (.88, .86, .80),
    "kit_salt": (.85, .86, .86), "kit_pork": (.74, .58, .48), "kit_glass": (.33, .19, .07),
    "kit_osnaburg": (.74, .68, .55), "kit_blanket": (.76, .72, .62), "kit_paint": (.30, .085, .06),
    "kit_sign": (.80, .76, .64), "kit_tin": (.62, .62, .60), "kit_crock": (.50, .40, .28),
    "kit_ash": (.40, .38, .36), "kit_labels": (.80, .74, .62), "kit_stencil": (.09, .07, .05),
}
DOUBLE = {"kit_canvas", "kit_glass", "kit_sign"}


def _image(name, rgb, colour, tmp):
    """rgb: HxWx3 in 0..1 (already sRGB for colour images)."""
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    px = np.ones((h, w, 4), dtype=np.float32)
    px[..., :3] = rgb[::-1]  # Blender stores rows bottom-up
    img.pixels.foreach_set(px.ravel())
    path = Path(tmp) / (name + ".png")
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    return img


def _read_jpg(path: Path, size):
    img = bpy.data.images.load(str(path))
    if tuple(img.size) != (size, size):
        img.scale(size, size)  # some Poly Haven sets are 1024 x 1025
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    arr = px.reshape(h, w, 4)[::-1, :, :3].copy()
    bpy.data.images.remove(img)
    return arr


def _load_png(path: Path):
    """Any image as an HxWx4 float array, rows top to bottom (stored values / 255)."""
    img = bpy.data.images.load(str(path))
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    arr = px.reshape(h, w, 4)[::-1].copy()
    bpy.data.images.remove(img)
    return arr


def _save_grey(a, path: Path):
    h, w = a.shape
    img = bpy.data.images.new(path.stem, w, h, alpha=False)
    px = np.ones((h, w, 4), dtype=np.float32)
    px[..., :3] = np.clip(a[::-1], 0, 1)[..., None]
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    print("WROTE", path)


def grade(rgb, sat, val, tint, strength):
    lin = _lin(rgb)
    lum = (lin @ np.array([.2126, .7152, .0722]))[..., None]
    lin = lum + (lin - lum) * sat
    lin = lin * val
    if tint is not None and strength > 0:
        # The mean becomes the tint; each pixel keeps its luminance ratio to the mean.
        target = _lin(np.array(tint))
        ratio = lum / max(float(lum.mean()), 1e-6)
        tinted = target[None, None, :] * ratio
        lin = lin * (1 - strength) + tinted * strength
    return _srgb(lin)


def kit_material(name, albedo, orm, normal, double):
    m = bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    m.use_backface_culling = not double
    nt = m.node_tree
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    def tex(img):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img
        return t
    nt.links.new(tex(albedo).outputs["Color"], p.inputs["Base Color"])
    o = tex(orm)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(o.outputs["Color"], sep.inputs[0])
    nt.links.new(sep.outputs[1], p.inputs["Roughness"])
    nt.links.new(sep.outputs[2], p.inputs["Metallic"])
    group = bpy.data.node_groups.get("glTF Material Output")
    if group is None:
        group = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        group.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    g = nt.nodes.new("ShaderNodeGroup")
    g.node_tree = group
    nt.links.new(sep.outputs[0], g.inputs["Occlusion"])
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex(normal).outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], p.inputs["Normal"])
    return m


def build_kit(out=ASSETS / "props" / "kit_materials.glb"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cache = cache_root() / "polyhaven"
    mats = []
    with tempfile.TemporaryDirectory(prefix="kit_") as tmp:
        labels_dir = cache.parent / LABELS
        if not (labels_dir / "labels.png").exists():
            raise SystemExit("run tools/art/build_prop_labels.py first (system Python with Pillow)")
        for name, (src, sat, val, tint, strength, size, double) in PHOTO.items():
            d = cache / src / "1k"
            raw = _read_jpg(d / f"{src}_diff_1k.jpg", size)
            alb = grade(raw, sat, val, tint, strength)
            arm = _read_jpg(d / f"{src}_arm_1k.jpg", size)
            nor = _read_jpg(d / f"{src}_nor_gl_1k.jpg", size)
            if name in ("kit_canvas", "kit_sign"):  # weathering: soft water stains and grime
                stain = smooth_noise(size, 5, 61, 3)
                alb = alb * (.86 + .14 * stain)[..., None]
            if name == "kit_blanket":
                # Trade-blanket bands near each end of the 1 m repeat: green, red, gold, indigo.
                v = 1 - (np.arange(size) + .5) / size
                bands = [((.06, .095), (.10, .30, .16)), ((.10, .135), (.55, .09, .06)),
                         ((.14, .175), (.78, .60, .16)), ((.18, .215), (.10, .14, .34))]
                lum = (alb.mean(-1) / max(float(alb.mean()), 1e-6))[..., None]
                for (a, b), col in bands:
                    for lo, hi in ((a, b), (1 - b, 1 - a)):
                        m = ((v >= lo) & (v < hi)).astype(float)[:, None, None]
                        alb = alb * (1 - m) + np.clip(np.array(col) * lum, 0, 1) * m
            if name == "kit_paint":
                # Dark paint worn through to the grey wood on the board edges and high spots.
                # Kept dark: worn spots must not read as lettering (store_probes board probe).
                wood = grade(raw, .9, .62, None, 0)
                wear = np.clip((smooth_noise(size, 18, 64, 3) - .72) * 3.5, 0, 1) * np.clip((raw.mean(-1) - .2) * 4, 0, 1)
                alb = alb * (1 - wear[..., None]) + wood * wear[..., None]
            if name == "kit_sign":
                # The stall's sign: painted letters (ink mask, 1024 x 256) on a strip of canvas.
                ink = np.asarray(_load_png(labels_dir / "sign.png"), dtype=np.float64)[..., 0]
                h = ink.shape[0]
                alb, arm, nor = alb[:h], arm[:h], nor[:h]
                paint = np.array([.11, .05, .035])
                alb = alb * (1 - ink[..., None] * .92) + paint * (ink[..., None] * .92)
                arm = arm.copy()
                arm[..., 1] = arm[..., 1] * (1 - .3 * ink)
            mats.append(kit_material(name, _image(name + "_albedo", alb, True, tmp),
                                     _image(name + "_orm", arm, False, tmp),
                                     _image(name + "_normal", nor, False, tmp), double))
        # Printed paper labels (opaque atlas, 4 x 4 cells).
        lab = np.asarray(_load_png(labels_dir / "labels.png"), dtype=np.float64)[..., :3]
        grain = smooth_noise(512, 60, 65)
        grain = np.tile(grain, (1, 2))
        lh, lw = lab.shape[:2]
        orm = np.stack([np.full((lh, lw), .95), .9 + .05 * grain[:lh, :lw], np.zeros((lh, lw))], -1)
        mats.append(kit_material("kit_labels", _image("kit_labels_albedo", lab, True, tmp),
                                 _image("kit_labels_orm", orm, False, tmp),
                                 _image("kit_labels_normal", height_to_normal(grain[:lh, :lw], 3.0), False, tmp), False))
        # Shipping-mark stencils: an alpha mask the game's decal shader reads (no JPEG alpha).
        mask = np.asarray(_load_png(labels_dir / "stencil.png"), dtype=np.float64)[..., 0]
        _save_grey(mask, ASSETS / "props" / "stencil_mask.png")
        for i, (name, (kind, size)) in enumerate(PROC.items()):
            alb, rough, metal, h, strength = _proc(kind, size, 1848 + 37 * i)
            if name == "kit_slate":  # wiped sums ghost on the counter slate
                ghost = np.asarray(_load_png(labels_dir / "chalk.png"), dtype=np.float64)[..., 0]
                alb = alb + np.array([.75, .75, .72]) * (ghost * .85)[..., None]
            rough = np.broadcast_to(rough, (size, size))
            orm = np.stack([.75 + .25 * np.clip(h, 0, 1), rough, np.broadcast_to(metal, (size, size))], -1)
            mats.append(kit_material(name, _image(name + "_albedo", np.clip(alb, 0, 1), True, tmp),
                                     _image(name + "_orm", orm, False, tmp),
                                     _image(name + "_normal", height_to_normal(h, strength * size / 64), False, tmp),
                                     name in DOUBLE))
        glass = bpy.data.materials.new("kit_glass")
        glass.use_nodes = True
        p = next(n for n in glass.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        p.inputs["Base Color"].default_value = (*_lin(np.array(BASE["kit_glass"])), 1)
        p.inputs["Roughness"].default_value = .12
        p.inputs["Alpha"].default_value = .78
        glass.surface_render_method = "BLENDED"
        mats.append(glass)
        objs = []
        for i, m in enumerate(mats):
            b = MeshBuilder()
            q = [b.vert((i, 0, 0)), b.vert((i + .9, 0, 0)), b.vert((i + .9, .9, 0)), b.vert((i, .9, 0))]
            b.face(q, [(0, 0), (1, 0), (1, 1), (0, 1)], 0)
            objs.append(b.build(m.name, [m]))
        export_glb(objs, out, images=True)
    print("KIT", out, len(mats), "materials")


# ---------------------------------------------------------------- geometry

class MeshBuilder:
    """Faces with per-loop UVs and material slots; per-vertex grey dirt -> COLOR_0."""

    def __init__(self):
        self.v, self.c, self.f, self.uv, self.m, self.flat = [], [], [], [], [], []

    def vert(self, p, c=1.0):
        self.v.append(Vector(p))
        self.c.append(c)
        return len(self.v) - 1

    def face(self, ids, uvs, mat, flat=False):
        self.f.append(list(ids))
        self.uv.append([tuple(u) for u in uvs])
        self.m.append(mat)
        self.flat.append(flat)

    def extend(self, other, mat_map=None):
        base = len(self.v)
        self.v += other.v
        self.c += other.c
        for f, u, m, fl in zip(other.f, other.uv, other.m, other.flat):
            self.f.append([i + base for i in f])
            self.uv.append(u)
            self.m.append(mat_map[m] if mat_map else m)
            self.flat.append(fl)

    def transform(self, fn, start=0):
        for i in range(start, len(self.v)):
            self.v[i] = Vector(fn(self.v[i]))

    def dirt(self, fn):
        for i, p in enumerate(self.v):
            self.c[i] *= fn(p)

    def build(self, name, materials):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([tuple(p) for p in self.v], [], self.f)
        mesh.update()
        layer = mesh.uv_layers.new(name="UVMap")
        for poly, uvs, mi, fl in zip(mesh.polygons, self.uv, self.m, self.flat):
            poly.material_index = mi
            poly.use_smooth = not fl
            for li, uv in zip(poly.loop_indices, uvs):
                layer.data[li].uv = uv
        col = mesh.color_attributes.new(name="Color", type="BYTE_COLOR", domain="POINT")
        for i, c in enumerate(self.c):
            g = max(0.0, min(1.0, c))
            col.data[i].color = (g, g, g, 1)
        mesh.color_attributes.active_color = col
        # Caps are n-gons; MikkTSpace tangents (for the normal maps) need them triangulated.
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
        bm.to_mesh(mesh)
        bm.free()
        for m in materials:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def placeholder(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgb = _lin(np.array(BASE[name]))
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = .85
    m.diffuse_color = (*rgb, 1)
    m.use_backface_culling = name not in DOUBLE
    if name == "kit_glass":
        p.inputs["Alpha"].default_value = .78
    return m


_P = np.array([151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225])


def vnoise(p, freq=1.0, seed=0):
    """Seeded smooth 3D value noise in [-1, 1] (deterministic, pure Python)."""
    x, y, z = p[0] * freq, p[1] * freq, p[2] * freq
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    xf, yf, zf = x - xi, y - yi, z - zi

    def h(i, j, k):
        n = (i * 73856093) ^ (j * 19349663) ^ (k * 83492791) ^ (seed * 2654435761)
        n = (n ^ (n >> 13)) * 1274126177
        return ((n ^ (n >> 16)) & 0xFFFF) / 32767.5 - 1.0

    def s(t):
        return t * t * (3 - 2 * t)
    u, v, w = s(xf), s(yf), s(zf)
    out = 0.0
    for dk in (0, 1):
        for dj in (0, 1):
            for di in (0, 1):
                wt = (u if di else 1 - u) * (v if dj else 1 - v) * (w if dk else 1 - w)
                out += wt * h(xi + di, yi + dj, zi + dk)
    return out


def fbm(p, freq, seed, octaves=3):
    a, f, t, norm = 1.0, freq, 0.0, 0.0
    for o in range(octaves):
        t += a * vnoise(p, f, seed + o)
        norm += a
        a *= .5
        f *= 2.03
    return t / norm


def _frame(d):
    d = d.normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < .1:
        side = d.cross(Vector((1, 0, 0)))
    side.normalize()
    return side, d.cross(side).normalized()


def tube(b, points, radii, mat, sides=8, tile=1.0, cap_mat=None, wobble=0.0, seed=0, dirt=None,
         twist=0.0, flat=False, u_offset=0.0):
    """Tube along a polyline; UV u around (metres/tile), v along (metres/tile)."""
    pts = [Vector(p) for p in points]
    if isinstance(radii, (int, float)):
        radii = [radii] * len(pts)
    rings = []
    length = 0.0
    prev_side = None
    for j, p in enumerate(pts):
        d = pts[min(j + 1, len(pts) - 1)] - pts[max(j - 1, 0)]
        side, other = _frame(d)
        if prev_side is not None and side.dot(prev_side) < 0:
            side, other = -side, -other
        prev_side = side
        if j:
            length += (pts[j] - pts[j - 1]).length
        r = radii[j]
        ring = []
        for k in range(sides + 1):
            a = math.tau * k / sides + twist * length
            rr = r * (1 + wobble * fbm((p.x + math.cos(a) * .3, p.y + math.sin(a) * .3, p.z), 3.0, seed)) if wobble else r
            q = p + rr * (math.cos(a) * side + math.sin(a) * other)
            c = dirt(q) if dirt else 1.0
            ring.append((b.vert(q, c), (u_offset + k / sides * math.tau * r / tile, length / tile)))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for k in range(sides):
            a0, a1 = rings[j][k], rings[j][k + 1]
            b0, b1 = rings[j + 1][k], rings[j + 1][k + 1]
            b.face([a0[0], a1[0], b1[0], b0[0]], [a0[1], a1[1], b1[1], b0[1]], mat, flat)
    if cap_mat is not None:
        for j, flip in ((0, True), (len(rings) - 1, False)):
            ring = rings[j][:sides]
            r = radii[j]
            p = pts[j]
            side, other = _frame(pts[min(j + 1, len(pts) - 1)] - pts[max(j - 1, 0)])
            ids, uvs = [], []
            for k, (vi, _) in enumerate(ring):
                q = b.v[vi] - p
                ids.append(vi)
                uvs.append((.5 + .5 * q.dot(side) / max(r, 1e-6), .5 + .5 * q.dot(other) / max(r, 1e-6)))
            if flip:
                ids, uvs = ids[::-1], uvs[::-1]
            b.face(ids, uvs, cap_mat, True)
    return rings


def lathe(b, profile, mat, sides=16, tile=1.0, center=(0, 0, 0), seed=0, wobble=0.0, dirt=None,
          close_top=False, close_bottom=False, cap_mat=None, squash=(1.0, 1.0)):
    """Surface of revolution of [(r, z), ...] about +Z through center."""
    cx, cy, cz = center
    rings = []
    arc = 0.0
    for j, (r, z) in enumerate(profile):
        if j:
            arc += math.hypot(r - profile[j - 1][0], z - profile[j - 1][1])
        ring = []
        for k in range(sides + 1):
            a = math.tau * k / sides
            rr = r * (1 + wobble * vnoise((math.cos(a) * 2, math.sin(a) * 2, z * 4), 1.0, seed)) if wobble else r
            q = Vector((cx + math.cos(a) * rr * squash[0], cy + math.sin(a) * rr * squash[1], cz + z))
            ring.append((b.vert(q, dirt(q) if dirt else 1.0), (k / sides * math.tau * max(r, .02) / tile, arc / tile)))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for k in range(sides):
            a0, a1 = rings[j][k], rings[j][k + 1]
            b0, b1 = rings[j + 1][k], rings[j + 1][k + 1]
            b.face([a0[0], a1[0], b1[0], b0[0]], [a0[1], a1[1], b1[1], b0[1]], mat)
    for j, use, flip in ((0, close_bottom, True), (len(rings) - 1, close_top, False)):
        if not use:
            continue
        r = max(profile[j][0], 1e-6)
        ids = [rings[j][k][0] for k in range(sides)]
        uvs = [(.5 + .5 * math.cos(math.tau * k / sides), .5 + .5 * math.sin(math.tau * k / sides)) for k in range(sides)]
        if flip:
            ids, uvs = ids[::-1], uvs[::-1]
        b.face(ids, uvs, cap_mat if cap_mat is not None else mat, True)
    return rings


def box(b, center, size, mat, tile=1.0, rot=None, grain=2, uv_offset=(0.0, 0.0), dirt=None, end_mat=None):
    """Axis box (Blender axes) with UVs in metres/tile; `grain` is the long axis (0,1,2)."""
    c = Vector(center)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    corners = [Vector((sx * hx, sy * hy, sz * hz)) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    if rot is not None:
        corners = [rot @ q for q in corners]
    ids = [b.vert(c + q, dirt(c + q) if dirt else 1.0) for q in corners]
    local = [Vector((sx * hx, sy * hy, sz * hz)) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    faces = [((0, 2, 3, 1), 2), ((4, 5, 7, 6), 2), ((0, 1, 5, 4), 1), ((2, 6, 7, 3), 1), ((0, 4, 6, 2), 0), ((1, 3, 7, 5), 0)]
    for quad, axis in faces:
        axes = [a for a in range(3) if a != axis]
        # v along grain where possible
        if grain in axes:
            ua = [a for a in axes if a != grain][0]
            va = grain
        else:
            ua, va = axes
        if end_mat is not None and axis == grain:
            a0, a1 = axes
            uvs = [(.5 + .45 * local[i][a0] / max(size[a0] / 2, 1e-6), .5 + .45 * local[i][a1] / max(size[a1] / 2, 1e-6)) for i in quad]
            b.face([ids[i] for i in quad], uvs, end_mat, True)
            continue
        uvs = [((local[i][ua] + 7) / tile + uv_offset[0], (local[i][va] + 7) / tile + uv_offset[1]) for i in quad]
        b.face([ids[i] for i in quad], uvs, mat, True)
    return ids


def catenary(a, b_, sag, n=10):
    a, b_ = Vector(a), Vector(b_)
    pts = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b_, t)
        p.z -= sag * 4 * t * (1 - t)
        pts.append(p)
    return pts


def rope(b, a, b_, mat, radius=.006, sag=.03, n=8, sides=5):
    return tube(b, catenary(a, b_, sag, n), radius, mat, sides=sides, tile=.05)


def wraps(b, center, axis, radius, mat, turns=4, width=.03, thickness=.006, sides=5, seg=10):
    """Rope lashing: a tight helix around a pole."""
    axis = Vector(axis).normalized()
    side, other = _frame(axis)
    pts = []
    n = turns * seg
    for i in range(n + 1):
        t = i / n
        a = math.tau * turns * t
        pts.append(Vector(center) + axis * (t - .5) * width + (radius + thickness) * (math.cos(a) * side + math.sin(a) * other))
    return tube(b, pts, thickness, mat, sides=sides, tile=.05)


def ground_dirt(base=.62, height=.25):
    def f(p):
        t = max(0.0, min(1.0, p.z / height))
        return base + (1 - base) * t * t * (3 - 2 * t)
    return f


def triangles(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def export_glb(objs, path: Path, images=False):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    settings = dict(GLTF_EXPORT)
    settings.update(export_image_format="JPEG" if images else "NONE", export_jpeg_quality=90)
    bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_materials="EXPORT", **settings)
    print("EXPORTED %s: %d objects, %d triangles, %.0f KB" % (path.relative_to(ROOT).as_posix(), len(objs), triangles(objs), path.stat().st_size / 1024))


if __name__ == "__main__":
    build_kit()
