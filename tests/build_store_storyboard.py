"""Assemble 11 revised beats plus two failure-state reviews from Godot."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / "artifacts" / "storyboard"
sheet = Image.new("RGB", (1920, 1900), "#172322")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 30)
draw.text((24, 12), "1848 / MILESTONE 10 — STORYBOARD REVISION 2 / REVIEW GATE", font=font, fill="#ebe7d9")
for number in range(1, 14):
    source = Image.open(folder / f"storyboard-{number:02d}.png").convert("RGB")
    assert source.size == (1920, 1080)
    source.thumbnail((624, 351), Image.Resampling.LANCZOS)
    sheet.paste(source, (12 + ((number - 1) % 3) * 640, 66 + ((number - 1) // 3) * 365))
draw.multiline_text((660, 1550), "11 beats + 2 failure states\nNamed focus and review cameras\nHands and smoke are greybox poses\nPrices come from the pure model\nApproval still pending", font=font, fill="#ebe7d9", spacing=9)
sheet.save(folder / "storyboard-sheet.png")
sheet.save(folder / "storyboard-sheet-r2.png")
# Also provide a compact supplemental sheet for the two failure cases.
failures = Image.new("RGB", (1920, 620), "#172322")
fd = ImageDraw.Draw(failures)
fd.text((24, 12), "SUPPLEMENTAL REVIEW / SHORT AND SOLD OUT", font=font, fill="#ebe7d9")
for i, number in enumerate((12, 13)):
    frame = Image.open(folder / f"storyboard-{number:02d}.png").convert("RGB")
    frame.thumbnail((944, 531), Image.Resampling.LANCZOS)
    failures.paste(frame, (8 + i * 960, 70))
failures.save(folder / "failure-sheet.png")
print(folder / "storyboard-sheet.png")
