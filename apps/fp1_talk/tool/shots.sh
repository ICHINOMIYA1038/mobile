#!/bin/zsh
# 通しの確認をシミュレーターで流し、「SHOT 名前」を出したところで画面を撮る。
#   tool/shots.sh <シミュレーターの UDID> <出力先（例 tool/shots）> <テスト（例 integration_test/fp1_flow_test.dart）> [flutter test に渡す引数…]
# 例: tool/shots.sh $UDID tool/shots integration_test/fp1_flow_test.dart --dart-define=API_BASE=http://localhost:3150
set -u
UDID=$1; OUT=$2; TEST=$3; shift 3
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
flutter test "$TEST" -d "$UDID" "$@" 2>&1 | while IFS= read -r line; do
  echo "$line"
  case "$line" in *"SHOT "*) n=${line##*SHOT }; xcrun simctl io "$UDID" screenshot "$OUT/$n.png" >/dev/null 2>&1;; esac
done
