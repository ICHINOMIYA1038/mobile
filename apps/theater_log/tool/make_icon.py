"""アプリアイコンを作る。 uv run --with pillow python tool/make_icon.py"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 3  # 大きく描いて縮め、線をなめらかにする
NAVY, PAPER, RED = (31, 47, 74), (247, 242, 232), (184, 58, 38)
S = SIZE * SCALE


def line(d, points, width, fill):
    pts = [(x * SCALE, y * SCALE) for x, y in points]
    w = width * SCALE
    d.line(pts, fill=fill, width=w, joint="curve")
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=fill)


img = Image.new("RGB", (S, S), NAVY)
d = ImageDraw.Draw(img)
# 切り込みのある半券
top, bottom, tear = 262 * SCALE, 762 * SCALE, 262 * SCALE
d.rounded_rectangle([70 * SCALE, top, 954 * SCALE, bottom], radius=44 * SCALE, fill=PAPER)
for cy in (top, bottom):
    d.ellipse([tear - 44 * SCALE, cy - 44 * SCALE, tear + 44 * SCALE, cy + 44 * SCALE], fill=NAVY)
for y in range(top + 70 * SCALE, bottom - 60 * SCALE, 54 * SCALE):
    d.rectangle([tear - 6 * SCALE, y, tear + 6 * SCALE, y + 28 * SCALE], fill=NAVY)

# 押されたハンコ。文字はフォントを使わず線で描く
seal = Image.new("RGBA", (S, S), (0, 0, 0, 0))
g = ImageDraw.Draw(seal)
cx, cy, r = 590, 512, 350
g.ellipse([(cx - r) * SCALE, (cy - r) * SCALE, (cx + r) * SCALE, (cy + r) * SCALE], fill=RED)
ring = r - 30
g.ellipse([(cx - ring) * SCALE, (cy - ring) * SCALE, (cx + ring) * SCALE, (cy + ring) * SCALE], outline=PAPER, width=14 * SCALE)
W = 46
# ポ
line(g, [(360, 440), (560, 440)], W, PAPER)
line(g, [(460, 370), (460, 650)], W, PAPER)
line(g, [(392, 520), (352, 610)], W, PAPER)
line(g, [(528, 520), (568, 610)], W, PAPER)
g.ellipse([(562) * SCALE, (345) * SCALE, (622) * SCALE, (405) * SCALE], outline=PAPER, width=16 * SCALE)
# ン
line(g, [(660, 408), (722, 452)], W, PAPER)
p0, p1, p2 = (650, 630), (790, 600), (830, 450)
line(g, [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]) for t in [i / 24 for i in range(25)]], W, PAPER)
seal = seal.rotate(14, resample=Image.BICUBIC, center=(cx * SCALE, cy * SCALE))
img.paste(seal, (0, 0), seal)
img = img.resize((SIZE, SIZE), Image.LANCZOS)
out = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
for e in json.loads((out / "Contents.json").read_text())["images"]:
    px = round(float(e["size"].split("x")[0]) * int(e["scale"].rstrip("x")))
    img.resize((px, px), Image.LANCZOS).save(out / e["filename"], "PNG")
img.save("tool/icon_1024.png", "PNG")
