import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/models.dart';
import 'package:takken_talk/screens/paywall_screen.dart';
import 'package:takken_talk/state/app_state.dart';

Me _me() => const Me(
      userId: 'u_test',
      nickname: null,
      examDate: '2026-10-18',
      plan: PlanInfo(isPro: false, proUntil: null, turnBalance: 0, freeUsed: 4, freeCap: 80),
      subjects: [],
      chapters: [],
      turnCounts: {},
      currentTopics: {},
      visitedTopics: {},
      lastChapterId: null,
      progress: ProgressSummary.empty,
      live: true,
    );

void main() {
  testWidgets('価格が取れなくてもプランの中身は伝わる', (tester) async {
    // RevenueCat のプラグインはテスト環境に無いので offerings() は必ず失敗する。
    // そのときに「何が買えるのか」が消えてしまわないことを確かめる。
    final state = AppState(ApiClient('http://localhost:0'))..me = _me();
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: PaywallScreen(reason: 'locked')),
      ),
    );
    // _load() が失敗して _loading が下りるまで回す
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('Pro（月額）').evaluate().isNotEmpty) break;
    }

    expect(find.text('Pro（月額）'), findsOneWidget);
    expect(find.text('会話パック 100回'), findsOneWidget);
    expect(find.text('会話パック 300回'), findsOneWidget);
    expect(find.text('もう一度読み込む'), findsOneWidget);

    // 解約と復元の導線は、価格が出ていなくても残っている（審査要件）。
    // ListView は画面外を組み立てないので、下まで送ってから確かめる。
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('購入を復元'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('プライバシー'), findsOneWidget);
  });
}
