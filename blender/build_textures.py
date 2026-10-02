"""Terrain and rock texture sets from CC0 scans (VISUAL_UPGRADE_PLAN.md stages 1 and 3).

Plain Python 3 with numpy and Pillow; Blender is not needed despite the folder:

  python blender/build_textures.py [set ...]

Each set is built from one scan in the shared CC0 cache (fetched on demand through
tools/art/fetch_cc0.py, which also writes the provenance row) into
assets/textures/<set>_{albedo,normal,orm}.png, and the outputs are recorded on the
row in assets/CC0_MANIFEST.json. The build is deterministic: same cache, same PNGs.

  albedo  sRGB RGB. Graded to the art target in linear light: the scan's baked
          low-frequency lighting is partly flattened (a periodic blur, so the map
          stays seamless; large light/dark blotches are what makes a tile repeat
          visibly), saturation and tint are set, then the mean linear luminance is
          scaled to the set's target. Final 8-bit PNG: no palette quantisation,
          because scans band visibly at 256 colours.
  normal  OpenGL convention (green up), unit length; imported as RGTC, and the
          shaders rebuild Z from XY. Blue is fixed at 255 so the PNG stays lean.
  orm     R ambient occlusion, G roughness, B height (0..1, low frequencies
          removed and stretched so every set's height has the same range for
          height-blended transitions). Metallic is zero for every ground set.

The retired procedural sets (shader-node graphs baked in Cycles) remain inspectable
in build_textures.blend; this script no longer touches that file.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import manifest  # noqa: E402

OUT = ROOT / "assets" / "textures"

# Per set: source scan and cache resolution, output size, target mean linear luminance,
# saturation factor, linear tint (renormalised to unit luminance), how much of the
# scan's low-frequency shading to flatten (0 keeps it, 1 removes it) and an optional
# luminance contrast exponent.
SETS = {
    # Mixed-colour river cobble: grey, tan, rust and dark stones in a sandy matrix.
    "gravel": dict(src=("polyhaven", "ganges_river_pebbles", "2k"), size=2048, lum=0.25, sat=1.3,
                   tint=(1.0, 1.0, 1.0), flatten=0.55, contrast=1.35),
    # Buff, low-contrast sand; the shader darkens it into the wet swash band.
    "sand": dict(src=("polyhaven", "dense_sand", "1k"), size=1024, lum=0.30, sat=0.85,
                 tint=(1.0, 1.0, 1.0), flatten=0.7),
    # Pale weathered granite, cooled from the scan's pink-tan to grey. 1k from the 2k
    # scan: after Stage 3 it skins only cobbles, props and quartz veins in the cliffs.
    "granite": dict(src=("polyhaven", "rock_boulder_dry", "2k"), size=1024, lum=0.335, sat=0.42,
                    tint=(0.97, 1.0, 1.03), flatten=0.45),
    # Dark slate scree at the cliff foot.
    "talus": dict(src=("polyhaven", "gray_rocks", "1k"), size=1024, lum=0.22, sat=0.55,
                  tint=(0.93, 1.0, 1.06), flatten=0.5),
    # Conifer needle and twig duff for forest floor, oak shade and the camp.
    "duff": dict(src=("polyhaven", "forest_leaves_04", "1k"), size=1024, lum=0.115, sat=0.78,
                 tint=(1.0, 1.0, 1.0), flatten=0.5),
    # Foliated slate/greenstone: cliffs, benches and the river bedrock ledges.
    "bedrock": dict(src=("ambientcg", "Rock022", "1K-JPG"), size=1024, lum=0.26, sat=1.0,
                    tint=(0.90, 1.0, 1.05), flatten=0.5),
    # Red-brown Sierra soil above the flood line.
    "soil": dict(src=("polyhaven", "red_dirt_mud_01", "1k"), size=1024, lum=0.13, sat=0.62,
                 tint=(0.94, 1.0, 1.06), flatten=0.6),
}

LUMA = np.array([0.2126, 0.7152, 0.0722], np.float32)


def to_linear(a):
    return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


def to_srgb(a):
    a = np.clip(a, 0.0, 1.0)
    return np.where(a <= 0.0031308, a * 12.92, 1.055 * np.power(a, 1 / 2.4) - 0.055)


def periodic_blur(channel, sigma):
    """Gaussian blur with wrap-around edges (FFT), so a seamless map stays seamless."""
    h, w = channel.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    kernel = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(channel) * kernel)).astype(np.float32)


def load(path, size, mode="RGB"):
    im = Image.open(path).convert(mode)
    if im.size != (size, size):
        im = im.resize((size, size), Image.Resampling.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def cache_dir(source, asset_id, res):
    path = manifest.cache_root() / source / asset_id / res
    if not (path / "_fetch.json").exists():
        subprocess.run([sys.executable, str(ROOT / "tools" / "art" / "fetch_cc0.py"), source, asset_id, res], check=True)
    else:
        # Cache hit: make sure this checkout's manifest has the row.
        row = json.loads((path / "_fetch.json").read_text())
        manifest.upsert(row)
    return path


def maps(source, asset_id, res):
    d = cache_dir(source, asset_id, res)
    if source == "polyhaven":
        r = res.lower()
        return dict(albedo=d / f"{asset_id}_diff_{r}.jpg", normal=d / f"{asset_id}_nor_gl_{r}.jpg",
                    arm=d / f"{asset_id}_arm_{r}.jpg", height=d / f"{asset_id}_disp_{r}.jpg")
    stem = d / f"{asset_id}_{res}"
    ao = Path(str(stem) + "_AmbientOcclusion.jpg")
    return dict(albedo=Path(str(stem) + "_Color.jpg"), normal=Path(str(stem) + "_NormalGL.jpg"),
                rough=Path(str(stem) + "_Roughness.jpg"), ao=ao if ao.exists() else None,
                height=Path(str(stem) + "_Displacement.jpg"))


def grade_albedo(rgb, s):
    lin = to_linear(rgb)
    size = lin.shape[0]
    lum = np.maximum((lin * LUMA).sum(-1), 1e-4)
    if s["flatten"] > 0:
        log_l = np.log(lum)
        low = periodic_blur(log_l, size / 10.0)
        lin = lin * np.exp(-s["flatten"] * (low - low.mean()))[..., None]
        lum = np.maximum((lin * LUMA).sum(-1), 1e-4)
    if s.get("contrast", 1.0) != 1.0:
        # Luminance exponent: darker dark stones, brighter quartz, same mean after scaling.
        lin = lin * (lum ** (s["contrast"] - 1.0))[..., None]
        lum = np.maximum((lin * LUMA).sum(-1), 1e-4)
    lin = lum[..., None] + (lin - lum[..., None]) * s["sat"]
    tint = np.array(s["tint"], np.float32)
    lin = lin * (tint / float((tint * LUMA).sum()))
    lin = np.maximum(lin, 0.0)
    for _ in range(4):  # clipping the brightest stones shifts the mean; converge.
        mean = float((lin * LUMA).sum(-1).mean())
        lin = np.clip(lin * (s["lum"] / mean), 0.0, 0.92)
    return to_srgb(lin), float((lin * LUMA).sum(-1).mean())


def build(name):
    s = SETS[name]
    source, asset_id, res = s["src"]
    m = maps(source, asset_id, res)
    size = s["size"]
    albedo, mean = grade_albedo(load(m["albedo"], size), s)

    n = load(m["normal"], size) * 2.0 - 1.0
    xy = n[..., :2]
    z = np.maximum(n[..., 2], 0.05)
    length = np.sqrt((xy * xy).sum(-1) + z * z)
    xy = xy / length[..., None]
    normal = np.dstack([xy * 0.5 + 0.5, np.ones((size, size), np.float32)])

    if "arm" in m:
        arm = load(m["arm"], size)
        ao, rough = arm[..., 0], arm[..., 1]
    else:
        rough = load(m["rough"], size, "L")
        ao = load(m["ao"], size, "L") if m["ao"] else np.ones((size, size), np.float32)
    # AO and roughness are smooth modulators: a light blur strips the source JPEG's
    # block noise and 64 levels keep the PNG lean without visible steps.
    ao, rough = [np.round(np.clip(periodic_blur(c, 0.8), 0.0, 1.0) * 63.0) / 63.0 for c in (ao, rough)]
    height = load(m["height"], size, "L")
    height = periodic_blur(height, 0.4) - periodic_blur(height, size / 6.0)
    lo, hi = np.percentile(height, [0.5, 99.5])
    height = np.clip((height - lo) / max(hi - lo, 1e-4), 0.0, 1.0)
    orm = np.dstack([ao, rough, height])

    outputs = []
    for suffix, data in (("albedo", albedo), ("normal", normal), ("orm", orm)):
        path = OUT / f"{name}_{suffix}.png"
        Image.fromarray(np.round(np.clip(data, 0, 1) * 255).astype(np.uint8), "RGB").save(path, optimize=True)
        outputs.append(path)
    spec = f"{source}:{asset_id}:{res}"
    for path in outputs:
        manifest.add_output(spec, str(path))
    sizes = ", ".join(f"{p.name} {p.stat().st_size / 1e6:.2f} MB" for p in outputs)
    print(f"{name}: {spec} -> mean linear albedo {mean:.3f}; {sizes}")


if __name__ == "__main__":
    for set_name in (sys.argv[1:] or SETS):
        build(set_name)
