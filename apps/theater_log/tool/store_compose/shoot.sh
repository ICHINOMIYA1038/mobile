#!/bin/bash
# App Store の画像の素材を撮る。iPhone 16 Pro Max のシミュレーターで integration_test/store_shots_test.dart を流し、
# 「SHOT 名前」の出たところで画面を raw/<名前>.png に保存する。終わったらシミュレーターを止める。
#   bash tool/store_compose/shoot.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
SIM="${SIM:-2A5FFB9C-DDA6-4D4E-9702-DDAE3F1E2CE0}"   # iPhone 16 Pro Max（1320×2868）
RAW="tool/store_compose/raw"
mkdir -p "$RAW"
# テストが失敗しても止める（起動したままだと Mac の音が途切れる）
trap 'xcrun simctl shutdown "$SIM" 2>/dev/null || true' EXIT
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl status_bar "$SIM" override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
flutter test integration_test/store_shots_test.dart -d "$SIM" --dart-define=PHOTOS="$PWD/tool/store_compose/photos" 2>&1 | while IFS= read -r line; do
  if [[ "$line" == *"SHOT "* ]]; then
    name="${line##*SHOT }"
    sleep 1.2
    xcrun simctl io "$SIM" screenshot "$RAW/$name.png" >/dev/null 2>&1
    echo "shot $name"
  fi
  [[ "$line" == *"passed"* || "$line" == *"failed"* || "$line" == *"EXCEPTION"* ]] && echo "$line"
done
