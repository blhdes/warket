#!/usr/bin/env python3
"""Builds every warket mark file from the workshop line (Session 8b, 2026-11-18).

    mark=A ring=0.310 rim=0.075 tick=0.070 stroke=0.045 key=0 dot=0.070
    caps=round accent=#3CC4B3 bg=#2A9D8F ink=#08090D pad=0.10

Direction A, "Dial": a safe's dial with twelve notches, one in colour. Your
12 words, one key. Workshop: https://claude.ai/artifact/TFD8q1ZfsXZp5Epb1wBUcK

Sizes are fractions of the 1024 canvas (ring and dot are radii). The geometry
copies the workshop's drawing code exactly. Strokes are turned into filled
outlines, so every file holds filled shapes only (Icon Composer wants that).

Run from the repo root:  python3 design/build-mark.py
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESIGN = ROOT / "design"
IOS = ROOT / "warket-ios/warket"
ASSETS = IOS / "Assets.xcassets"
ICON_ASSETS = IOS / "AppIcon.icon/Assets"

# The line, as numbers.
U, C = 1024, 512
RING, RIM, TICK, STROKE, KEY, DOT, PAD = 0.310, 0.075, 0.070, 0.045, 0, 0.070, 0.10
ACCENT, BG, INK = "#3CC4B3", "#2A9D8F", "#08090D"

R, RW, T, W, D = RING * U, RIM * U, TICK * U, STROKE * U, DOT * U
# Notches hang inside the rim, like the markings on a safe's dial.
OUTER = R - RW / 2 - 0.035 * U - W / 2
INNER = max(0.0, OUTER - T)
EXTENT = R + RW / 2  # half the width of the whole mark


def n(v: float) -> str:
    return f"{round(v, 2):g}"


def xy(r: float, deg: float) -> tuple[float, float]:
    a = math.radians(deg)
    return C + r * math.cos(a), C + r * math.sin(a)


def circle(r: float, clockwise: bool = True) -> str:
    sweep = 1 if clockwise else 0
    return (
        f"M{n(C - r)} {C}A{n(r)} {n(r)} 0 1 {sweep} {n(C + r)} {C}"
        f"A{n(r)} {n(r)} 0 1 {sweep} {n(C - r)} {C}Z"
    )


def notch(i: int) -> str:
    """A line with round ends from INNER to OUTER, as a filled stadium."""
    deg = -90 + i * 30  # 0 is the top notch, then clockwise
    ux, uy = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    px, py = -uy * W / 2, ux * W / 2  # half the width, across the line
    x0, y0 = xy(INNER, deg)
    x1, y1 = xy(OUTER, deg)
    h = W / 2
    return (
        f"M{n(x0 + px)} {n(y0 + py)}L{n(x1 + px)} {n(y1 + py)}"
        f"A{n(h)} {n(h)} 0 0 0 {n(x1 - px)} {n(y1 - py)}"
        f"L{n(x0 - px)} {n(y0 - py)}"
        f"A{n(h)} {n(h)} 0 0 0 {n(x0 + px)} {n(y0 + py)}Z"
    )


# The rim is a ring: the outer circle one way, the inner circle the other way,
# so it stays hollow under both fill rules.
RIM_PATH = circle(R + RW / 2) + circle(R - RW / 2, clockwise=False)
NOTCHES = "".join(notch(i) for i in range(12) if i != KEY)
DIAL_PATH = RIM_PATH + NOTCHES + circle(D)  # everything in ink
KEY_PATH = notch(KEY)  # the one notch in the accent colour

# In-app crop: the mark plus PAD of empty margin on each side.
HALF = EXTENT / (1 - 2 * PAD)
CROP = f"{n(C - HALF)} {n(C - HALF)} {n(2 * HALF)} {n(2 * HALF)}"
CROPPED = 2 * HALF
FULL = f"0 0 {U} {U}"


def svg(view_box: str, size: float, *paths: tuple[str, str], under: str = "") -> str:
    body = "".join(f'\n  <path fill="{fill}" d="{d}"/>' for fill, d in paths)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{n(size)}" height="{n(size)}" '
        f'viewBox="{view_box}">{under}{body}\n</svg>\n'
    )


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    print("wrote", path.relative_to(ROOT))


def image_set(name: str, svg_name: str, svg_text: str, template: bool) -> None:
    folder = ASSETS / f"{name}.imageset"
    write(folder / svg_name, svg_text)
    contents = {
        "images": [{"filename": svg_name, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {
            "preserves-vector-representation": True,
            "template-rendering-intent": "template" if template else "original",
        },
    }
    write(folder / "Contents.json", json.dumps(contents, indent=2, separators=(",", " : ")) + "\n")


# Icon Composer layers: full 1024 canvas, back to front. The background (BG)
# is a fill colour in AppIcon.icon/icon.json, not a file.
for name, fill, d in (("1-dial.svg", INK, DIAL_PATH), ("2-key.svg", ACCENT, KEY_PATH)):
    write(DESIGN / "icon-layers" / name, svg(FULL, U, (fill, d)))
    write(ICON_ASSETS / name, svg(FULL, U, (fill, d)))

# Masters for everything else (store, docs).
write(DESIGN / "warket-mark.svg", svg(CROP, CROPPED, ("#000000", DIAL_PATH), ("#000000", KEY_PATH)))
write(DESIGN / "warket-mark-color.svg", svg(CROP, CROPPED, ("#000000", DIAL_PATH), (ACCENT, KEY_PATH)))

# In-app: two layers sharing one crop so they stack exactly. The dial is a
# template (follows the text colour); the key keeps its colour.
image_set("WarketMarkDial", "warket-mark-dial.svg", svg(CROP, CROPPED, ("#000000", DIAL_PATH)), template=True)
image_set("WarketMarkKey", "warket-mark-key.svg", svg(CROP, CROPPED, (ACCENT, KEY_PATH)), template=False)

# Website: the vector favicon is the app icon, square tile with rounded corners.
radius = 0.225 * U
tile = f'\n  <rect width="{U}" height="{U}" rx="{n(radius)}" fill="{BG}"/>'
write(ROOT / "public/favicon.svg", svg(FULL, 64, (INK, DIAL_PATH), (ACCENT, KEY_PATH), under=tile))

# Flat, full-bleed icon (no glass, square corners) for the home-screen icons of
# the website: iOS and Android round the corners themselves.
square = f'\n  <rect width="{U}" height="{U}" fill="{BG}"/>'
write(DESIGN / "app-icon-flat.svg", svg(FULL, U, (INK, DIAL_PATH), (ACCENT, KEY_PATH), under=square))

# Website: the same paths for the React Logo component.
ts = (
    "// Generated by design/build-mark.py from the workshop line. Do not edit by hand.\n"
    f"export const MARK_VIEW_BOX = '{CROP}'\n"
    f"export const MARK_DIAL_PATH = '{DIAL_PATH}'\n"
    f"export const MARK_KEY_PATH = '{KEY_PATH}'\n"
    f"export const MARK_ACCENT = '{ACCENT}'\n"
)
write(ROOT / "src/components/logoMark.ts", ts)
