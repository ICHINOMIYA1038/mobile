# App Store 提出メモ

観た舞台を半券にして集める観劇記録アプリ。戯曲図書館のアプリから 2026-11-06 に分離した。サーバー、DB、戯曲 ID、運営画面は戯曲図書館と共通。

## 状態
| 項目 | 状態 |
|---|---|
| Bundle ID | `com.gikyokutosyokan.theaterlog` |
| ログインの戻り先 | `gikyokutheaterlog://auth-callback`（戯曲 ID の許可リストに登録済み） |
| Firebase のアプリ登録 | 済（`ichinomiya-apps`） |
| アプリの名前 | 未定。表示名は仮に「観劇記録」 |
| ASC のアプリ登録、TestFlight | 未（名前が決まってから） |
| ストアの資料、プライバシー申告 | 未 |

対応端末は iPhone のみ。サーバー側の確認は gikyoku_tosyokan の `scripts/test-app-api.mjs`。
