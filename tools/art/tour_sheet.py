"""Contact sheets, before/after sheets and per-view statistics for a visual tour.

  python tools/art/tour_sheet.py <before_dir> [<after_dir>] [--out <dir>] [--gates gates.json]

Every *.png in a directory is a view; its file stem is the view name, and views
are paired between the two directories by name.

Writes (to --out, default the after dir, or the only dir):
  tour_sheet_NN.jpg    contact sheets of the after (or only) dir, 800x450 tiles
                       with captions, --cols x --rows tiles per sheet (2x3)
  tour_compare_NN.jpg  with two dirs: one row per view, before left, after right
and always writes tour.json into the after dir (or the only dir).

Statistics, all on the 8-bit sRGB-encoded frame scaled to 0..1 (no linearising):
  luma        Rec.709 luma of the encoded values: Y' = .2126 R' + .7152 G' + .0722 B'
  saturation  HSV saturation of the encoded values: (max - min) / max, 0 where max = 0
  lower half  rows [H//2, H)
  mean_luminance         mean luma of the frame
  lower_mean_luminance   mean luma of the lower half
  bright_share           share of frame pixels with luma > 0.85
  lower_mean_saturation  mean saturation of the lower half
  ssim                   skimage SSIM of the luma planes against the before view
                         (data_range 1, default 7x7 window), when a before dir is given
These reproduce the October 2026 audit numbers: a1_downstream_10h gives lower-half
luma 0.660 / saturation 0.126 and b2_downstream_13h 0.672 / 0.127 (plan: 0.66-0.67
and 0.08-0.13). Linear luminance gives 0.41/0.43 and HSL saturation 0.131/0.140,
so neither was what the audit measured.

Gates (--gates FILE): JSON {"<view or glob>": {"<metric>": [min, max]}}; null for an
open end; keys starting with "_" are comments. A metric may be suffixed "/before"
to gate the ratio after/before, e.g. {"b3_*": {"lower_mean_luminance/before": [0.9, null]}}.
Prints PASS/FAIL per gate and exits 1 if any gate fails or matches no view.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

TILE = (800, 450)
CAPTION = 34
METRICS = ["mean_luminance", "lower_mean_luminance", "bright_share", "lower_mean_saturation"]
DEFINITIONS = {
    "colour_space": "8-bit sRGB-encoded values scaled to 0..1, not linearised",
    "luma": "Rec.709 luma of encoded values: 0.2126 R' + 0.7152 G' + 0.0722 B'",
    "saturation": "HSV saturation of encoded values: (max-min)/max, 0 where max=0",
    "lower_half": "rows H//2 .. H-1",
    "mean_luminance": "mean luma, whole frame",
    "lower_mean_luminance": "mean luma, lower half",
    "bright_share": "share of whole-frame pixels with luma > 0.85",
    "lower_mean_saturation": "mean HSV saturation, lower half",
    "ssim": "skimage.metrics.structural_similarity of luma planes vs the before view, data_range=1",
    "calibration": "audit a1_downstream_10h: lower luma 0.660, sat 0.126; b2_downstream_13h: 0.672, 0.127",
}


def views(d: Path) -> dict:
    return {p.stem: p for p in sorted(d.glob("*.png"))}


def load_rgb(p: Path) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.float32) / 255.0


def luma(rgb: np.ndarray) -> np.ndarray:
    return rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def saturation(rgb: np.ndarray) -> np.ndarray:
    mx, mn = rgb.max(-1), rgb.min(-1)
    return np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-8), 0.0)


def stats(rgb: np.ndarray) -> dict:
    y = luma(rgb)
    lo = rgb[rgb.shape[0] // 2:]
    return {
        "mean_luminance": float(y.mean()),
        "lower_mean_luminance": float(y[rgb.shape[0] // 2:].mean()),
        "bright_share": float((y > 0.85).mean()),
        "lower_mean_saturation": float(saturation(lo).mean()),
    }


def ssim(a: np.ndarray, b: np.ndarray) -> float:
    from skimage.metrics import structural_similarity
    if a.shape != b.shape:
        b = np.asarray(Image.fromarray((b * 255).astype(np.uint8)).resize((a.shape[1], a.shape[0]), Image.LANCZOS),
                       dtype=np.float32) / 255.0
    return float(structural_similarity(luma(a), luma(b), data_range=1.0))


def font(size: int):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Pillow < 10.1
        return ImageFont.load_default()


def tile(path: Path | None, caption: str) -> Image.Image:
    out = Image.new("RGB", (TILE[0], TILE[1] + CAPTION), (24, 24, 24))
    if path is not None:
        out.paste(Image.open(path).convert("RGB").resize(TILE, Image.LANCZOS), (0, CAPTION))
    else:
        ImageDraw.Draw(out).text((TILE[0] // 2, CAPTION + TILE[1] // 2), "missing", fill=(200, 80, 80),
                                 font=font(28), anchor="mm")
    ImageDraw.Draw(out).text((10, CAPTION // 2), caption, fill=(235, 235, 235), font=font(22), anchor="lm")
    return out


def contact_sheets(vs: dict, out: Path, cols: int, rows: int, quality: int) -> list:
    names = list(vs)
    per = cols * rows
    written = []
    for page in range(math.ceil(len(names) / per)):
        chunk = names[page * per:(page + 1) * per]
        r = math.ceil(len(chunk) / cols)
        sheet = Image.new("RGB", (cols * TILE[0], r * (TILE[1] + CAPTION)), (24, 24, 24))
        for i, n in enumerate(chunk):
            sheet.paste(tile(vs[n], n), ((i % cols) * TILE[0], (i // cols) * (TILE[1] + CAPTION)))
        p = out / ("tour_sheet_%02d.jpg" % (page + 1))
        sheet.save(p, quality=quality)
        written.append(p)
    return written


def compare_sheets(before: dict, after: dict, labels: tuple, out: Path, rows: int, quality: int) -> list:
    names = sorted(set(before) | set(after))
    header = 40
    written = []
    for page in range(math.ceil(len(names) / rows)):
        chunk = names[page * rows:(page + 1) * rows]
        sheet = Image.new("RGB", (2 * TILE[0], header + len(chunk) * (TILE[1] + CAPTION)), (24, 24, 24))
        d = ImageDraw.Draw(sheet)
        for c, text in enumerate(("BEFORE  " + labels[0], "AFTER  " + labels[1])):
            d.text((c * TILE[0] + 10, header // 2), text, fill=(255, 220, 120), font=font(24), anchor="lm")
        for i, n in enumerate(chunk):
            y = header + i * (TILE[1] + CAPTION)
            sheet.paste(tile(before.get(n), n), (0, y))
            sheet.paste(tile(after.get(n), n), (TILE[0], y))
        p = out / ("tour_compare_%02d.jpg" % (page + 1))
        sheet.save(p, quality=quality)
        written.append(p)
    return written


def check_gates(gates: dict, report: dict, before_stats: dict) -> bool:
    ok_all = True
    print("\n%-34s %-36s %9s  %-17s %s" % ("view", "metric", "value", "range", "result"))
    for pattern, metrics in gates.items():
        if pattern.startswith("_"):
            continue
        matched = [v for v in report if fnmatch.fnmatchcase(v, pattern)]
        if not matched:
            print("%-34s %-36s %9s  %-17s FAIL (no such view)" % (pattern, "-", "-", "-"))
            ok_all = False
            continue
        for v in matched:
            for metric, (lo, hi) in metrics.items():
                if metric.startswith("_"):
                    continue
                name, _, rel = metric.partition("/")
                value = report[v].get(name)
                if rel == "before":
                    b = before_stats.get(v, {}).get(name)
                    value = value / b if value is not None and b else None
                rng = "[%s, %s]" % ("-inf" if lo is None else lo, "inf" if hi is None else hi)
                ok = value is not None and (lo is None or value >= lo) and (hi is None or value <= hi)
                ok_all &= ok
                print("%-34s %-36s %9s  %-17s %s" % (v, metric, "n/a" if value is None else "%.4f" % value, rng,
                                                     "PASS" if ok else "FAIL"))
    return ok_all


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("before", type=Path, help="baseline dir (or the only dir)")
    ap.add_argument("after", type=Path, nargs="?", help="dir to compare against the baseline")
    ap.add_argument("--out", type=Path, help="where sheets go (default: after dir, or the only dir)")
    ap.add_argument("--gates", type=Path, help="JSON of view -> {metric: [min, max]}")
    ap.add_argument("--cols", type=int, default=2)
    ap.add_argument("--rows", type=int, default=3)
    ap.add_argument("--quality", type=int, default=90, help="JPEG quality of the sheets")
    ap.add_argument("--no-sheets", action="store_true", help="statistics and gates only")
    args = ap.parse_args(argv)

    target = args.after or args.before
    before = views(args.before) if args.after else {}
    after = views(target)
    if not after:
        raise SystemExit("no *.png views in %s" % target)
    out = args.out or target
    out.mkdir(parents=True, exist_ok=True)

    report, before_stats = {}, {}
    print("%-34s %8s %8s %8s %8s %8s" % ("view", "mean_L", "lower_L", ">0.85", "lower_S", "ssim"))
    for name, path in after.items():
        rgb = load_rgb(path)
        s = stats(rgb)
        if name in before:
            b = load_rgb(before[name])
            before_stats[name] = stats(b)
            s["ssim"] = ssim(rgb, b)
        report[name] = {k: round(v, 4) for k, v in s.items()}
        print("%-34s %8.3f %8.3f %8.3f %8.3f %8s" % (name, s["mean_luminance"], s["lower_mean_luminance"],
              s["bright_share"], s["lower_mean_saturation"], "%.3f" % s["ssim"] if "ssim" in s else "-"))

    doc = {"dir": target.resolve().as_posix(), "before": args.before.resolve().as_posix() if args.after else None,
           "definitions": DEFINITIONS, "views": report}
    if args.after:
        doc["missing_in_after"] = sorted(set(before) - set(after))
    (target / "tour.json").write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    print("wrote %s" % (target / "tour.json").as_posix())

    if not args.no_sheets:
        for p in contact_sheets(after, out, args.cols, args.rows, args.quality):
            print("wrote %s" % p.as_posix())
        if args.after:
            for p in compare_sheets(before, after, (args.before.name, target.name), out, args.rows, args.quality):
                print("wrote %s" % p.as_posix())

    if args.gates:
        gates = json.loads(args.gates.read_text(encoding="utf-8"))
        ok = check_gates(gates, report, before_stats)
        print("gates: %s" % ("PASS" if ok else "FAIL"))
        return 0 if ok else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
