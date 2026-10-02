"""Repaint Kelgar's CC0 "Undead Squirrel" coat as a healthy western gray squirrel.

  python tools/art/repaint_squirrel.py <unpacked source dir> <out dir> [--preview]

Procedural, deterministic texture edits only (no sculpting). Inputs are the source's
`squirrel-head.png` and `squirrel-body.png` (1024, sha-pinned in assets/CC0_MANIFEST.json,
row opengameart:undead-squirrel-animated:undeadsquirrell.zip). Steps:

  1. Mask the undead paint: dried blood (dark saturated red), rotting flesh (olive and
     grey-green: green at or above red) and raw flesh (pink: blue at or above green with
     red well above both). The UV background colour and the alpha-cut ear-hair card are
     left alone. Masks are dilated so no rim of blood survives the fill.
  2. Fill the masked areas from the surrounding fur (OpenCV Telea inpainting, then a
     fine Navier-Stokes pass), and add back fur grain: the high-pass luminance of a
     clean strip of the source's own fur, tiled across the filled areas.
  3. Recolour the fur by its own luminance: the orange back and tail become silver grey
     (the fur's light/dark variation is kept as salt-and-pepper), the cream underparts
     white; a slight warm cast stays on the grey as on the real animal.
  4. Paint the two eye sockets (fixed texel centres measured on this source) as large
     dark eyes with a thin pale eye ring, which the western gray squirrel has.

Writes head.png and body.png (RGB, alpha copied) to <out dir>; --preview also writes
masks for review.
"""
import argparse
from pathlib import Path

import cv2
import numpy as np

EYES = [(395, 657), (625, 662)]   # texel centres of the two sockets in squirrel-head.png
EYE_RADIUS = 25                    # dark eye
RING = 6                           # pale eye ring outside it
SOCKET = 46                        # socket paint radius (rotting flesh around the eye)
GREY = np.array([0.53, 0.52, 0.50], np.float32)    # sRGB mean of the back fur
WHITE = np.array([0.86, 0.85, 0.82], np.float32)   # underparts
EYE = np.array([0.035, 0.03, 0.028], np.float32)
EYE_RING = np.array([0.80, 0.79, 0.76], np.float32)
BACKGROUND = np.array([0.663, 0.345, 0.114], np.float32)  # flat UV padding colour


def masks(rgb, alpha):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hsv = cv2.cvtColor((rgb * 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    hue, s, v = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255   # hue in degrees
    red = (hue < 14) | (hue > 340)
    # The fur is orange (hue 18-35, saturated); blood is crimson, rot is olive, flesh pink.
    blood = red & (s > 0.55) & (v < 0.72)
    rot = (g >= r * 0.97) & (hue > 44) & (hue < 110) & (s > 0.12) & (v > 0.15)
    flesh = red & (s > 0.12) & (s <= 0.55) & (v > 0.32)
    bad = (blood | rot | flesh) & (alpha > 0.5)
    pad = np.abs(rgb - BACKGROUND).max(axis=2) < 0.02
    bad &= ~pad
    bad = cv2.dilate(bad.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
    return bad.astype(bool), pad


def fill(rgb, bad):
    img = (rgb * 255).astype(np.uint8)
    m = bad.astype(np.uint8) * 255
    out = cv2.inpaint(img, m, 21, cv2.INPAINT_TELEA)
    # A second, finer pass re-seeds texture from the nearest real fur.
    out = cv2.inpaint(out, cv2.erode(m, np.ones((5, 5), np.uint8)), 5, cv2.INPAINT_NS)
    return out.astype(np.float32) / 255


def regrain(filled, original, bad, pad):
    """Inpainting leaves smooth smears; add back fur grain (the high-pass luminance of
    the cleanest 64-texel patch of the source's own orange fur, mirror-tiled) inside the
    filled areas."""
    lum = cv2.cvtColor((original * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32) / 255
    detail = lum - cv2.GaussianBlur(lum, (0, 0), 3)
    hsv = cv2.cvtColor((original * 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    fur = ((hsv[..., 0] * 2 > 16) & (hsv[..., 0] * 2 < 40) & (hsv[..., 1] > 115) & ~bad & ~pad).astype(np.float32)
    k = 64
    cover = cv2.boxFilter(fur, -1, (k, k), normalize=True)
    y, x = np.unravel_index(int(np.argmax(cover[k // 2:-k // 2, k // 2:-k // 2])), cover[k // 2:-k // 2, k // 2:-k // 2].shape)
    patch = detail[y:y + k, x:x + k]
    tile = np.block([[patch, patch[:, ::-1]], [patch[::-1], patch[::-1, ::-1]]])
    h, w = filled.shape[:2]
    tiled = np.tile(tile, (h // tile.shape[0] + 1, w // tile.shape[1] + 1))[:h, :w]
    soft = cv2.GaussianBlur(bad.astype(np.float32), (0, 0), 2)
    return np.clip(filled + (tiled * 1.2 * soft)[..., None], 0, 1)


def recolour(rgb, pad):
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    lum = lin @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    hsv = cv2.cvtColor((rgb * 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    sat = hsv[..., 1] / 255
    fur = ~pad
    ref = float(np.median(lum[fur & (sat > 0.45)]))
    rel = np.clip(lum / max(ref, 1e-4), 0.25, 2.2)[..., None]
    # Cream underparts are the low-saturation, bright fur in the source.
    pale = np.clip((0.32 - sat) / 0.14, 0, 1) * np.clip((lum - ref * 1.1) / (ref * 0.7), 0, 1)
    grey = np.clip(GREY * rel ** 0.85, 0, 1)
    white = np.clip(WHITE * (0.82 + 0.18 * np.clip(rel, 0, 1.4)), 0, 1)
    out = grey * (1 - pale[..., None]) + white * pale[..., None]
    out[pad] = GREY
    return out


def eyes(rgb):
    h, w = rgb.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for cx, cy in EYES:
        d = np.hypot(xx - cx, yy - cy)
        ring = np.clip((EYE_RADIUS + RING + 1.5 - d) / 3, 0, 1)
        rgb[:] = rgb * (1 - ring[..., None]) + EYE_RING * ring[..., None]
        eye = np.clip((EYE_RADIUS + 1.5 - d) / 3, 0, 1)
        rgb[:] = rgb * (1 - eye[..., None]) + EYE * eye[..., None]
    return rgb


def process(src: Path, name: str, out: Path, head: bool, preview: bool):
    raw = cv2.imread(str(src / name), cv2.IMREAD_UNCHANGED)
    alpha = raw[..., 3].astype(np.float32) / 255 if raw.shape[2] == 4 else np.ones(raw.shape[:2], np.float32)
    rgb = cv2.cvtColor(raw[..., :3], cv2.COLOR_BGR2RGB).astype(np.float32) / 255
    bad, pad = masks(rgb, alpha)
    if head:
        h, w = bad.shape
        yy, xx = np.mgrid[0:h, 0:w]
        for cx, cy in EYES:
            bad |= np.hypot(xx - cx, yy - cy) < SOCKET
    filled = regrain(fill(rgb, bad), rgb, bad, pad)
    result = recolour(filled, pad)
    if head:
        result = eyes(result)
    bgr = cv2.cvtColor((np.clip(result, 0, 1) * 255 + 0.5).astype(np.uint8), cv2.COLOR_RGB2BGR)
    if raw.shape[2] == 4:
        bgr = np.dstack([bgr, raw[..., 3]])
    target = out / ("head.png" if head else "body.png")
    cv2.imwrite(str(target), bgr)
    if preview:
        cv2.imwrite(str(out / ("mask_" + target.name)), (bad * 255).astype(np.uint8))
    print("%s: %.1f%% repainted -> %s" % (name, 100 * bad[~pad].mean(), target))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--preview", action="store_true")
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    process(a.src, "squirrel-head.png", a.out, True, a.preview)
    process(a.src, "squirrel-body.png", a.out, False, a.preview)


if __name__ == "__main__":
    main()
