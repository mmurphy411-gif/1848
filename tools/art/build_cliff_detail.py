"""Build assets/cliffs/cliff_detail.png, the tiling detail map of the Stage 2 cliff kit.

  python tools/art/build_cliff_detail.py [--size 512]

Channels (data, not colour; shaders/cliff_kit.gdshader tints them):
  R  slate strata: ambientCG Rock022 (scanned shale/slate) luminance, mean 0.5
  G  iron staining: ambientCG Rock056 orange-ochre strength (red minus blue), 0..1
  B  lichen: Poly Haven lichen_rock pale crust mask, 0..1
All three sources are seamless CC0 textures from the shared cache (fetch them with
tools/art/fetch_cc0.py first; their manifest rows list this file as an output).
Deterministic: same inputs, same bytes.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import manifest  # noqa: E402

OUT = ROOT / "assets" / "cliffs" / "cliff_detail.png"
SOURCES = {
    "slate": ("ambientcg:Rock022:1K-JPG", "ambientcg/Rock022/1K-JPG/Rock022_1K-JPG_Color.jpg"),
    "rust": ("ambientcg:Rock056:1K-JPG", "ambientcg/Rock056/1K-JPG/Rock056_1K-JPG_Color.jpg"),
    "lichen": ("polyhaven:lichen_rock:1k", "polyhaven/lichen_rock/1k/lichen_rock_diff_1k.jpg"),
}


def load(rel, size):
    path = manifest.cache_root() / rel
    if not path.exists():
        raise SystemExit("missing %s: run tools/art/fetch_cc0.py first" % path)
    return np.asarray(Image.open(path).convert("RGB").resize((size, size), Image.LANCZOS), dtype=np.float32) / 255.0


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--size", type=int, default=512)
    args = ap.parse_args()
    luma = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    slate = load(SOURCES["slate"][1], args.size) @ luma
    slate = np.clip(0.5 + (slate - slate.mean()) / (4.0 * slate.std()), 0, 1)
    rust_rgb = load(SOURCES["rust"][1], args.size)
    rust = rust_rgb[..., 0] - rust_rgb[..., 2]
    rust = smoothstep(np.percentile(rust, 20), np.percentile(rust, 97), rust)
    lichen_rgb = load(SOURCES["lichen"][1], args.size)
    lichen = smoothstep(np.percentile(lichen_rgb @ luma, 55), np.percentile(lichen_rgb @ luma, 92), lichen_rgb @ luma)
    rgb = np.stack([slate, rust, lichen], -1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.round(rgb * 255).astype(np.uint8), "RGB").save(OUT, optimize=True)
    print("wrote %s (%.0f KB); means R %.3f G %.3f B %.3f" % (OUT.relative_to(ROOT).as_posix(), OUT.stat().st_size / 1024,
                                                             *rgb.reshape(-1, 3).mean(0)))
    for spec, _ in SOURCES.values():
        manifest.add_output(spec, str(OUT))


if __name__ == "__main__":
    main()
