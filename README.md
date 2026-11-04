# Mobile apps

複数のモバイルアプリを管理するモノレポです。各アプリは独立した Flutter プロジェクトとして
`apps/` に置き、複数アプリで実際に再利用するコードだけを `packages/` に切り出します。
リポジトリ全体を1つの Dart pub workspace（[melos](https://melos.invertase.dev/)管理）に
しており、依存パッケージのバージョン解決は全アプリ共通の`pubspec.lock`1本にまとまります。

前提コマンド（初回のみ）:

```sh
dart pub global activate melos 7.8.1  # 8.2.2以降はcli_util ^0.5.0を要求し、
                                        # flutter_launcher_icons(^0.4.1要求)と
                                        # workspace内で共存できない
dart pub global activate flutterfire_cli
```

## 構成

```text
pubspec.yaml           workspace定義（apps/*・packages/*）とmelosスクリプト
apps/
  takken_simple/       シンプルに学ぶ宅建（1アプリ1ディレクトリ、他のアプリも並ぶ）
packages/
  app_insights/        全アプリ共通の計測（Analytics / Crashlytics）
scripts/               リポジトリ全体を対象にするスクリプト
docs/                  全アプリ共通の方針や運用資料
```

宅建シリーズを増やす場合は、用途が分かる名前で並べます。

```text
apps/takken_simple
apps/takken_mock_exam
apps/takken_terms
```

Bundle ID、アイコン、ストア文言、課金、広告、通知、スクリーンショット、審査資料は
アプリごとに管理します。共通化を先に行わず、2本以上で同じ実装が必要になった時点で
`packages/` へ移します。

## 既存アプリ

`apps/` 配下に1アプリ1ディレクトリで並んでいます。それぞれ独立した Flutter
プロジェクトとして`flutter run`等はアプリごとに行いますが、依存解決はworkspace
全体で1本になっているため、`pub get`はリポジトリルートから行います（個別ディレクトリで
`flutter pub get`しても動きますが、実体はルートの`pubspec.lock`を見に行きます）。

```sh
melos bootstrap        # workspace全体の依存解決（初回・pubspec.yaml変更後）
cd apps/takken_simple
flutter test
flutter run
```

全アプリの解析とテストは次で実行できます（`melos bootstrap` → `melos run analyze` →
`melos run test`を内部で呼びます）。

```sh
./scripts/check_all.sh
```

## 新しいアプリ

作成スクリプトから追加します。名前とBundle IDの重複を防ぎ、Bundle IDの反映、
pub workspaceへの参加（`resolution: workspace`）、計測（Firebase Analytics /
Crashlytics）、ストア提出用のfastlaneひな形の配線まで済ませます。

```sh
./scripts/create_app.sh takken_mock_exam jp.pairof.takken.mockexam
```

このあと手で決めるのは、表示名、アイコン、署名、課金商品、広告ID、ストア資料です。
**ストアのプライバシー申告とプライバシーポリシーには、計測している項目の記載が要ります。**
書くべき内容は [`docs/analytics.md`](docs/analytics.md) にまとめてあります。

## 資格シリーズの試作アプリ

FP2級・FP3級・ITパスポート・情報セキュリティマネジメント・基本情報技術者・管理業務主任者・賃貸不動産経営管理士の7本は、`packages/shikaku_trial` の画面を共有する iOS 試作版です。教材と API は別リポジトリ `pairof-shikaku` の `feat/qualification-series` にあります。

新しい資格を同じ試作構成で追加するときは、`scripts/generate_qualification_trials.py` の `EXAMS` に資格名・アイコン文字・色を追加し、`python3 -B scripts/generate_qualification_trials.py --create <資格ID>` を実行します。生成済みの設定は `--check` で確認できます。開発用 API には `--dart-define=API_BASE=<開発サーバーURL>` で接続します。

この7本は調査とコード作成の段階に限り、Firebase へのアプリ登録と計測を行っていません。そのため `scripts/insights-exempt.txt` に理由を記録しています。ストア提出に進む前に、`AGENTS.md` の新規アプリ手順に沿って計測、提出資料、署名を確認してください。

## 計測

ダウンロード数はストアのコンソール、アプリ内の利用状況は Firebase Analytics、
クラッシュは Crashlytics で見ます。全アプリを1つの Firebase プロジェクト
`ichinomiya-apps` に集約しているため、アプリ横断で DAU や継続率を比較できます。

方針とイベント命名規約は [`docs/analytics.md`](docs/analytics.md) を参照してください。

## ストア提出（fastlane）

iOSのApp Store Connect提出は、各アプリの`ios/`に配線済みのfastlane
（`deliver` + `frameit`。`snapshot`はFlutterと非互換のため不採用）で行います。
スクリーンショットの作り方は [`docs/screenshot-guidelines.md`](docs/screenshot-guidelines.md)、
APIキー・審査提出手順は [`ios-app-review-submission.md`](ios-app-review-submission.md)
を参照してください。

```sh
cd apps/takken_simple/ios
bundle install                              # 初回のみ
bundle exec fastlane ios compose_screenshots  # frameitでスクショ合成（ローカルのみ、安全）
bundle exec fastlane ios upload_metadata      # ASCへメタデータ+スクショをアップロード
                                               # （実際に反映されるため実行前に要確認）
```
