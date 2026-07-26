# Applications

App Store / Google Playへ配信するFlutterアプリを、1ディレクトリにつき1本置きます。

## 命名

- ディレクトリ名・Dart package名: `snake_case`
- 宅建シリーズ: `takken_<役割>`
- Bundle ID: 所有ドメインを逆順にした接頭辞（`jp.pairof.*` または `com.gikyokutosyokan.*`）
- 表示名、アイコン、課金商品、広告ID、ストア資料はアプリごとに管理

例:

| ディレクトリ | 役割 | Bundle ID例 |
| --- | --- | --- |
| `takken_simple` | 既存の一問一答 | `jp.pairof.takken` |
| `takken_mock_exam` | 50問の模擬試験 | `jp.pairof.takken.mockexam` |
| `takken_terms` | 用語・暗記特化 | `jp.pairof.takken.terms` |

新規作成にはルートの `scripts/create_app.sh` を使います。既存ディレクトリや既存Bundle IDと
重複する場合は作成しません。

```sh
./scripts/create_app.sh takken_mock_exam jp.pairof.takken.mockexam
```
