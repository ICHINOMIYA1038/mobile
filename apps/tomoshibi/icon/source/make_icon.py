"""TOMOSHIBI小屋のアプリアイコン（1024×1024、角丸なし・透過なし・sRGB）を作る。

    python icon/source/make_icon.py          # apps/tomoshibi で実行
    dart run flutter_launcher_icons          # iOS / Android のアイコンに反映

暗転した舞台に上から光が落ち、極太の「舞台照明」と赤い帯「3Dで仕込み」。
文字はヒラギノ角ゴ W9/W8 の字形をパスにして SVG に埋め込む（takken_talk の icon/source/ship2.py と同じ方式）。
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

INK = "#0E0B12"      # 暗転した舞台
BEAM = "#FFD58A"     # 光の芯
WARM = "#F08A3C"     # 光の縁
RED = "#C8482D"      # アプリのテーマ色（lib/main.dart の seedColor）
CREAM = "#FFF6E6"


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
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
  <linearGradient id="beam" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{BEAM}" stop-opacity="0.55"/>
    <stop offset="1" stop-color="{WARM}" stop-opacity="0.08"/>
  </linearGradient>
  <radialGradient id="pool" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="{BEAM}" stop-opacity="0.7"/>
    <stop offset="1" stop-color="{WARM}" stop-opacity="0"/>
  </radialGradient>
</defs>
<rect width="1024" height="1024" fill="{INK}"/>
<path d="M432,0 L592,0 L940,700 L84,700 Z" fill="url(#beam)"/>
<ellipse cx="512" cy="690" rx="470" ry="80" fill="url(#pool)"/>
<path fill="{CREAM}" d="{text_path('舞台', 9, 290, 512, 345, -0.02)}"/>
<path fill="{CREAM}" d="{text_path('照明', 9, 290, 512, 655, -0.02)}"/>
<rect x="112" y="736" width="800" height="200" rx="40" fill="{RED}"/>
<path fill="{CREAM}" d="{text_path('3Dで仕込み', 9, 128, 512, 884, -0.02)}"/>
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
    # ホーム画面の大きさ（60px）での見え方の確認用。リポジトリには入れない
    subprocess.run(["magick", out, "-resize", "60x60", "/tmp/tomoshibi_icon_60.png"], check=True)
    print("icon:", out)


if __name__ == "__main__":
    main()
