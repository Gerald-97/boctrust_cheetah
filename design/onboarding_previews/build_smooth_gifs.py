"""Build steady, gently animated previews from the approved onboarding art."""

from pathlib import Path
import math

from PIL import Image


HERE = Path(__file__).resolve().parent
BACKGROUND = (246, 244, 238, 255)
FRAME_COUNT = 48
FRAME_MS = 40
OUTPUT_SIZE = 600
ART_SIZE = 505

# Only these small floating motifs move. The characters and the crop stay fixed.
ASSETS = (
    ("01-save-afro", ((145, 250, 365, 500, 0.3), (925, 260, 1170, 520, 1.5))),
    (
        "02-goals-afro",
        (
            (65, 220, 320, 475, 0.2),
            (845, 135, 1230, 460, 1.5),
            (125, 530, 290, 765, 2.2),
            (995, 720, 1230, 970, 0.9),
        ),
    ),
    ("03-pay-afro", ((165, 245, 405, 500, 0.4), (875, 360, 1135, 610, 1.5))),
)


def render(name, regions):
    original = Image.open(HERE / f"{name}-master.png").convert("RGBA")
    fixed_crop = original.getchannel("A").getbbox()
    body = original.copy()
    motifs = []
    for left, top, right, bottom, phase_offset in regions:
        motifs.append((original.crop((left, top, right, bottom)), left, top, phase_offset))
        body.paste((0, 0, 0, 0), (left, top, right, bottom))

    frames = []
    for index in range(FRAME_COUNT):
        phase = 2 * math.pi * index / FRAME_COUNT
        art = body.copy()
        for motif, x, y, offset in motifs:
            # A small, periodic motion brings the symbols to rest at each turn.
            dy = round(7 * math.sin(phase + offset))
            art.alpha_composite(motif, (x, y + dy))

        art = art.crop(fixed_crop)
        art.thumbnail((ART_SIZE, ART_SIZE), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), BACKGROUND)
        canvas.alpha_composite(
            art, ((OUTPUT_SIZE - art.width) // 2, (OUTPUT_SIZE - art.height) // 2)
        )
        frames.append(canvas.convert("RGB"))

    palette = frames[0].quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    indexed = [
        frame.quantize(palette=palette, dither=Image.Dither.NONE)
        for frame in frames
    ]
    gif_path = HERE / f"{name}-smooth-preview.gif"
    indexed[0].save(
        gif_path,
        save_all=True,
        append_images=indexed[1:],
        duration=FRAME_MS,
        loop=0,
        optimize=True,
        disposal=2,
    )
    frames[0].save(HERE / f"{name}-smooth-preview.png")
    return gif_path


if __name__ == "__main__":
    for asset in ASSETS:
        print(render(*asset))
