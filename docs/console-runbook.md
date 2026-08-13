# コンソール作業の手順書

計測まわりで **CLI から実行できず、ブラウザでの操作が必要になる作業**の手順。
クリック位置ではなく「何を選ぶか」を記録してあるので、UI が変わっても読み替えられる。

方針そのものは [analytics.md](analytics.md) を参照。

## CLI でできること / できないこと

先に CLI を試すこと。ブラウザ操作は最後の手段。

| 作業 | 手段 |
| --- | --- |
| Firebase プロジェクト作成 | `firebase projects:create <id> --display-name "<name>"` |
| iOS / Android アプリ登録 | `flutterfire configure` が未登録なら自動で作る |
| 設定ファイル・`firebase_options.dart` 生成 | `flutterfire configure` |
| Android の gradle プラグイン追加 | `flutterfire configure` |
| iOS の dSYM アップロード Build Phase | `flutterfire configure` |
| リンク状態の確認 | Firebase Management API（下記） |
| **GA4 のリンク** | **ブラウザのみ** |
| **App Store のプライバシー申告** | **ブラウザのみ** |
| **Play のデータセーフティ申告** | **ブラウザのみ** |
| **AdMob と Firebase のリンク** | **ブラウザのみ** |

### リンク状態の確認（CLI）

申告や設定の結果は、このエンドポイントで機械的に確認できる。
`x-goog-user-project` ヘッダが無いと 403 になる。

```sh
TOKEN=$(gcloud auth print-access-token --account=ichiryo108@gmail.com)
curl -s -H "Authorization: Bearer $TOKEN" \
     -H "x-goog-user-project: ichinomiya-apps" \
     "https://firebase.googleapis.com/v1beta1/projects/ichinomiya-apps/analyticsDetails"
```

- 404 → GA4 が未リンク
- 200 → `analyticsProperty` と、アプリごとの `streamMappings` が返る

**GA4 のリンク自体を API から実行するのは避けること。** `projects:addGoogleAnalytics`
には `analytics.readonly` スコープが要るが、gcloud の ADC には含まれていない。
足すには `gcloud auth application-default login --scopes=...` が必要で、
ユーザーの既存 ADC を上書きしてしまう。1クリックの手作業のほうが安い。

---

## 1. GA4 のリンク（Firebase コンソール）

**これをやるまで、SDK がイベントを送ってもデータの行き先が無い。**

1. https://console.firebase.google.com/project/ichinomiya-apps/settings/integrations
2. 「Google Analytics」カード →「有効にする」
3. アカウントを選択 → `Ichinomiya Apps`（既存。無ければ「新しいアカウントを作成」）
4. **アナリティクスの地域: 日本** ← 既定はアメリカ合衆国。ここで直すこと
5. データ共有・利用規約のチェックは既定で入っている。内容を確認する
6. 「Google アナリティクスを有効にする」

### 落とし穴

**手順4を飛ばしても後から直せる。** ただし場所が変わる:

GA コンソール → 管理 → プロパティ → プロパティの詳細
https://analytics.google.com/analytics/web/#/a404046761p549171598/admin/property/settings

- レポートのタイムゾーン: **日本 / (GMT+09:00) 日本時間**
- 通貨の表示: **日本円 (¥)**

保存には「お店やサービスの詳細」の3項目が必須。現在の設定:

- 業種: 仕事、教育
- ビジネスの規模: 小規模 - 従業員数 1〜10 名
- ビジネスの目標: ウェブ/アプリのトラフィックの分析、ユーザーエンゲージメントとユーザー維持率の把握

保存時にタイムゾーン変更の確認ダイアログが出る（変更は以降のデータにのみ反映）。

---

## 2. App Store のプライバシー申告

https://appstoreconnect.apple.com/apps → アプリ → 配信 → 信頼と安全 → アプリのプライバシー

**先に現在の申告を読むこと。** 広告を出しているアプリには AdMob 分の申告が既にあり、
編集フローは「今ある選択に足す」形なので、既存のチェックを外さないよう注意する。

### 手順

「データタイプ」の**編集**から:

1. 「はい、このアプリからデータを収集します」→ 次へ
2. 説明文 → 次へ
3. チェックを**追加**する（既存のチェックはそのまま）:
   - 使用状況データ → **製品の操作**
   - 診断 → **クラッシュデータ**
   - 診断 → **パフォーマンスデータ**
4. 続ける →「追加の設定が必要です」→ OK

追加した3つそれぞれに「◯◯を設定」が出るので、**同じ回答を3回**繰り返す:

| 質問 | 回答 |
| --- | --- |
| どのように使用されるか | **アナリティクス** |
| ユーザの個人情報に関連付けられるか | **いいえ** |
| トラッキング目的で使用するか | **いいえ** |

最後に「公開」。**ライブのプロダクトページに即時反映される**（新バージョンの提出は不要）。

### 完了状態（takken_simple の実例）

| データタイプ | 用途 |
| --- | --- |
| ID → デバイスID | サードパーティ広告 |
| 使用状況データ → 広告データ | サードパーティ広告 |
| 使用状況データ → 製品の操作 | アナリティクス |
| 診断 → クラッシュデータ | アナリティクス |
| 診断 → パフォーマンスデータ | アナリティクス |

### 注意

- フォームにこう書かれている: 「アプリが現在App Storeで公開されている場合は、回答が
  そのアプリバージョンからのみ収集されたデータを反映していることを確認してください」。
  **本来は Firebase 入りのビルドを提出するときに申告を更新する。**
  先に申告すると過剰申告になる（過少申告よりは安全側だが、正しい順序ではない）。
- プライバシーポリシーURLの変更だけは新バージョンの作成が必要。他は即時反映。
- `デバイスID` の用途は「サードパーティ広告」のまま。Firebase Analytics も端末識別子を
  使うので「アナリティクス」を足す余地はあるが、既存申告の書き換えになるため未実施。

---

## 3. Play のデータセーフティ申告

https://play.google.com/console → デベロッパーアカウント `ichiryo108` → アプリ →
ポリシーとプログラム → アプリのコンテンツ → データセーフティ

申告内容:

| データの種類 | 収集 | 共有 | 用途 |
| --- | --- | --- | --- |
| アプリのアクティビティ → アプリの操作 | はい | いいえ | 分析 |
| アプリの情報とパフォーマンス → クラッシュログ | はい | いいえ | 分析 |
| アプリの情報とパフォーマンス → 診断 | はい | いいえ | 分析 |
| デバイスまたはその他のID | はい | いいえ | 分析 |

### 対象アプリを間違えないこと

**Play と App Store で配信しているアプリは一致しない。**
`takken_simple`（`jp.pairof.takken`）は **iOS のみ**で、Play には存在しない。

2026年8月時点で Play にあるのは4本:

| アプリ | パッケージ名 | このリポジトリ |
| --- | --- | --- |
| ネタメーカー | `jp.pairof.netamaker` | `apps/neta_maker` |
| 猫と学ぶ高校化学 | `jp.pairof.nekoChemistry` | `apps/neko_chemistry` |
| エチュードメーカー | `com.gikyokutosyokan.etude` | `apps/etude_generator` |
| tryroop_campus | `com.tryroop.tryroop_campus_live_flutter` | 別リポジトリ |

つまり `apps/` の8本のうち Play に出ているのは3本だけで、
`takken_simple` / `korokoro_slope` / `neta_gacha` / `tomoshibi` / `sound_shield` は未配信。

作業前に必ずアプリ一覧を確認する。パッケージ名で検索できる。

---

## 4. AdMob と Firebase のリンク（任意）

広告を出しているアプリは、リンクすると広告収益が GA4 に流れ込み、
ユーザーあたりの収益まで見えるようになる。

https://apps.admob.com → アプリ → アプリ設定 → Firebase にリンク

未実施。

---

## ブラウザ自動化の注意

Claude Code の Chrome 連携で操作する場合:

- **認証情報の入力はできない。** サインインは人がやる。ターミナルから
  `! open https://appstoreconnect.apple.com/apps` で開いて、そのタブでサインインすれば、
  Cookie は共有されるので自動化側のタブでも認証が通る。
- **Google 系（Firebase / GA / Play / AdMob）はセッションが共有される。** どれか1つに
  サインインしていれば他も通ることが多い。Apple は別。
- 座標クリックはビューポートが変わると外れる。`find` で要素参照を取ってから
  参照でクリックするほうが安定する。ただし**ページが再描画されると参照は失効する**ので、
  スクロールや遷移のあとは取り直すこと。
- モーダルの中身は `get_page_text`（`<main>` を読む）に出てこないことがある。
  スクリーンショットか `find` で確認する。
- **送信ボタンを押す前に必ずスクリーンショットで状態を確認する。** GA4 の設定では、
  地域を変更する前に有効化が確定してしまい、あとから直す羽目になった。
