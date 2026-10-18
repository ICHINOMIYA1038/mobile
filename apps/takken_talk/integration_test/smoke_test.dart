import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/main.dart';
import 'package:takken_talk/state/app_state.dart';

/// 通しの確認: 起動 → 下のタブを全部開く → 章の会話 → 過去問で1問答えて「AIに聞く」。
/// 手元のサイトに向けて動かす（AI はモックの定型文）:
///   flutter test integration_test/smoke_test.dart -d <シミュレーター> --dart-define=API_BASE=http://localhost:3140
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 4]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('タブ・会話・過去問・AIに聞く', (tester) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester);
    expect(find.text('カリキュラム'), findsOneWidget);

    for (final tab in ['過去問', '復習', '図解', '設定', '学ぶ']) {
      await tester.tap(find.text(tab).last);
      await settle(tester, 3);
      expect(tester.takeException(), isNull, reason: tab);
    }

    // 章の会話（最初の一言が流れてくる）
    await tester.tap(find.textContaining('から始める').first);
    await settle(tester, 6);
    expect(find.byType(TextField), findsWidgets);
    await tester.pageBack();
    await settle(tester, 2);
    expect(find.text('カリキュラム'), findsOneWidget, reason: '会話から戻れる');

    // 過去問: 令和7年度で1問答えて、AIに聞く
    await tester.tap(find.text('過去問').last);
    await settle(tester, 3);
    await tester.tap(find.text('令和7年度').first);
    await settle(tester, 8);
    if (find.text('○ 正しい').evaluate().isEmpty) {
      // ignore: avoid_print
      print('SEEN: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().take(60).join(' | ')}');
    }
    await tester.tap(find.text('○ 正しい').first);
    await settle(tester, 3);
    expect(find.textContaining('あなたの答え'), findsWidgets);
    await tester.tap(find.text('AIに聞く').last);
    await settle(tester, 3);
    await tester.tap(find.textContaining('なぜ').first);
    await settle(tester, 6);
    expect(find.textContaining('開発モードの定型文'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
