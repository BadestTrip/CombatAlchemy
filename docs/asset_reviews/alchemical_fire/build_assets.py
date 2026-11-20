"""Extract four native flame cells from the built-in ImageGen source.

Run from repository root with Pillow. Binary alpha and a three-color ramp
remove source antialiasing; shared scale and base anchor prevent frame jumps.
"""
from pathlib import Path
import json
from PIL import Image

review = Path("docs/asset_reviews/alchemical_fire")
out = Path("sprites/vfx/alchemical_fire")
out.mkdir(parents=True, exist_ok=True)
source = Image.open(review / "imagegen_source.png").convert("RGBA")
palette = [(0, 94, 116), (41, 217, 255), (240, 240, 240)]
parts = []
for index in range(4):
    part = source.crop((index * source.width // 4, 0, (index + 1) * source.width // 4, source.height))
    part.putalpha(part.getchannel("A").point(lambda value: 255 if value >= 200 else 0))
    bounds = part.getbbox()
    assert bounds, "Empty generated frame"
    parts.append(part.crop(bounds))
factor = 12 / max(part.height for part in parts)
sheet = Image.new("RGBA", (64, 16))
for index, part in enumerate(parts):
    small = part.resize((max(1, round(part.width * factor)), max(1, round(part.height * factor))), Image.Resampling.NEAREST)
    pixels = small.load()
    for y in range(small.height):
        for x in range(small.width):
            red, green, blue, alpha = pixels[x, y]
            if not alpha:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            color = min(palette, key=lambda c: sum((a - b) ** 2 for a, b in zip(c, (red, green, blue))))
            pixels[x, y] = (*color, 255)
    frame = Image.new("RGBA", (16, 16))
    frame.paste(small, ((16 - small.width) // 2, 14 - small.height))
    # Two stable base pixels preserve the burner contact through the loop.
    frame.putpixel((7, 13), (*palette[0], 255))
    frame.putpixel((8, 13), (*palette[0], 255))
    assert frame.getbbox()[3] == 14
    assert all(frame.getpixel(p)[3] == 0 for p in [(0, 0), (15, 0), (0, 15), (15, 15)])
    sheet.paste(frame, (index * 16, 0))
sheet.save(out / "alchemical_fire_v001.png")
sheet.resize((1024, 256), Image.Resampling.NEAREST).save(review / "alchemical_fire_review.png")
metadata = {"frame_size": [16, 16], "sheet_size": [64, 16], "frame_count": 4,
            "pivot": [8, 14], "frame_order": [0, 1, 2, 3], "loop": True,
            "fps_range": [4, 10], "display_scale": 3, "palette": ["#005E74", "#29D9FF", "#F0F0F0"]}
(out / "alchemical_fire_v001.json").write_text(json.dumps(metadata, indent=2) + "\n")
assert set(sheet.getchannel("A").getdata()) <= {0, 255}
print("Validated 64x16 RGBA, four nonempty anchored cells, binary alpha.")
