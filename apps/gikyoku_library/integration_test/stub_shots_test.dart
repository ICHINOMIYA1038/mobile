import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_library/account/auth_service.dart';
import 'package:gikyoku_library/catalog/catalog_repository.dart';
import 'package:gikyoku_library/catalog/shortlist.dart';
import 'package:gikyoku_library/catalog/theater_log.dart';
import 'package:gikyoku_library/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 半券の体験を通す（中身は動作確認用の仮のデータ）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('初回、3 秒の記録、スタンプ、半券帳、スタンプ帳', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const hold = Duration(seconds: 5);
    final repository = CatalogRepository();
    final log = TheaterLog();
    await tester.pumpWidget(App(repository: repository, catalog: await repository.load(), shortlist: Shortlist(), log: log, auth: AuthService()));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);

    await tester.tap(find.byKey(const Key('first-stub')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quick-title')), 'エダニク');
    await tester.pumpAndSettle();
    await tester.tap(find.text('横山拓也').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-star-4')));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);

    await tester.tap(find.byKey(const Key('quick-save')));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);
    await tester.tap(find.byKey(const Key('stamped-close')));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    for (var i = 0; i < 5; i++) {
      await log.upsert(TheaterLogEntry(id: 's$i', title: '動作確認の舞台 ${i + 1}', watchedOn: DateTime(now.year, now.month - 1 - i % 2, 3 + i * 3), group: '仮の劇団${i % 2 + 1}', venue: '仮の劇場${i + 1}', rating: 3 + i % 3, showTime: i.isEven ? 'soiree' : 'matinee', note: i.isEven ? '動作確認用の仮の感想です。' : ''));
    }
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);

    await tester.tap(find.text('スタンプ'));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);
  });
}
