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
# 撮影方式は etude_generator の tool/screenshots.sh と同じ（詳細はそちらのコメント参照）。
set -euo pipefail

DEVICE_NAME="${1:-iPhone 16 Pro Max}"
OUT_DIR="${2:-screenshots}"

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

BUNDLE_ID="jp.pairof.sound.shield"

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

echo "== 撮影 =="
flutter test integration_test/screenshots_test.dart -d "$UDID"

cleanup
trap - EXIT

echo
echo "== 完了 =="
ls -la "$OUT_DIR/" 2>/dev/null || echo "$OUT_DIR/ が空です"
echo
echo "解像度を確認してください（App Store 6.9インチは 1320x2868 が必須）:"
for f in "$OUT_DIR"/*.png; do
  [ -e "$f" ] || continue
  printf "  %s: " "$(basename "$f")"
  sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixel/{printf "%s ", $2}'
  echo
done
