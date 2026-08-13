# Mobile apps

複数のモバイルアプリを管理するモノレポです。各アプリは独立した Flutter プロジェクトとして
`apps/` に置き、複数アプリで実際に再利用するコードだけを `packages/` に切り出します。

## 構成

```text
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
プロジェクトなので、操作もアプリごとに行います（以下は takken_simple の例）。

```sh
cd apps/takken_simple
flutter pub get
flutter test
flutter run
```

全アプリの解析とテストは次で実行できます。

```sh
./scripts/check_all.sh
```

## 新しいアプリ

作成スクリプトから追加します。名前とBundle IDの重複を防ぎ、Bundle IDの反映と
計測（Firebase Analytics / Crashlytics）の配線まで済ませます。

```sh
./scripts/create_app.sh takken_mock_exam jp.pairof.takken.mockexam
```

このあと手で決めるのは、表示名、アイコン、署名、課金商品、広告ID、ストア資料です。
**ストアのプライバシー申告とプライバシーポリシーには、計測している項目の記載が要ります。**
書くべき内容は [`docs/analytics.md`](docs/analytics.md) にまとめてあります。

## 計測

ダウンロード数はストアのコンソール、アプリ内の利用状況は Firebase Analytics、
クラッシュは Crashlytics で見ます。全アプリを1つの Firebase プロジェクト
`ichinomiya-apps` に集約しているため、アプリ横断で DAU や継続率を比較できます。

方針とイベント命名規約は [`docs/analytics.md`](docs/analytics.md) を参照してください。
