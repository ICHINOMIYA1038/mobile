import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theater_log/account/auth_service.dart';
import 'package:theater_log/catalog/log_photos.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/main.dart';

import 'fake_photo.dart';

/// 500 本記録し、写真も多い人の使い方を実機で通す（中身は動作確認用の仮のデータ）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('めくる、写真を送る、一覧を端まで流す、探す、消す', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const hold = Duration(seconds: 3);
    final log = TheaterLog();
    final base = await fakeStagePhoto();
    final photos = <String>[];
    for (var i = 0; i < 4; i++) {
      photos.add(await fakeStagePhoto(seed: i + 1));
    }
    // 写真は記録ごとに別のファイルにする（1 本消しても、ほかの記録の写真は残る）
    Future<String> copy(String name) async => LogPhotos.save(await LogPhotos.file(name));
    for (var i = 0; i < 500; i++) {
      final withPhotos = i % 10 == 0;
      await log.upsert(
        TheaterLogEntry(
          id: 'h$i',
          title: '動作確認の舞台 ${500 - i}',
          watchedOn: DateTime(2026, 11, 7).subtract(Duration(days: i)),
          venue: '仮の劇場${i % 7}',
          rating: 1 + i % 5,
          note: i % 3 == 0 ? List.filled(12, '動作確認用の仮の感想です。').join() : '',
          photos: withPhotos ? [for (var k = 0; k < 3; k++) await copy(k == 0 ? base : photos[(i + k) % 4])] : const [],
        ),
      );
    }
    final repository = CatalogRepository();
    final sw = Stopwatch()..start();
    await tester.pumpWidget(App(repository: repository, catalog: await repository.load(), log: log, auth: AuthService()));
    await tester.pumpAndSettle();
    debugPrint('HEAVY first frame ${sw.elapsedMilliseconds}ms');
    expect(find.text('1 / 500'), findsOneWidget);
    await Future<void>.delayed(hold);

    // 写真 3 枚を送り、次の記録へ
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(330, 400));
      await tester.pumpAndSettle();
    }
    expect(find.text('2 / 500'), findsOneWidget);

    // 続けて 30 本めくる
    sw.reset();
    for (var i = 0; i < 30; i++) {
      await tester.fling(find.byKey(const Key('log-story')), const Offset(-300, 0), 2000);
      await tester.pumpAndSettle();
    }
    debugPrint('HEAVY 30 pages ${sw.elapsedMilliseconds}ms');
    await Future<void>.delayed(hold);

    // 一覧を端まで流して戻る
    await tester.tap(find.byKey(const Key('log-view-toggle')));
    await tester.pumpAndSettle();
    sw.reset();
    for (var i = 0; i < 40; i++) {
      await tester.fling(find.byKey(const Key('log-list')), const Offset(0, -600), 6000);
      await tester.pumpAndSettle();
    }
    debugPrint('HEAVY list fling ${sw.elapsedMilliseconds}ms');
    expect(find.text('動作確認の舞台 1'), findsOneWidget);
    await Future<void>.delayed(hold);
    for (var i = 0; i < 40; i++) {
      await tester.fling(find.byKey(const Key('log-list')), const Offset(0, 600), 6000);
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byKey(const Key('log-search')), '舞台 451');
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((w) => w is Text && w.data == '動作確認の舞台 451'));
    await tester.pumpAndSettle();
    expect(find.text('50 / 500'), findsOneWidget);
    await Future<void>.delayed(hold);

    // 開いている 1 本を消すと、隣の 1 本が出る
    await tester.tap(find.byKey(const Key('story-edit')));
    await tester.pumpAndSettle();
    final del = find.text('この記録を削除');
    await tester.scrollUntilVisible(del, 300, scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(del);
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);
    await tester.tap(find.widgetWithText(TextButton, '削除'));
    await tester.pumpAndSettle();
    expect(log.entries.length, 499);
    expect(find.text('50 / 499'), findsOneWidget);
    expect(find.text('動作確認の舞台 450'), findsOneWidget);
    await Future<void>.delayed(hold);
  });
}
