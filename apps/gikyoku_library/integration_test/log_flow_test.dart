import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_library/catalog/catalog_repository.dart';
import 'package:gikyoku_library/catalog/shortlist.dart';
import 'package:gikyoku_library/catalog/theater_log.dart';
import 'package:gikyoku_library/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 観劇ノートの流れを、同梱のカタログで通す（本文は動作確認用の仮の文）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('作品を選んで記録し、ノートから台本情報へ進む', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const hold = Duration(seconds: 6);
    final repository = CatalogRepository();
    final log = TheaterLog();
    await log.upsert(TheaterLogEntry(id: 'x', title: '動作確認の舞台', watchedOn: DateTime(2026, 9, 12), group: '動作確認の劇団', venue: '動作確認の劇場', rating: 3, note: '自由入力の記録の表示を確かめるための仮の文です。'));
    await tester.pumpWidget(App(repository: repository, catalog: await repository.load(), shortlist: Shortlist(), log: log));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('log-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log-title')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('log-title')), 'エダニク');
    await tester.pumpAndSettle();
    await tester.tap(find.text('横山拓也').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.enterText(find.byKey(const Key('log-note')), '動作確認用の仮の感想です。');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);

    await tester.tap(find.byKey(const Key('log-save')));
    await tester.pumpAndSettle();
    expect(log.entries.where((e) => e.title == 'エダニク').single.playId, isNotNull);
    await Future<void>.delayed(hold);

    await tester.tap(find.byKey(const Key('log-to-play')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('log-this-play')), findsOneWidget);
    await Future<void>.delayed(hold);
  });
}
