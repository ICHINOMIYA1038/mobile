"""ストア用の画像を作る。 uv run --with pillow python tool/store_compose.py
tool/raw の画面は iPhone 16 Pro Max で integration_test/flow_test.dart を流して撮る。"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 1320, 2868
NAVY, PAPER, RED = (31, 47, 74), (247, 242, 232), (184, 58, 38)
FONT = "/System/Library/Fonts/ヒラギノ明朝 ProN.ttc"
SLOTS = [
    ("1_search", "人数と時間で", "上演する台本を探す", "1,300 作品以上"),
    ("2_play", "上演に必要な情報を", "1 画面で確かめる", "人数・時間・掲載先"),
    ("3_shortlist", "候補を比べて", "仲間に共有する", "部員や劇団で決められる"),
]
big = ImageFont.truetype(FONT, 118, index=1)
badge_font = ImageFont.truetype(FONT, 50, index=1)


def centered(d, y, text, font, fill):
    box = d.textbbox((0, 0), text, font=font)
    d.text(((W - (box[2] - box[0])) / 2 - box[0], y), text, font=font, fill=fill)


for name, l1, l2, badge in SLOTS:
    img = Image.new("RGB", (W, H), NAVY)
    d = ImageDraw.Draw(img)
    box = d.textbbox((0, 0), badge, font=badge_font)
    bw = box[2] - box[0] + 72
    d.rounded_rectangle([(W - bw) / 2, 120, (W + bw) / 2, 210], radius=45, fill=RED)
    centered(d, 136, badge, badge_font, PAPER)
    centered(d, 262, l1, big, PAPER)
    centered(d, 410, l2, big, PAPER)
    shot = Image.open(f"tool/raw/{name}.png").convert("RGB")
    sw = 1120
    shot = shot.resize((sw, round(shot.height * sw / shot.width)), Image.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width, shot.height], radius=72, fill=255)
    img.paste(shot, ((W - sw) // 2, 610), mask)
    img.save(Path("docs/screenshots") / f"{name}.png", "PNG")
