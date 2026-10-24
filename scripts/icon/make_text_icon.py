"""文字が主役のアプリアイコン（1024×1024、角丸なし・透過なし・sRGB）を作る。

    python scripts/icon/make_text_icon.py apps/<app>/icon/source/icon.json
    （そのあと apps/<app> で dart run flutter_launcher_icons）

takken_talk（極太「宅建」＋帯）・tomoshibi（極太「舞台照明」＋帯）と同じ作り。
文字はヒラギノ角ゴの字形をパスにして SVG に埋め込む。要るもの: fonttools（pip）、rsvg-convert と magick（Homebrew）。

icon.json の例:
{
  "bg": "#8E2A2A",
  "big": {"text": "即興", "color": "#FFF6E6", "weight": 9, "size": 430, "baseline": 640},
  "band": {"text": "演劇のお題", "color": "#3A1414", "text_color": "#F5D447", "weight": 9, "size": 120,
           "y": 736, "h": 200, "x": 112, "w": 800},
  "decor": "<SVG の要素（背景の飾り。任意）>"
}
出力: icon.json と同じ場所に icon.svg、アプリの icon/icon.png（flutter_launcher_icons の入力）。
"""
import json
import os
import subprocess
import sys

from fontTools.pens.recordingPen import RecordingPen
from fontTools.ttLib import TTCollection

_FONTS = {}


def font(weight):
    if weight not in _FONTS:
        _FONTS[weight] = TTCollection(f"/System/Library/Fonts/ヒラギノ角ゴシック W{weight}.ttc").fonts[0]
    return _FONTS[weight]


def text_path(s, weight, size, cx, baseline, tracking=-0.02):
    """文字列を、cx を中心にした SVG のパス（d 属性）にする。size は 1em のピクセル数。"""
    f = font(weight)
    glyphs = f.getGlyphSet()
    cmap = f.getBestCmap()
    k = size / f["head"].unitsPerEm
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
    return " ".join(out), total


def build(cfg):
    big, band = cfg["big"], cfg.get("band")
    parts = [f'<rect width="1024" height="1024" fill="{cfg["bg"]}"/>', cfg.get("decor", "")]
    lines = big["text"] if isinstance(big["text"], list) else [big["text"]]
    gap = big.get("line_gap", big["size"] * 0.98)
    for i, line in enumerate(lines):
        d, width = text_path(line, big.get("weight", 9), big["size"], 512, big["baseline"] + i * gap, big.get("tracking", -0.02))
        if width > 940:
            raise SystemExit(f"大きな文字「{line}」がはみ出す（幅 {width:.0f}px > 940px）。size を下げる")
        parts.append(f'<path fill="{big["color"]}" d="{d}"/>')
    if band:
        parts.append(f'<rect x="{band.get("x", 112)}" y="{band["y"]}" width="{band.get("w", 800)}" height="{band["h"]}" rx="{band.get("rx", 40)}" fill="{band["color"]}"/>')
        d, width = text_path(band["text"], band.get("weight", 9), band["size"], 512, band["y"] + band["h"] / 2 + band["size"] * 0.36, band.get("tracking", -0.02))
        if width > band.get("w", 800) - 60:
            raise SystemExit(f"帯の文字「{band['text']}」が帯からはみ出す（幅 {width:.0f}px）。size を下げる")
        parts.append(f'<path fill="{band["text_color"]}" d="{d}"/>')
    return '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n' + "\n".join(p for p in parts if p) + "\n</svg>"


def main(path, out_png=None):
    cfg = json.load(open(path, encoding="utf-8"))
    src_dir = os.path.dirname(os.path.abspath(path))
    svg = os.path.join(src_dir, "icon.svg")
    open(svg, "w", encoding="utf-8").write(build(cfg))
    png = out_png or os.path.abspath(os.path.join(src_dir, "..", "icon.png"))
    subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", svg, "-o", png], check=True)
    # App Store は透過を受け付けないので、背景色で埋めてアルファを外す
    subprocess.run(["magick", png, "-background", cfg["bg"], "-alpha", "remove", "-alpha", "off", "-colorspace", "sRGB", png], check=True)
    print(png)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
