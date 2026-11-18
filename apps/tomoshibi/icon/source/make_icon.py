"""TOMOSHIBI小屋のアプリアイコン（1024×1024、角丸なし・透過なし・sRGB）を作る。

    python icon/source/make_icon.py          # apps/tomoshibi で実行
    dart run flutter_launcher_icons          # iOS / Android のアイコンに反映

墨の地に、提灯の印（骨の隙間で刻み、真ん中の段だけが金にずれる）と「舞台」「3D」、えんじの帯「シミュレータ」。
提灯の形の元データは tomoshibi リポジトリの design/icon/build.py（サイトの favicon・ヘッダーと同じ形）。
文字はヒラギノ角ゴ W9 の字形をパスにして SVG に埋め込む（takken_talk の icon/source/ship2.py と同じ方式）。
要るもの: fonttools（pip）、rsvg-convert と magick（Homebrew）。
出力: icon/source/icon.svg（元データ）、icon/icon.png、assets/icon/app_icon.png（flutter_launcher_icons の入力）。
"""
import os
import shutil
import subprocess

from fontTools.pens.recordingPen import RecordingPen
from fontTools.ttLib import TTCollection

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.abspath(os.path.join(HERE, "..", ".."))
FONTS = {w: TTCollection(f"/System/Library/Fonts/ヒラギノ角ゴシック W{w}.ttc").fonts[0] for w in (8, 9)}

INK = "#0E0B12"      # 墨の地
CREAM = "#F3E9D8"    # 提灯の胴と「舞台」
GOLD = "#F2B544"     # 灯る段と「3D」
RED = "#C8482D"      # アプリのテーマ色（lib/main.dart の seedColor）

# 提灯（viewBox 0 0 256 256）。外接は x 28.7〜232、y 12〜244
LANTERN_BODY = "M90 12 H146 V30 H90 Z M90 226 H146 V244 H90 Z M116.6 36 H119.4 A92 92 0 0 1 189.4 70 H46.6 A92 92 0 0 1 116.6 36 Z M38.3 82 H197.7 A92 92 0 0 1 207.3 106 H28.7 A92 92 0 0 1 38.3 82 Z M28.7 150 H207.3 A92 92 0 0 1 199.9 170 H36.1 A92 92 0 0 1 28.7 150 Z M43.5 182 H192.5 A92 92 0 0 1 119.4 220 H116.6 A92 92 0 0 1 43.5 182 Z "
LANTERN_LIT = "M48.5 118 H231.5 A92 92 0 0 1 231.5 138 H48.5 A92 92 0 0 1 48.5 118 Z "


def text_path(s, weight, size, cx, baseline, tracking=0.0):
    """文字列を、cx を中心にした SVG のパス（d 属性）にする。size は 1em のピクセル数。"""
    font = FONTS[weight]
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    k = size / font["head"].unitsPerEm
    names = [cmap[ord(ch)] for ch in s]
    total = sum(glyphs[n].width for n in names) * k + tracking * size * (len(s) - 1)
    x = cx - total / 2
    ops = {"moveTo": "M", "lineTo": "L", "qCurveTo": "Q", "curveTo": "C", "closePath": "Z", "endPath": ""}
    out = []
    for n in names:
        pen = RecordingPen()
        glyphs[n].draw(pen)
        for op, args in pen.value:
            out.append(ops[op] + " ".join(f"{x + px * k:.1f},{baseline - py * k:.1f}" for px, py in args))
        x += glyphs[n].width * k + tracking * size
    return " ".join(out)


def svg():
    # 提灯と文字の塊を同じ高さ（y 126〜601）にそろえ、帯との間と上下の余白をそろえる
    s = 2.05
    tx, ty = 82 - 28.7 * s, 126 - 12 * s
    col = (82 + (232 - 28.7) * s + 40 + 1024 - 82) / 2
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<rect width="1024" height="1024" fill="{INK}"/>
<g transform="translate({tx:.1f} {ty:.1f}) scale({s})"><path fill="{CREAM}" d="{LANTERN_BODY}"/><path fill="{GOLD}" d="{LANTERN_LIT}"/></g>
<path fill="{CREAM}" d="{text_path('舞台', 9, 204, col, 309, -0.02)}"/>
<path fill="{GOLD}" d="{text_path('3D', 9, 250, col, 586, -0.02)}"/>
<rect x="80" y="700" width="864" height="200" rx="40" fill="{RED}"/>
<path fill="{CREAM}" d="{text_path('シミュレータ', 9, 128, 512, 846, -0.02)}"/>
</svg>"""


def main():
    src = os.path.join(HERE, "icon.svg")
    open(src, "w", encoding="utf-8").write(svg())
    out = os.path.join(APP, "icon", "icon.png")
    subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", src, "-o", out], check=True)
    # App Store は透過を受け付けないので、背景色で埋めてアルファを外す
    subprocess.run(["magick", out, "-background", INK, "-alpha", "remove", "-alpha", "off", "-colorspace", "sRGB", out], check=True)
    os.makedirs(os.path.join(APP, "assets", "icon"), exist_ok=True)
    shutil.copyfile(out, os.path.join(APP, "assets", "icon", "app_icon.png"))
    print("icon:", out)


if __name__ == "__main__":
    main()
