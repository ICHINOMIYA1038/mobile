#!/usr/bin/env python3
"""ストアスクリーンショット用のシーンをURLとして組み立てる。

TOMOSHIBI小屋のWeb側は起動時に `#scene=<base64(JSON)>` を読んでシーンを復元する
(tomoshibi/src/io/sceneIO.ts の tryLoadFromHash)。カメラ視点(cameraView)や客電
(showHouseLights)もこのJSONのsettingsに入るため、1枚のスクリーンショット=1つのURLとして
完全に再現できる。撮影のたびに手で器具を並べ直す必要はない。

  python3 tool/build_scene_urls.py           # URL一覧を表示
  python3 tool/build_scene_urls.py --json    # スクリプトから読む用
  python3 tool/build_scene_urls.py --dart    # integration_test/scene_urls.g.dart を生成
  python3 tool/build_scene_urls.py --framefile  # ios/fastlane/screenshots/Framefile.json を生成

舞台座標 (tomoshibi/src/scene/Stage.tsx より):
  床 z=-8..2 / プロセニアム開口 幅12m 高さ6m / バトン y=7.0, z=1.5,-1,-3.5,-6
  ホリゾント(白幕) z=-7.6, 高さ中心3.5m
"""
import base64
import json
import sys

BASE_URL = "https://tomoshibi.gikyokutosyokan.com/"


def fixture(fid, name, preset, pos, target, *, beam, intensity, color,
            gel=False, white=0.0, kelvin=3200, rot=0.0):
    return {
        "id": fid, "name": name, "presetKey": preset,
        "position": pos, "target": target,
        "beamAngleDeg": beam, "intensity": intensity, "color": color,
        "gelEnabled": gel, "whiteMix": white, "colorTempK": kelvin,
        "rotationZDeg": rot, "enabled": True,
    }


def performer(pid, name, pos, scale, color, pose="standing"):
    return {"id": pid, "name": name, "position": pos,
            "scale": scale, "color": color, "pose": pose}


# --- 共通の仕込み: 「1人芝居のクライマックス」を想定した吊り込み ---------------
# 前明かり3灯 (第1バトン z=1.5) + トップバック2灯 (第3バトン z=-3.5)
# + ホリゾント青2灯 (第4バトン z=-6) + 袖からの横明かり1灯
FIXTURES = [
    fixture("f1", "Source Four 26° 前L", "Source4_26",
            [-3.0, 7.0, 1.5], [-1.4, 1.5, -1.0],
            beam=26, intensity=0.36, color=[1.0, 0.87, 0.72], kelvin=3200),
    fixture("f2", "Source Four 26° 前C", "Source4_26",
            [0.0, 7.0, 1.5], [0.0, 1.5, -1.0],
            beam=26, intensity=0.3, color=[1.0, 0.9, 0.78], kelvin=3200),
    fixture("f3", "Source Four 26° 前R", "Source4_26",
            [3.0, 7.0, 1.5], [1.4, 1.5, -1.0],
            beam=26, intensity=0.36, color=[1.0, 0.87, 0.72], kelvin=3200),
    fixture("f4", "PAR64 NSP トップL", "PAR64_NSP",
            [-2.2, 7.0, -3.5], [-1.2, 0.6, -2.2],
            beam=11, intensity=0.38, color=[0.62, 0.74, 1.0], gel=True, kelvin=3200),
    fixture("f5", "PAR64 NSP トップR", "PAR64_NSP",
            [2.2, 7.0, -3.5], [1.2, 0.6, -2.2],
            beam=11, intensity=0.38, color=[0.62, 0.74, 1.0], gel=True, kelvin=3200),
    fixture("f6", "COLORado 2 Solo ホリL", "Chauvet_COLORado2Solo",
            [-3.0, 7.0, -6.0], [-3.2, 3.4, -7.5],
            beam=25, intensity=0.28, color=[0.18, 0.34, 0.95], white=0.0, kelvin=6500),
    fixture("f7", "COLORado 2 Solo ホリR", "Chauvet_COLORado2Solo",
            [3.0, 7.0, -6.0], [3.2, 3.4, -7.5],
            beam=25, intensity=0.28, color=[0.18, 0.34, 0.95], white=0.0, kelvin=6500),
    fixture("f8", "LEDBeam 150 袖下手", "Robe_LEDBeam150",
            [-5.6, 2.4, -1.0], [0.6, 1.5, -1.2],
            beam=12, intensity=0.42, color=[1.0, 0.62, 0.24], white=0.0, kelvin=5600),
]

PERFORMERS = [
    performer("p1", "主演", [0.0, 0.0, -1.2], 1.0, "#d6b896"),
    performer("p2", "役者2", [-1.9, 0.0, -2.4], 0.95, "#7d5a3d"),
    performer("p3", "役者3", [2.0, 0.0, -2.6], 1.05, "#5a4030"),
]

# 撮影用に固定する共通設定。
# 光量・露出・ブルームは初回撮影(2026-08-28)で床と役者が完全に白飛びしたため、
# 器具のintensityを半分以下に、exposureを1.05→0.55、bloomを0.42→0.24へ落としてある。
# showGizmos/panelOpen を落として3Dだけを見せ、showHelp を落として
# 初回ヘルプのオーバーレイが被らないようにする。quality は見栄え優先で high。
BASE_SETTINGS = {
    "hazeDensity": 0.36,
    "ambient": 0.03,
    "exposure": 0.55,
    "bloom": 0.24,
    "quality": "high",
    "showHouseLights": False,
    "showGizmos": False,
    "showHelp": False,
    "panelOpen": False,
    "scenePanelOpen": False,
    "settingsOpen": False,
    "probeMode": False,
}

# 5枚の構成。1枚ごとに違うベネフィットを担当させる
# (docs/screenshot-guidelines.md の「要素1: 全スクショに見出し」に対応)。
SHOTS = [
    {
        "name": "01_audience",
        "scene_name": "客席から",
        "settings": {"cameraView": "audience"},
        "title": "客席からの見え方を\nそのまま確認",
        "keyword": "本番と同じ目線で",
    },
    {
        # 客電OFFのままだと画面の中央3分の1が黒く抜けて構図にならないため、
        # 俯瞰だけは客電ONで撮る (2026-08-28の撮影で確認)。
        "name": "02_aerial",
        "scene_name": "俯瞰",
        "settings": {"cameraView": "aerial", "showHouseLights": True},
        "title": "吊り位置と当たりを\n俯瞰でチェック",
        "keyword": "仕込み図がそのまま3Dに",
    },
    # 【注意】この袖(sidewing)視点は、Web側のカメラ修正がデプロイ済みであることが前提。
    # 修正前のプリセットは pos=[-9,3,4] とサイドウォール(x=-8)の外側にあり、
    # 壁の裏面が画面の大半を黒く覆って何も写らない(2026-08-28の撮影で判明)。
    # tomoshibi(Web)側の src/App.tsx の CAMERA_VIEWS.sidewing を修正済みだが、
    # 本番へデプロイするまでこのアプリは旧版を読み込む。デプロイ前に撮ると
    # 真っ黒な画像になるので、必ずデプロイ後に撮り直すこと。
    {
        "name": "03_sidewing",
        "scene_name": "袖から",
        "settings": {"cameraView": "sidewing"},
        "title": "袖からの抜けも\n確かめられる",
        "keyword": "客席・俯瞰・袖・自由の4視点",
    },
    {
        "name": "04_houselights",
        "scene_name": "客電ON",
        "settings": {"cameraView": "audience", "showHouseLights": True},
        "title": "客電を入れて\n明転も再現",
        "keyword": "作業灯と本番の差がわかる",
    },
    {
        "name": "05_panel",
        "scene_name": "器具を選ぶ",
        "settings": {"cameraView": "free", "panelOpen": True},
        "title": "在来もLEDも\n22機種を収録",
        "keyword": "PAR・Fresnel・Source Four・ETC",
    },
]


def build_scene(shot):
    settings = dict(BASE_SETTINGS)
    settings.update(shot["settings"])
    return {
        "version": 1,
        "name": shot["scene_name"],
        "savedAt": "2026-08-28T00:00:00.000Z",
        "fixtures": FIXTURES,
        "performers": PERFORMERS,
        "settings": settings,
    }


def build_url(shot):
    raw = json.dumps(build_scene(shot), ensure_ascii=False, separators=(",", ":"))
    b64 = base64.b64encode(raw.encode("utf-8")).decode("ascii")
    return f"{BASE_URL}#scene={b64}"


DART_HEADER = """// GENERATED FILE - DO NOT EDIT.
// `python3 tool/build_scene_urls.py --dart` で生成する。
// 元データは tool/build_scene_urls.py。

/// ストア用スクリーンショット1枚分の指定。
class ShotSpec {
  const ShotSpec({required this.name, required this.url});

  /// 出力ファイル名 (`screenshots/<name>.png`)。
  final String name;

  /// シーンを埋め込んだ起動URL。
  final String url;
}

const shotSpecs = <ShotSpec>[
"""


def write_dart(shots, path="integration_test/scene_urls.g.dart"):
    lines = [DART_HEADER]
    for s in shots:
        lines.append("  ShotSpec(")
        lines.append(f"    name: '{s['name']}',")
        lines.append(f"    url: '{s['url']}',")
        lines.append("  ),")
    lines.append("];")
    lines.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"wrote {path} ({len(shots)} shots)")


# frameit の見出し配色。アプリアイコン (#1A1410 の暗い小屋 + 灯りのオレンジ) に合わせる
# = docs/screenshot-guidelines.md の「要素4: アイコンと同じ配色で背景を統一」。
FRAME_BACKGROUND = "#1A1410"
FRAME_TITLE_COLOR = "#F5EDE0"
FRAME_KEYWORD_COLOR = "#E8874F"


def write_framefile(shots, path="ios/fastlane/screenshots/Framefile.json"):
    doc = {
        "default": {
            "background": "../frame_assets/background.png",
            "padding": "5%",
            "stack_title": True,
            "title_below_image": False,
            "title": {
                "font": "../frame_assets/fonts/HiraginoSansW6.ttc",
                "color": FRAME_TITLE_COLOR,
                "font_size": 88,
            },
            "keyword": {
                "font": "../frame_assets/fonts/HiraginoSansW3.ttc",
                "color": FRAME_KEYWORD_COLOR,
                "font_size": 44,
            },
        },
        "data": [
            {
                "filter": s["name"],
                "title": {"text": s["title"]},
                "keyword": {"text": s["keyword"]},
            }
            for s in shots
        ],
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"wrote {path} ({len(shots)} shots)")


def main():
    shots = [dict(s, url=build_url(s)) for s in SHOTS]
    if "--json" in sys.argv:
        json.dump(shots, sys.stdout, ensure_ascii=False)
        print()
        return
    if "--dart" in sys.argv:
        write_dart(shots)
        return
    if "--framefile" in sys.argv:
        write_framefile(shots)
        return
    for s in shots:
        print(f"# {s['name']}: {s['title']}")
        print(s["url"])
        print()


if __name__ == "__main__":
    main()
