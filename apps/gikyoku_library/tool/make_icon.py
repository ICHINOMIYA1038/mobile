"""アプリアイコンを作る。 uv run --with pillow python tool/make_icon.py"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/ヒラギノ明朝 ProN.ttc"
SIZE = 1024
NAVY, PAPER, RED = (31, 47, 74), (247, 242, 232), (184, 58, 38)

img = Image.new("RGB", (SIZE, SIZE), NAVY)
d = ImageDraw.Draw(img)
# 本の背を思わせる帯と、開いた台本のページ
d.rectangle([0, 790, SIZE, SIZE], fill=RED)
d.rounded_rectangle([190, 130, 834, 900], radius=26, fill=PAPER)
font = ImageFont.truetype(FONT, 470, index=1)
box = d.textbbox((0, 0), "戯", font=font)
d.text(((SIZE - (box[2] - box[0])) / 2 - box[0], 200 - box[1]), "戯", font=font, fill=NAVY)
d.rounded_rectangle([660, 720, 780, 840], radius=14, fill=RED)

out = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
for entry in json.loads((out / "Contents.json").read_text())["images"]:
    pts = float(entry["size"].split("x")[0])
    scale = int(entry["scale"].rstrip("x"))
    px = round(pts * scale)
    img.resize((px, px), Image.LANCZOS).save(out / entry["filename"], "PNG")
img.save("tool/icon_1024.png", "PNG")
