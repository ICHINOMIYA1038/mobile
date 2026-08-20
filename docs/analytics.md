# 計測（ダウンロード数・利用状況・クラッシュ）

「どれだけ入れられて、どれだけ使われて、どこで落ちているか」を見るための方針。
実装は共有パッケージ [`packages/app_insights`](../packages/app_insights) にまとめてある。

## 3層で見る

| 層 | 見えるもの | 実装 |
| --- | --- | --- |
| ストアのコンソール | ダウンロード数、アンインストール、表示回数、コンバージョン率 | 不要 |
| Firebase Analytics (GA4) | DAU/MAU、継続率、画面遷移、アプリ固有の行動 | `app_insights` |
| Firebase Crashlytics | クラッシュ、ANR、発生端末とスタックトレース | `app_insights` |

ダウンロード数を知りたいだけならストアのコンソールで足りる。逆にそこでは
アプリの中で何が起きているかは一切分からないので、2層目以降を入れている。

- App Store Connect → App Analytics
- Google Play Console → 統計情報

## Firebase の構成

**1プロジェクトに全アプリを集約する。**

- プロジェクト: `ichinomiya-apps`（コンソール: https://console.firebase.google.com/project/ichinomiya-apps ）
- アプリごとに iOS / Android の Firebase アプリを登録する（Bundle ID がキー）
- GA4 プロパティも1つ。アプリの区別は GA4 の「ストリーム名」ディメンションで行う

アプリを1本増やすたびにプロジェクトを作らずに済み、「全アプリ合計の DAU」と
「アプリ別の継続率の比較」を1つの画面で見られるのが理由。分離したくなったら
（アプリを譲渡・売却するなど）そのアプリだけ別プロジェクトに切り出す。

## 新規アプリ

`scripts/create_app.sh` が配線まで済ませる。追加の作業は要らない。

```sh
./scripts/create_app.sh takken_mock_exam jp.pairof.takken.mockexam
```

スクリプトがやること:

1. 要求された Bundle ID を iOS / Android に反映（Firebase の設定ファイルは Bundle ID をキーに配られるため）
2. `firebase_core` / `firebase_crashlytics` / `app_insights` を依存に追加
3. `flutterfire configure` で Firebase 側にアプリを登録し、設定ファイルと `firebase_options.dart` を生成
   （Android の gradle プラグインと、iOS のクラッシュ用 dSYM アップロード Build Phase もここで入る）
4. 計測を配線済みの `lib/main.dart` を配置

### iOS の対応OSは15以上になる

Firebase の iOS SDK は **iOS 15.0 以上**を要求する。`flutter create` の既定値
（13.0）のままだと `requires minimum platform version 15.0` でビルドが通らない。
`create_app.sh` は最初から 15.0 で作るが、既存アプリに後から入れる場合は
`IPHONEOS_DEPLOYMENT_TARGET` と `ios/Podfile` の `platform :ios` を上げること。

**リリース済みアプリでは最低対応OSの引き上げ（iOS 13/14 の端末が対象外になる）
にあたるので、ストアの対応OS表記も変わる。**

### 設定ファイルはコミットする

`google-services.json` と `GoogleService-Info.plist` はリポジトリに入れる。中身の
API キーは Bundle ID で用途が制限されたクライアント用の値で、配信済みのアプリから
誰でも取り出せるため秘密ではない。gitignore すると CI でビルドできなくなる。

秘密なのは署名鍵（`android/key.properties`）とサービスアカウント JSON のほうで、
そちらは従来どおり入れないこと。

## 既存アプリに後から入れる

```sh
cd apps/<app>
flutter pub add firebase_core firebase_crashlytics 'app_insights:{"path":"../../packages/app_insights"}'
flutterfire configure --project=ichinomiya-apps --platforms=android,ios \
  --ios-bundle-id=<bundle_id> --android-package-name=<bundle_id> --yes
```

そのうえで `lib/main.dart` を配線し、`analysis_options.yaml` に `build/**` の
除外を足す（Firebase を入れると `build/` 配下に依存パッケージのソースが展開され、
`flutter analyze` が大量の指摘を出すため）。

導入済み: `takken_simple`

## イベントの書き方

```dart
await AppInsights.logEvent('question_answered', parameters: {'is_correct': 1});
```

### 命名規約

- `snake_case`、英字始まり、40文字以内
- `firebase_` `google_` `ga_` で始まる名前は予約されていて使えない
- 動詞は過去形（`quiz_started` / `question_answered` / `study_session_finished`）
- パラメータは1イベントにつき25個まで、文字列の値は100文字まで

GA4 は規約違反のイベントをエラーではなく**無言の破棄**で扱う。気付けるよう
`AppInsights.logEvent` はデバッグビルドで assert する。

### 何を計測するか

自動で取れるものは書かない。`first_open` `session_start` `screen_view`
`app_remove` `in_app_purchase` は Firebase が勝手に収集する。

手で足す価値があるのは、**そのアプリの成否を判断する行動**だけ:

- 中心となる機能が実際に使われたか（`quiz_started`、`etude_generated`、…）
- 一連の流れを最後まで終えたか（`study_session_finished`）
- どこで離脱したか（回数や順番をパラメータに入れる）

「なんとなく取っておく」イベントは増やさない。GA4 のカスタムディメンションは
プロパティあたり50個までで、後から消しても枠が戻らない。

### 画面遷移

`AppInsights.navigatorObservers` が `screen_view` を記録するのは
`RouteSettings.name` が設定されているルートだけ。名前を付け忘れた画面は
GA4 上で存在しないことになる。

```dart
MaterialPageRoute(
  settings: const RouteSettings(name: 'result'),
  builder: (_) => const ResultScreen(),
)
```

## デバッグビルドは計測しない

開発中のセッションが本番の DAU や継続率に混ざらないよう、`kDebugMode` では
収集を無効化している。実機で計測の実装そのものを確認したいときだけ:

```dart
await AppInsights.initialize(
  options: DefaultFirebaseOptions.currentPlatform,
  collectInDebug: true,
);
```

そのうえで DebugView を使うと、イベントが数秒で流れてくるのが見える。

```sh
# Android
adb shell setprop debug.firebase.analytics.app <bundle_id>
# iOS: Xcode の Scheme → Run → Arguments に -FIRDebugEnabled を追加
```

通常の（DebugView を使わない）計測は最大24時間ほど遅れて GA4 に反映される。
入れた直後に「データが出ない」と焦らないこと。

## ストアのプライバシー申告

手順（どこを押して何を選ぶか）は [console-runbook.md](console-runbook.md) にある。

**計測を入れたアプリは、申告とプライバシーポリシーの両方を必ず更新する。**
実装と記載がずれている状態がいちばん危険で、審査で落ちる。

App Store Connect →「App のプライバシー」:

| データ | 用途 | トラッキング |
| --- | --- | --- |
| 識別子 → デバイスID | 分析、App の機能 | いいえ |
| 使用状況データ → 製品操作 | 分析 | いいえ |
| 診断 → クラッシュデータ、パフォーマンスデータ | 分析 | いいえ |

Google Play Console →「データセーフティ」:

| データ | 収集 | 共有 | 用途 |
| --- | --- | --- | --- |
| アプリのアクティビティ → アプリの操作 | はい | いいえ | 分析 |
| アプリの情報とパフォーマンス → クラッシュログ、診断 | はい | いいえ | 分析 |
| デバイスまたはその他のID | はい | いいえ | 分析 |

### ATT（iOS）との関係

Firebase Analytics は IDFA なしでも動く。DAU・継続率・イベントはすべて
取れるので、**計測のために ATT の許諾を求める必要はない**。ATT が要るのは
広告のパーソナライズなど、アプリをまたいだトラッキングをする場合だけ。

「トラッキング」に該当しない申告（上表の「トラッキング: いいえ」）を維持する
ため、`AppInsights.setUserProperty` に個人を特定できる値を入れないこと。

## AdMob との連携

広告を出しているアプリは、AdMob コンソールでアプリを Firebase にリンクすると
広告収益が GA4 に流れ込み、「1ユーザーあたりいくら稼いでいるか」まで見える。
AdMob コンソール → アプリ → アプリ設定 → Firebase にリンク（手作業）。
