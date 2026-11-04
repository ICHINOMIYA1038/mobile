"""アプリアイコンを作る。 uv run --with pillow python tool/make_icon.py"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
NAVY, PAPER, RED = (31, 47, 74), (247, 242, 232), (184, 58, 38)
img = Image.new("RGB", (SIZE, SIZE), NAVY)
d = ImageDraw.Draw(img)
# 切り込みのある半券と、切り取り線
top, bottom = 230, 794
d.rounded_rectangle([110, top, 914, bottom], radius=48, fill=RED)
d.rounded_rectangle([340, top, 914, bottom], radius=48, fill=PAPER)
d.rectangle([340, top, 400, bottom], fill=PAPER)
for cy in (top, bottom):
    d.ellipse([340 - 46, cy - 46, 340 + 46, cy + 46], fill=NAVY)
for y in range(top + 66, bottom - 60, 52):
    d.rectangle([334, y, 346, y + 28], fill=NAVY)
# スタンプ
d.ellipse([470, 330, 830, 690], outline=RED, width=30)
d.line([(560, 515), (635, 590), (755, 440)], fill=RED, width=38, joint="curve")
out = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
for e in json.loads((out / "Contents.json").read_text())["images"]:
    px = round(float(e["size"].split("x")[0]) * int(e["scale"].rstrip("x")))
    img.resize((px, px), Image.LANCZOS).save(out / e["filename"], "PNG")
img.save("tool/icon_1024.png", "PNG")
