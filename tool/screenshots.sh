#!/usr/bin/env bash
# App Store / Google Play 掲載用のスクリーンショットを撮る。
#
#   ./tool/screenshots.sh
#
# screenshots/ に PNG が書き出される。
#
# App Store は 6.9インチ（1320x2868）の提出が必須。iPhone 16 Pro Max がちょうどこの解像度。
# 6.5インチ（1242x2688）も求められる場合があるので、iPhone 11 Pro Max 等でも撮ること。
#
# 撮る内容は integration_test/screenshots_test.dart にある。
# まっさらな状態では合格グラフの良さが伝わらないため、学習が進んだ状態を作ってから撮っている。
set -euo pipefail

DEVICE_NAME="${1:-iPhone 16 Pro Max}"

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

xcrun simctl boot "$UDID" 2>/dev/null || true
# 起動しきる前に流し込むと落ちるので待つ
xcrun simctl bootstatus "$UDID" -b

echo "== 撮影 =="
flutter drive \
  --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$UDID"

echo
echo "== 完了 =="
ls -la screenshots/ 2>/dev/null || echo "screenshots/ が空です"
echo
echo "解像度を確認してください（App Store 6.9インチは 1320x2868 が必須）:"
for f in screenshots/*.png; do
  [ -e "$f" ] || continue
  printf "  %s: " "$(basename "$f")"
  sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixel/{printf "%s ", $2}'
  echo
done
