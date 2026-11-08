# TOMOSHIBI小屋 (tomoshibi)

戯曲図書館が開発・運営する舞台の演出・照明プランニングツール
[TOMOSHIBI小屋](https://tomoshibi.gikyokutosyokan.com/) の公式 iOS クライアント。

起動時にプロジェクト一覧を開く。作品や会場ごとのプランを選び、章とシーンを
編集する。3D 表示と平面図で役者・舞台セット・照明を配置し、光の当たり方や
シーンの流れを確認できる。

## 構成

Web 版のプロジェクト一覧とエディタを `webview_flutter` で表示し、
iOS ネイティブ側の機能を橋渡しする。購入の復元は Web 画面の下にあるバーから開く。

| ファイル | 役割 |
| --- | --- |
| `lib/main.dart` | WebView シェル本体。ATT 許諾、Universal Links、購入・復元の導線 |
| `lib/navigation_policy.dart` | アプリ内で開くホストの判定、サインイン/ログアウト/ネイティブ購入の横取り条件 |
| `lib/purchase_service.dart` | RevenueCat 経由の StoreKit 購入・復元・アカウント紐付け |

ネイティブ側で個別に実装している連携:

- **ATT**: WebView が何かを読み込む前に許諾を取り、結果を `X-ATT-Status` ヘッダで
  サイト側へ渡してトラッキング系スクリプトを制御する (Guideline 5.1.2(i))
- **サインイン**: 埋め込み WebView ではなく `ASWebAuthenticationSession` で開き、
  ワンタイムトークンを `/api/auth/mobile-handoff` に渡して本体 WebView 側の
  Cookie ストアにセッションを発行させる (Guideline 4)
- **課金**: Stripe Checkout への遷移を横取りして StoreKit の IAP に置き換える。
  未ログインでも購入・復元できる (Guideline 3.1.1 / 5.1.1(v))

## 開発

```sh
flutter analyze
flutter test
flutter run
```

## 審査・リリース

- [docs/app-store-submission.md](docs/app-store-submission.md) — 提出手順と審査メモ
- [docs/4.3a-rejection-response.md](docs/4.3a-rejection-response.md) — 2026-08-27 の
  Guideline 4.3(a) 却下への対応
- リポジトリルートの `ios-app-review-submission.md` — 署名・アップロード手順（全アプリ共通）
