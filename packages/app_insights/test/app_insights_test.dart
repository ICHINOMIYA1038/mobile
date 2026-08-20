import 'package:app_insights/app_insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(AppInsights.resetForTesting);

  group('未初期化のとき', () {
    test('計測は無効', () {
      expect(AppInsights.isEnabled, isFalse);
    });

    test('navigatorObservers は空なので MaterialApp にそのまま渡せる', () {
      expect(AppInsights.navigatorObservers, isEmpty);
    });

    // Firebase の無いユニットテストや web ビルドでアプリが落ちないことが
    // このパッケージの前提なので、ここは特に守りたい。
    test('logEvent / setUserProperty / recordError は例外を投げずに何もしない', () async {
      await expectLater(AppInsights.logEvent('anything'), completes);
      await expectLater(AppInsights.setUserProperty('mode', 'a'), completes);
      await expectLater(
        AppInsights.recordError(Exception('boom'), StackTrace.current),
        completes,
      );
    });
  });

  group('イベント名の検証', () {
    test('規約に沿った名前は通る', () async {
      await expectLater(AppInsights.logEvent('question_answered'), completes);
      await expectLater(
        AppInsights.logEvent('quiz1', parameters: {'correct': 1}),
        completes,
      );
    });

    test('GA4 が黙って捨てる名前は assert で落ちる', () {
      expect(() => AppInsights.logEvent('1_starts_with_digit'), throwsAssertionError);
      expect(() => AppInsights.logEvent('has space'), throwsAssertionError);
      expect(() => AppInsights.logEvent('has-hyphen'), throwsAssertionError);
      expect(() => AppInsights.logEvent(''), throwsAssertionError);
      expect(() => AppInsights.logEvent('a' * 41), throwsAssertionError);
    });

    test('Firebase の予約プレフィックスは assert で落ちる', () {
      expect(() => AppInsights.logEvent('firebase_x'), throwsAssertionError);
      expect(() => AppInsights.logEvent('google_x'), throwsAssertionError);
      expect(() => AppInsights.logEvent('ga_x'), throwsAssertionError);
    });

    test('パラメータ名とパラメータ数も検証される', () {
      expect(
        () => AppInsights.logEvent('ok_name', parameters: {'bad name': 1}),
        throwsAssertionError,
      );
      expect(
        () => AppInsights.logEvent(
          'ok_name',
          parameters: {for (var i = 0; i < 26; i++) 'p$i': i},
        ),
        throwsAssertionError,
      );
    });

    test('ユーザー属性名も同じ規約で検証される', () {
      expect(() => AppInsights.setUserProperty('bad name', 'v'), throwsAssertionError);
      expect(AppInsights.setUserProperty('study_mode', 'random'), completes);
    });
  });
}
