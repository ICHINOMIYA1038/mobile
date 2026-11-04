import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_library/account/auth_service.dart';
import 'package:gikyoku_library/catalog/catalog_repository.dart';
import 'package:gikyoku_library/catalog/shortlist.dart';
import 'package:gikyoku_library/catalog/theater_log.dart';
import 'package:gikyoku_library/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 観劇ノートの各画面を通す（中身は動作確認用の仮のデータ）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('一覧、カレンダー、集計、シェアカード', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const hold = Duration(seconds: 5);
    final repository = CatalogRepository();
    final log = TheaterLog();
    final now = DateTime.now();
    for (var i = 0; i < 6; i++) {
      await log.upsert(TheaterLogEntry(id: '$i', title: '動作確認の舞台 ${i + 1}', watchedOn: DateTime(now.year, now.month - i % 3, 3 + i * 4), group: '仮の劇団${i % 2 + 1}', venue: '仮の劇場${i % 3 + 1}', rating: 3 + i % 3, price: 3000 + i * 500, seat: 'C列${i + 1}番', showTime: 'soiree', note: '動作確認用の仮の感想です。'));
    }
    await tester.pumpWidget(App(repository: repository, catalog: await repository.load(), shortlist: Shortlist(), log: log, auth: AuthService()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('log-search')), findsOneWidget);
    await Future<void>.delayed(hold);

    await tester.tap(find.byKey(const Key('log-calendar-toggle')));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);
    await tester.tap(find.byKey(const Key('log-calendar-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('シェアカードを作る').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('card-note')));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('動作確認の舞台 1'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.byKey(const Key('log-details')), find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);
  });
}
