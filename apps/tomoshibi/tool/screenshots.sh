#!/usr/bin/env bash
# App Store 掲載用のスクリーンショットを撮る。
#
#   ./tool/screenshots.sh                                # iPhone 16 Pro Max (6.9インチ, 1320x2868)
#   ./tool/screenshots.sh "iPad Pro 13-inch (M4)" screenshots_ipad
#
# screenshots/ に PNG が書き出される。
#
# 撮る内容は integration_test/screenshots_test.dart、
# 表示するシーン(器具の吊り込み・視点・客電)は tool/build_scene_urls.py にある。
# 撮影方式は sound_shield の tool/screenshots.sh と同じマーカーファイル方式。
#
# 注意: このアプリはWebView (Web版 TOMOSHIBI小屋) を表示するため、撮影には
# ネットワーク接続が必要で、本番サイトが表示できる状態でなければならない。
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_NAME="${1:-iPhone 16 Pro Max}"
OUT_DIR="${2:-screenshots}"

BUNDLE_ID="com.gikyokutosyokan.tomoshibi"

echo "== シーンURLを生成 =="
python3 tool/build_scene_urls.py --dart

echo "== $DEVICE_NAME を起動 =="
UDID=$(xcrun simctl list devices available \
  | grep -F "$DEVICE_NAME (" \
  | head -1 \
  | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')

if [ -z "$UDID" ]; then
  echo "エラー: シミュレータ '$DEVICE_NAME' が見つかりません。" >&2
  echo "使える端末: xcrun simctl list devices available" >&2
  exit 1
fi

# 直前に別のアプリ(Safari等)を触っていると、ステータスバー左上に
# 「◀ Safari」のようなアプリ切り替え戻りリンクが残り、そのままスクリーンショットに
# 写り込む。過去に提出したスクショにも「◀ 猫と学ぶ高校化学」が写っていたので、
# 撮影前に必ずシャットダウンして切り替えチェーンを消してから起動する。
xcrun simctl shutdown "$UDID" 2>/dev/null || true
xcrun simctl boot "$UDID" 2>/dev/null || true
# 起動しきる前に流し込むと落ちるので待つ
xcrun simctl bootstatus "$UDID" -b

mkdir -p "$OUT_DIR"

echo "== 撮影用の常駐プロセスを起動 =="
(
  TMP_DIR=""
  while [ -z "$TMP_DIR" ]; do
    DATA_DIR=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data 2>/dev/null) || true
    if [ -n "$DATA_DIR" ] && [ -d "$DATA_DIR/tmp" ]; then
      TMP_DIR="$DATA_DIR/tmp"
    else
      sleep 0.3
    fi
  done

  while true; do
    for request in "$TMP_DIR"/shot_*.request; do
      [ -e "$request" ] || continue
      base=$(basename "$request" .request)
      name=${base#shot_}
      xcrun simctl io "$UDID" screenshot "$OUT_DIR/$name.png" >/dev/null 2>&1
      rm -f "$request"
      touch "$TMP_DIR/shot_$name.done"
    done
    sleep 0.05
  done
) &
POLLER_PID=$!

# `flutter test -d` は iOS の生成設定を一時テスト用listenerへ書き換える。
# そのままXcodeでArchiveすると削除済みlistenerを参照して失敗するため、
# 成否にかかわらず通常アプリのRelease設定へ戻す。
cleanup() {
  kill "$POLLER_PID" 2>/dev/null || true
  flutter build ios --config-only --release >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== 撮影 (1枚あたり25秒ほどWebGLの描画を待ちます) =="
flutter test integration_test/screenshots_test.dart -d "$UDID"

cleanup
trap - EXIT

# アプリがシミュレータのメモリ不足で落ちると `flutter test` が死んだ接続を待って
# 固まったままになり、途中までのスクショだけが残る。撮れた枚数を必ず突き合わせる。
EXPECTED=$(python3 tool/build_scene_urls.py --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')
MISSING=0
for name in $(python3 tool/build_scene_urls.py --json | python3 -c 'import json,sys; [print(s["name"]) for s in json.load(sys.stdin)]'); do
  if [ ! -e "$OUT_DIR/$name.png" ]; then
    echo "エラー: $OUT_DIR/$name.png が撮れていません" >&2
    MISSING=1
  fi
done
if [ "$MISSING" -ne 0 ]; then
  echo "撮影は $EXPECTED 枚すべて揃うまで完了とみなせません。" >&2
  exit 1
fi

echo
echo "== 完了 (${EXPECTED}枚) =="
ls -la "$OUT_DIR/" 2>/dev/null || echo "$OUT_DIR/ が空です"
echo
echo "解像度を確認してください（App Store 6.9インチは 1320x2868 が必須）:"
for f in "$OUT_DIR"/*.png; do
  [ -e "$f" ] || continue
  printf "  %s: " "$(basename "$f")"
  sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixel/{printf "%s ", $2}'
  echo
done
