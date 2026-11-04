import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:theater_log/account/auth_service.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 劇場スタンプ、みんなのひとこと、ふりかえりを通す（記録は動作確認用の仮のデータ。劇場名はカタログの実在の名前）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('スタンプ、地図、ふりかえり、みんな', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const hold = Duration(seconds: 5);
    final repository = CatalogRepository();
    final catalog = await repository.load();
    final log = TheaterLog();
    final now = DateTime.now();
    final sample = [catalog.venues.first, ...catalog.venues.where((v) => v.prefecture == '東京都').take(3), catalog.venues.firstWhere((v) => v.prefecture == '大阪府'), catalog.venues.firstWhere((v) => v.prefecture == '北海道')];
    for (var i = 0; i < sample.length; i++) {
      await log.upsert(TheaterLogEntry(id: 'v$i', title: '動作確認の舞台 ${i + 1}', watchedOn: DateTime(now.year, 2 + i % 3, 3 + i), group: '仮の劇団${i % 2 + 1}', venue: sample[i].name, rating: 3 + i % 3));
    }
    await tester.pumpWidget(App(repository: repository, catalog: catalog, log: log, auth: AuthService()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('スタンプ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('劇場スタンプ'), findsOneWidget);
    await Future<void>.delayed(hold);

    await tester.tap(find.byKey(const Key('pref-東京都')));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-recap')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recap-count')), findsOneWidget);
    await Future<void>.delayed(hold);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('みんな'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 15));
    await Future<void>.delayed(hold);
  });
}
