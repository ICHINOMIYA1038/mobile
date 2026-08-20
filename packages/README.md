# Shared packages

2つ以上のアプリで同じ責務のコードが必要になった場合だけ、ここへFlutter/Dartパッケージとして
切り出します。アプリ固有の課金、広告、通知、文言、ブランド要素は共有しません。

- [app_insights](app_insights) — 全アプリ共通の計測（Firebase Analytics / Crashlytics）。
  新規アプリには `scripts/create_app.sh` が自動で組み込みます。
