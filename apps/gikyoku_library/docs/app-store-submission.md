# App Store 提出メモ

## 状態（2026-11-04）
| 項目 | 状態 |
|---|---|
| Firebase のアプリ登録 | 済（`ichinomiya-apps`） |
| アイコン | 済（`tool/make_icon.py`） |
| カタログ API | 本番で稼働（gikyoku_tosyokan #594） |
| プライバシーポリシー | サイトの PR に追記 |
| ASC のアプリ登録 | 未（API では作れないのでオーナーの操作） |
| スクリーンショット | 未 |
| 実機の確認 | 未 |

対応端末は iPhone のみ（`TARGETED_DEVICE_FAMILY = 1`）。

## App のプライバシー（申告内容）
- トラッキング: なし
- 使用状況データ → 製品の操作: 分析目的、ユーザーに紐付けない（Firebase Analytics。画面遷移、絞り込みの種類、開いた作品と候補の操作）
- 診断 → クラッシュデータ: 分析目的、ユーザーに紐付けない（Crashlytics）
- 候補リストの中身は端末の中だけ。ただし追加と削除の計測で作品 ID を送る

## 審査メモ（案）
This app helps theatre groups and school drama clubs choose a play to stage. It needs no account. Filter plays by cast size and running time on the search tab, tap the bookmark to add plays to the shortlist tab, and compare or share them there. The catalog is bundled, so filtering works offline; it refreshes from https://gikyokutosyokan.com when online.

## 引用のあらすじ
「引用」「出典」「転載」の語か URL を含むあらすじは、再配布の扱いを確かめるまで API で除いている（2026-11-04 時点で 300 件中 3 件）。表記のない引用が残っている可能性はある。
