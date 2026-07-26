# Mobile apps

複数のモバイルアプリを管理するモノレポです。各アプリは独立した Flutter プロジェクトとして
`apps/` に置き、複数アプリで実際に再利用するコードだけを `packages/` に切り出します。

## 構成

```text
apps/
  takken_simple/       シンプルに学ぶ宅建
packages/              2アプリ以上で共有するFlutter/Dartパッケージ
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

新しいアプリは、名前とBundle IDの重複を防ぐ作成スクリプトから追加します。

```sh
./scripts/create_app.sh takken_mock_exam jp.pairof.takken.mockexam
```
