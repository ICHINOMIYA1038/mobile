# App Store 提出メモ

## 状態（2026-11-04）
| 項目 | 状態 |
|---|---|
| Firebase のアプリ登録 | 済（`ichinomiya-apps`） |
| アイコン | 済（`tool/make_icon.py`） |
| カタログ API | 本番で稼働（gikyoku_tosyokan #594） |
| プライバシーポリシー | 公開済み（gikyoku_tosyokan #595） |
| ASC のアプリ登録 | 済（App ID 6830291824。Web で作成） |
| ASC のストア情報 | 済（API。権利の申告だけ未） |
| TestFlight | build 1 を内部グループ「開発」に配布 |
| スクリーンショット | 済（`docs/screenshots`、iPhone 6.9 インチ 3 枚。`tool/store_compose.py`） |
| 実機の確認 | 未 |

対応端末は iPhone のみ（`TARGETED_DEVICE_FAMILY = 1`）。

## 署名
手動署名。プロファイル「gikyoku library App Store」、証明書は専用キーチェーンの Apple Distribution。ExportOptions は takken_talk と同じ形で Bundle ID とプロファイル名だけ違う。

## App のプライバシー（申告内容）
2026-11-04 に公開済み。
- トラッキング: なし
- 使用状況データ → 製品の操作: 分析目的、ユーザーに紐付けない（Firebase Analytics。画面遷移、絞り込みの種類、開いた作品と候補の操作）
- 診断 → クラッシュデータ: 分析目的、ユーザーに紐付けない（Crashlytics）
- 診断 → パフォーマンスデータ: 分析目的、ユーザーに紐付けない
- 候補リストの中身は端末の中だけ。ただし追加と削除の計測で作品 ID を送る

## 審査メモ（案）
This app helps theatre groups and school drama clubs choose a play to stage. It needs no account. Filter plays by cast size and running time on the search tab, tap the bookmark to add plays to the shortlist tab, and compare or share them there. The catalog is bundled, so filtering works offline; it refreshes from https://gikyokutosyokan.com when online.

## 引用のあらすじ
「引用」「出典」「転載」の語か URL を含むあらすじは、再配布の扱いを確かめるまで API で除いている（2026-11-04 時点で 300 件中 3 件）。表記のない引用が残っている可能性はある。
