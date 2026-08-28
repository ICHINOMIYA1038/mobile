# TOMOSHIBI小屋 (tomoshibi)

戯曲図書館が開発・運営する 3D 舞台照明プランニングツール
[TOMOSHIBI小屋](https://tomoshibi.gikyokutosyokan.com/) の公式 iOS クライアント。

3D 空間に舞台を組んで照明器具と役者を配置し、客席・俯瞰・袖・自由の 4 視点から
光の当たり方を確認する。客電のオン/オフで作業灯下と本番照明下を比較できる。

## 構成

Web 版のエディタを `webview_flutter` で表示し、iOS ネイティブ側の機能を橋渡しする。

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
