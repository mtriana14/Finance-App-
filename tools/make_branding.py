"""Generates Libreta's app-identity artwork.

Run from a venv outside the Flutter project:
    artvenv/bin/python make_branding.py <output_dir>

THE MARK
    A ledger: a portrait page with a margin rule down the left and three
    written lines, the last one short. Everything is knocked out of a single
    solid body rather than stroked, so the shape survives being scaled down to
    a 48dp launcher icon — thin strokes are the usual way an icon that looks
    fine at 1024px turns to mush on a home screen. The knockouts fall through
    to the adaptive background colour, which is why the same drawing routine
    produces the transparent, opaque and monochrome variants.

THE SAFE ZONE
    Android composites an adaptive foreground on a 108dp canvas and guarantees
    only the centred 66dp; OEM masks (circle, squircle, teardrop) crop the
    rest. On a 1024px canvas that is 626px across — a 624px centred square,
    bounds [200, 200, 824, 824], with 200px clear on every side.

    That square is the usual shorthand and it is not sufficient. The guarantee
    is a 66dp *circle*, and the corners of a 66dp square fall outside it, so a
    mark sized to the square gets its left and right edges shaved off by every
    circular-mask launcher — which is most Pixels. What has to fit is the
    circle: the mark's half-diagonal must not exceed its 313px radius. That is
    what ADAPTIVE_SCALE below computes, from the body geometry rather than from
    a number typed in by hand.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

CANVAS = 1024
SUPERSAMPLE = 4  # Pillow does not antialias shapes; draw big, then downsample.

# Adaptive-icon safe zone, in 1024px canvas units.
SAFE_INSET = 200
SAFE_BOX = (SAFE_INSET, SAFE_INSET, CANVAS - SAFE_INSET, CANVAS - SAFE_INSET)

# --- Base geometry, all inside SAFE_BOX -----------------------------------
BODY = (267, 212, 757, 812)
BODY_RADIUS = 54
MARGIN_RULE = (355, 262, 411, 762)
MARGIN_RULE_RADIUS = 28
LINE_LEFT, LINE_RIGHT = 471, 693
LINE_HEIGHT = 72
LINE_TOPS = (326, 476, 626)
LAST_LINE_WIDTH = 130

# Radius of the guaranteed-visible circle, in 1024px canvas units.
SAFE_CIRCLE_RADIUS = 66 / 108 * CANVAS / 2

# The body is the outermost shape, so its half-diagonal is the mark's.
_BODY_HALF_DIAGONAL = math.hypot(BODY[2] - BODY[0], BODY[3] - BODY[1]) / 2

# 0.98 leaves a pixel of slack for the antialiasing spread of the downsample.
ADAPTIVE_SCALE = round(SAFE_CIRCLE_RADIUS / _BODY_HALF_DIAGONAL * 0.98, 4)

# Per-output scaling about the canvas centre.
SCALES = {
    # Sized so the mark clears a circular mask, not merely the safe square.
    "icon_foreground": ADAPTIVE_SCALE,
    "icon_monochrome": ADAPTIVE_SCALE,
    # A legacy icon is not adaptive-cropped, so it can fill more of the tile.
    "icon_legacy": 1.25,
    # Android 12 masks the splash icon to a circle: the mark's diagonal has to
    # fit inside it, which a full-size square mark would not.
    "splash_logo": 0.82,
}

CENTRE = CANVAS / 2


def scaled(box, scale):
    """Scales a box about the canvas centre, in supersampled pixels."""
    return tuple(
        round((CENTRE + (value - CENTRE) * scale) * SUPERSAMPLE) for value in box
    )


def draw_mark(image, mark_color, knockout_color, scale):
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        scaled(BODY, scale),
        radius=round(BODY_RADIUS * scale * SUPERSAMPLE),
        fill=mark_color,
    )
    draw.rounded_rectangle(
        scaled(MARGIN_RULE, scale),
        radius=round(MARGIN_RULE_RADIUS * scale * SUPERSAMPLE),
        fill=knockout_color,
    )
    for index, top in enumerate(LINE_TOPS):
        is_last = index == len(LINE_TOPS) - 1
        right = LINE_LEFT + LAST_LINE_WIDTH if is_last else LINE_RIGHT
        draw.rounded_rectangle(
            scaled((LINE_LEFT, top, right, top + LINE_HEIGHT), scale),
            radius=round((LINE_HEIGHT / 2) * scale * SUPERSAMPLE),
            fill=knockout_color,
        )


def render(path, mark_color, background, scale):
    """`background` None means transparent; knockouts fall through to it."""
    transparent = (0, 0, 0, 0)
    base = background or transparent
    image = Image.new("RGBA", (CANVAS * SUPERSAMPLE,) * 2, base)
    draw_mark(image, mark_color, base, scale)
    image.resize((CANVAS, CANVAS), Image.LANCZOS).save(path, "PNG")
    print(f"  {path.name}")


def rgb(hex_color):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def build(out_dir, mark_hex, background_hex, label):
    out_dir.mkdir(parents=True, exist_ok=True)
    mark = rgb(mark_hex)
    background = rgb(background_hex)
    print(f"{label}: mark {mark_hex} on {background_hex} -> {out_dir}")
    render(out_dir / "icon_foreground.png", mark, None, SCALES["icon_foreground"])
    render(out_dir / "icon_legacy.png", mark, background, SCALES["icon_legacy"])
    render(out_dir / "icon_monochrome.png", (255, 255, 255, 255), None,
           SCALES["icon_monochrome"])
    render(out_dir / "splash_logo.png", mark, None, SCALES["splash_logo"])


if __name__ == "__main__":
    root = Path(sys.argv[1])
    print(f"Safe square {SAFE_BOX} ({SAFE_BOX[2] - SAFE_BOX[0]}px)")
    print(f"Safe circle radius {SAFE_CIRCLE_RADIUS:.0f}px "
          f"-> adaptive scale {ADAPTIVE_SCALE}\n")
    # Active set: the palette this session specified.
    build(root, "#C8F94B", "#08090B", "spec palette")
    print()
    # Comparison set: the app's own dark-theme colours, for judging on device.
    build(root / "alt", "#3DBB7A", "#14171C", "app palette")
