import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fp1_talk/api/client.dart';
import 'package:fp1_talk/main.dart';
import 'package:fp1_talk/state/app_state.dart';

/// 会話の入力欄のキーボードが閉じられること（会話を押す・動かす・送る）。
///   flutter test integration_test/keyboard_test.dart -d <シミュレーター>（本番。--dart-define=API_BASE=… で手元のサイト）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  bool typing(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField).first).focusNode?.hasFocus ?? FocusManager.instance.primaryFocus?.context?.widget is EditableText;
  bool keyboardOpen() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>() != null;

  testWidgets('キーボードを閉じられる', (tester) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester, 6);
    await tester.tap(find.textContaining('から始める').first);
    await settle(tester, 25);

    final field = find.byType(TextField).first;
    final log = find.byType(ListView).first;

    // 会話の部分を押すと閉じる
    await tester.tap(field);
    await settle(tester);
    expect(keyboardOpen(), isTrue);
    await tester.tapAt(tester.getCenter(log));
    await settle(tester);
    expect(keyboardOpen(), isFalse, reason: '会話を押したら閉じる');

    // 会話を動かすと閉じる
    await tester.tap(field);
    await settle(tester);
    expect(keyboardOpen(), isTrue);
    await tester.drag(log, const Offset(0, 200));
    await settle(tester);
    expect(keyboardOpen(), isFalse, reason: '会話を動かしたら閉じる');

    // 送ると閉じる
    await tester.tap(field);
    await settle(tester);
    await tester.enterText(field, 'ありがとう');
    await settle(tester);
    expect(keyboardOpen(), isTrue);
    for (var i = 0; i < 20 && keyboardOpen(); i++) {
      await tester.tap(find.widgetWithText(FilledButton, '送る'), warnIfMissed: false);
      await settle(tester, 2);
    }
    expect(keyboardOpen(), isFalse, reason: '送ったら閉じる');
    expect(typing(tester), isFalse);
    expect(tester.takeException(), isNull);
  });
}
