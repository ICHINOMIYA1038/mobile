#!/bin/sh
set -eu

# 新しいアプリを1本作る。
#
# flutter create したあと、リリースに必要な下ごしらえまで済ませる:
#   - 要求された Bundle ID を iOS / Android に反映する
#   - Firebase (Analytics + Crashlytics) を配線する
#   - 計測込みの main.dart を置く
#
# 計測の方針とイベント命名規約は docs/analytics.md を参照。

usage() {
  echo "Usage: $0 <snake_case_name> <bundle_id>"
  echo "Example: $0 takken_mock_exam jp.pairof.takken.mockexam"
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

app_name=$1
bundle_id=$2
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$repo_root/apps/$app_name"

# 全アプリを1つの Firebase プロジェクトに集約している。GA4 プロパティも
# 1つなので、アプリ横断で DAU や継続率を並べて見られる。
firebase_project=${FIREBASE_PROJECT:-ichinomiya-apps}

case "$app_name" in
  *[!a-z0-9_]* | "" | [0-9]*)
    echo "App name must be lower_snake_case and must not start with a number: $app_name" >&2
    exit 2
    ;;
esac

case "$bundle_id" in
  jp.pairof.* | com.gikyokutosyokan.*) ;;
  *)
    echo "Bundle ID must start with jp.pairof. or com.gikyokutosyokan.: $bundle_id" >&2
    exit 2
    ;;
esac

if [ -e "$app_dir" ]; then
  echo "App directory already exists: $app_dir" >&2
  exit 1
fi

if "$repo_root/scripts/validate_repo.sh" --contains-bundle-id "$bundle_id"; then
  echo "Bundle ID is already used: $bundle_id" >&2
  exit 1
fi

for cmd in flutter firebase flutterfire; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

org=$(echo "$bundle_id" | awk -F. '{ print $1 "." $2 }')

flutter create \
  --org "$org" \
  --project-name "$app_name" \
  --platforms ios,android,macos,web \
  "$app_dir"

cd "$app_dir"

# --- Bundle ID -------------------------------------------------------------
# flutter create はプロジェクト名から識別子を作るため、要求された Bundle ID
# とは食い違う。Firebase の設定ファイルは Bundle ID をキーに配られるので、
# ここで合わせておかないと実機で初期化に失敗する。
pbxproj=ios/Runner.xcodeproj/project.pbxproj
generated_ios_id=$(
  sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER = \([^;]*\);/\1/p' "$pbxproj" |
    sed 's/[[:space:]]//g' |
    grep -v -e '\$(PRODUCT_BUNDLE_IDENTIFIER)' -e '\.RunnerTests$' |
    sort -u |
    head -1
)
sed -i '' \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = ${generated_ios_id}\.RunnerTests;/PRODUCT_BUNDLE_IDENTIFIER = ${bundle_id}.RunnerTests;/g" \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = ${generated_ios_id};/PRODUCT_BUNDLE_IDENTIFIER = ${bundle_id};/g" \
  "$pbxproj"

# Android は namespace（Kotlin のパッケージ名）と applicationId を分けられる。
# ソースの置き場所を動かさずに済むよう、applicationId だけを差し替える。
gradle=android/app/build.gradle.kts
generated_android_id=$(sed -n 's/.*applicationId = "\([^"]*\)".*/\1/p' "$gradle" | head -1)
sed -i '' "s/applicationId = \"${generated_android_id}\"/applicationId = \"${bundle_id}\"/" "$gradle"

# --- ローカライズ -----------------------------------------------------------
# flutter create の既定値は Info.plist の CFBundleDevelopmentRegion が
# $(DEVELOPMENT_LANGUAGE)（実質 en）のままで、CFBundleLocalizations も無い。
# 中身は日本語アプリでも、App Store 上の「言語」表示が英語になり検索の関連度が
# 落ちる（takken_simple 以外の全アプリで発生していた実例あり）。最初から日本語を
# 宣言しておく。
plist=ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion ja_JP" "$plist"
if ! /usr/libexec/PlistBuddy -c "Print :CFBundleLocalizations" "$plist" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations array" "$plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:0 string ja" "$plist"
fi

# --- 対応OS ---------------------------------------------------------------
# Firebase の iOS SDK は iOS 15 以上を要求する。flutter create の既定値
# （13.0）のままだと "requires minimum platform version 15.0" でビルドが
# 通らないので、最初から上げておく。
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 1[0-4]\.[0-9];/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' "$pbxproj"
# Podfile は CocoaPods を要求するプラグインが無ければ生成されない。
if [ -f ios/Podfile ]; then
  sed -i '' "s/^# platform :ios, '.*'/platform :ios, '15.0'/" ios/Podfile
fi

# --- 静的解析 --------------------------------------------------------------
cat >> analysis_options.yaml <<'YAML'

analyzer:
  exclude:
    # Firebase を入れると build/ 配下に依存パッケージのソースが展開され、
    # そのまま解析されて大量の指摘が出る。自分たちのコードだけを見る。
    - build/**
YAML

# --- 計測 ------------------------------------------------------------------
flutter pub add \
  firebase_core \
  firebase_crashlytics \
  'app_insights:{"path":"../../packages/app_insights"}'

# 未登録なら iOS / Android アプリを Firebase 側に作ってから設定ファイルを配る。
# Android の gradle プラグインと、iOS のクラッシュ用 dSYM アップロード
# Build Phase も、このコマンドが面倒を見てくれる。
flutterfire configure \
  --project="$firebase_project" \
  --platforms=android,ios \
  --ios-bundle-id="$bundle_id" \
  --android-package-name="$bundle_id" \
  --yes

# 計測を配線済みの main.dart を置く。flutter create が生成するカウンター
# デモは、どのみち作り直すので残さない。
cat > lib/main.dart <<'DART'
import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 画面遷移を screen_view として記録する。記録されるのは
      // RouteSettings.name を付けたルートだけなので、画面を追加したら
      // 名前も必ず付けること。
      navigatorObservers: AppInsights.navigatorObservers,
      home: const Scaffold(body: Center(child: Text('TODO'))),
    );
  }
}
DART

flutter analyze

cat <<EOS

Created apps/$app_name
  Bundle ID       : $bundle_id (iOS / Android に反映済み)
  Firebase project: $firebase_project

計測は配線済みです。アプリ固有のイベントは docs/analytics.md の命名規約に沿って
AppInsights.logEvent() で足してください。

このあと手で決めるもの: 表示名、アイコン、署名、課金商品、広告ID、ストア資料。
ストアのプライバシー申告には計測項目の記載が必要です（docs/analytics.md 参照）。
macOS / Web は Firebase 未設定のまま（配信対象ではないため）。計測は自動で無効化されます。
EOS
