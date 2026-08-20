# Repository-wide documentation

全アプリに共通するリリース方針、命名規則、CI運用などを置きます。
アプリ固有の審査資料やプライバシーポリシーは各 `apps/<app>/docs/` に置きます。

- [analytics.md](analytics.md) — ダウンロード数・利用状況・クラッシュの計測方針、
  イベント命名規約、ストアのプライバシー申告に書く内容
- [console-runbook.md](console-runbook.md) — CLI では済まずブラウザ操作が必要な作業の手順
  （GA4 のリンク、ストアのプライバシー申告、AdMob 連携）
- [screenshot-guidelines.md](screenshot-guidelines.md) — 売れているアプリのスクリーン
  ショット調査と、見出し合成スクリプト（`tool/store_previews.sh`）の使い方
