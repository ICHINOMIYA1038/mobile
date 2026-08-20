import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:neta_gacha/main.dart';
import 'package:neta_gacha/ui/widgets/prompt_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ホーム画面にシチュエーション一覧が表示される', (tester) async {
    await tester.pumpWidget(const NetaGachaApp());
    await tester.pumpAndSettle();

    expect(find.text('配信ネタガチャ'), findsOneWidget);
    expect(find.text('オープニング'), findsOneWidget);
    expect(find.text('初見さん向け'), findsOneWidget);
  });

  testWidgets('シチュエーションを選ぶと抽選画面に遷移し、お題を引ける', (tester) async {
    await tester.pumpWidget(const NetaGachaApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('オープニング'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('オープニング'));
    await tester.pumpAndSettle();

    expect(find.text('ガチャを引く'), findsOneWidget);

    await tester.tap(find.text('ガチャを引く'));
    await tester.pumpAndSettle();

    expect(find.byType(PromptCard), findsOneWidget);
  });
}
