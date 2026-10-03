#!/usr/bin/env python3
"""Generates the platform branding derivatives from the approved Cheetah icon.

Run from the repository root:  python3 tool/branding/generate_derivatives.py

Inputs are never modified. The approved PNG is a 4x raster of the approved
SVG (2032 = 4 x 508), so derivatives are taken from it rather than re-drawing
the SVG path: that keeps the approved frame clip, including the deliberate
left-edge bleed, and never exposes the path's hidden off-canvas portion.
Requires Pillow.
"""

from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/branding/cheetah_app_icon.png"
OUT = ROOT / "assets/branding/generated"

BLUE = (0x4F, 0x7E, 0xB4)


def opaque_master(icon: Image.Image) -> Image.Image:
    # Composite the whole icon so anti-aliased corner pixels blend into the
    # field instead of leaving a half-transparent ring.
    canvas = Image.new("RGBA", icon.size, BLUE + (255,))
    canvas.alpha_composite(icon)
    return canvas.convert("RGB")


def white_silhouette(icon: Image.Image) -> Image.Image:
    # Each pixel is a blend of the blue field and the white Cheetah; recover
    # the white coverage from the red channel (79 = field, 255 = Cheetah).
    red, _, _, alpha = icon.split()
    coverage = red.point(
        lambda v: max(0, min(255, round((v - BLUE[0]) * 255 / (255 - BLUE[0]))))
    )
    mask = ImageChops.multiply(coverage, alpha)
    silhouette = Image.new("RGBA", icon.size, (255, 255, 255, 0))
    silhouette.putalpha(mask)
    return silhouette


def adaptive_foreground(icon: Image.Image) -> Image.Image:
    # 108dp canvas at 1024 px; the approved frame fills the centred 72dp
    # viewport (2/3 of the canvas) so the bleed meets the launcher mask.
    canvas_size = 1024
    viewport = round(canvas_size * 2 / 3)  # 683
    offset = (canvas_size - viewport) // 2  # 170
    frame = white_silhouette(icon).resize((viewport, viewport), Image.LANCZOS)
    # Resampling can ring slightly; keep pure white colour channels.
    white = Image.new("RGBA", frame.size, (255, 255, 255, 0))
    white.putalpha(frame.getchannel("A"))
    frame = white
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (255, 255, 255, 0))
    canvas.paste(frame, (offset, offset))
    return canvas


def centred(icon: Image.Image, canvas_size: int, icon_size: int) -> Image.Image:
    scaled = icon.resize((icon_size, icon_size), Image.LANCZOS)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    offset = (canvas_size - icon_size) // 2
    canvas.alpha_composite(scaled, (offset, offset))
    return canvas


def main() -> None:
    icon = Image.open(SOURCE).convert("RGBA")
    assert icon.size == (2032, 2032), icon.size
    OUT.mkdir(parents=True, exist_ok=True)
    opaque_master(icon).save(OUT / "cheetah_app_icon_opaque.png", optimize=True)
    adaptive_foreground(icon).save(OUT / "cheetah_adaptive_foreground.png", optimize=True)
    # Pre-Android-12 and iOS splash: treated as a 4x image (200dp canvas,
    # 120dp icon) by flutter_native_splash.
    centred(icon, 800, 480).save(OUT / "cheetah_splash.png", optimize=True)
    # Android 12+: the icon is shown inside a circle of 2/3 the canvas
    # (768 px); a 528 px square keeps its corners inside (max 768 x 0.707).
    centred(icon, 1152, 528).save(OUT / "cheetah_splash_android12.png", optimize=True)


if __name__ == "__main__":
    main()
