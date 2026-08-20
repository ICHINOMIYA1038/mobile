# app_insights

全アプリ共通の計測基盤。Firebase Analytics（利用状況）と Crashlytics（クラッシュ）を
1つの窓口にまとめています。

方針・イベント命名規約・ストアのプライバシー申告については
[`docs/analytics.md`](../../docs/analytics.md) を参照してください。

## 使い方

`pubspec.yaml`:

```yaml
dependencies:
  app_insights:
    path: ../../packages/app_insights
```

`lib/main.dart`:

```dart
import 'package:app_insights/app_insights.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
```

`MaterialApp`:

```dart
MaterialApp(
  navigatorObservers: AppInsights.navigatorObservers,
  ...
)
```

イベントの記録:

```dart
await AppInsights.logEvent('question_answered', parameters: {'correct': 1});
await AppInsights.setUserProperty('study_mode', 'random');
await AppInsights.recordError(error, stackTrace, reason: '問題データの読み込み');
```

## 設計上の約束

- **計測はアプリを落とさない。** 初期化に失敗すると `isEnabled` が false になり、
  以降の呼び出しはすべて何もしません。`flutterfire configure` の対象外である
  web / macOS ビルドや、Firebase の無いユニットテストでもそのまま動きます。
- **デバッグビルドは計測しない。** 開発中のセッションが本番の DAU や継続率に
  混ざらないよう、`kDebugMode` では収集を無効化します。実機で計測の実装を
  確認したいときだけ `initialize(collectInDebug: true)` を使ってください。
- **イベント名は debug ビルドの assert で検証されます。** GA4 は規約違反の
  イベントをエラーではなく無言の破棄で扱うため、気付けるようにしています。

## 画面遷移の記録についての注意

`navigatorObservers` が `screen_view` を記録するのは `RouteSettings.name` が
設定されているルートだけです。名前を付け忘れた画面は GA4 上で存在しないことに
なります。

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    settings: const RouteSettings(name: 'result'),
    builder: (_) => const ResultScreen(),
  ),
);
```
