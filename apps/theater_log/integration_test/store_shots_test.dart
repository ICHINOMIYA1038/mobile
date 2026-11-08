// App Store の画像の素材を撮る。iPhone 16 Pro Max（1320×2868）のシミュレーターで流し、
// 「SHOT 名前」が出たところで xcrun simctl io screenshot する（tool/store_compose/shoot.sh）。
// 記録はこの端末の中の見本で、作品と劇場はカタログにある実在のもの。感想は見本の文で、他の人の感想は出さない。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theater_log/account/auth_service.dart';
import 'package:theater_log/catalog/achievements.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/main.dart';
import 'package:theater_log/screens/quick_log_sheet.dart';
import 'package:theater_log/screens/recap_screen.dart';

const _hold = Duration(seconds: 3);

Future<void> _shot(String name) async {
  debugPrint('SHOT $name');
  await Future<void>.delayed(_hold);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store shots', (tester) async {
    SharedPreferences.setMockInitialValues({'community_rules_v2': true});
    final repository = CatalogRepository();
    final catalog = await repository.load();
    final plays = {for (final p in catalog.plays) p.title: p};
    final log = TheaterLog();
    final y = DateTime.now().year;
    // （題名, 月, 日, 劇場, 劇団, 評価, 昼夜, ひとこと）
    const rows = [
      ('東京ノート', 1, 18, 'こまばアゴラ劇場', '青年団', 5, 'soiree', '美術館のロビーだけで、遠い戦争の気配が伝わってくる。'),
      ('赤鬼', 2, 9, '本多劇場', null, 4, 'matinee', ''),
      ('三月の5日間', 3, 5, 'KAAT神奈川芸術劇場', null, 4, 'soiree', '語りのリズムが体に残る。'),
      ('エダニク', 4, 20, 'ザ・スズナリ', null, 5, 'soiree', '休憩室だけで、ここまで緊張が続くとは。'),
      ('わが星', 5, 11, '座・高円寺', null, 5, 'matinee', 'ラップと時報。帰り道ずっと口ずさんでいた。'),
      ('かもめ', 6, 2, '世田谷パブリックシアター', null, 3, 'soiree', ''),
      ('夏の夜の夢', 7, 26, 'ロームシアター京都', null, 4, 'matinee', '京都まで遠征。森の場面の照明がきれい。'),
      ('赤鬼', 8, 30, 'in→dependent theatre', null, 4, 'soiree', '大阪の小さな劇場で、同じ作品をもう一度。'),
      ('東京ノート', 9, 14, '名古屋市芸術創造センター', null, 4, 'matinee', ''),
      ('エダニク', 10, 4, 'アートマネージメントセンター福岡', null, 5, 'soiree', '福岡でも。客席の笑いの起き方が違う。'),
      ('わが星', 10, 25, '本多劇場', null, 5, 'soiree', ''),
    ];
    for (final (i, r) in rows.indexed) {
      final p = plays[r.$1];
      await log.upsert(TheaterLogEntry(
        id: 'shot$i',
        title: r.$1,
        watchedOn: DateTime(y, r.$2, r.$3),
        playId: p?.id,
        author: p?.author,
        venue: r.$4,
        group: r.$5,
        rating: r.$6,
        showTime: r.$7,
        note: r.$8,
      ));
    }
    await tester.pumpWidget(App(repository: repository, catalog: catalog, log: log, auth: AuthService()));
    await tester.pumpAndSettle();

    // 半券帳（1 枚ずつの表示）
    await _shot('story');

    // 半券帳（一覧）
    await tester.tap(find.byKey(const Key('log-view-toggle')).first);
    await tester.pumpAndSettle();
    await _shot('list');

    // 記録の手順：題名とチケット
    final ctx = tester.element(find.byType(Scaffold).first);
    QuickLogSheet.open(ctx);
    await tester.pumpAndSettle();
    await _shot('record');
    await tester.enterText(find.byKey(const Key('quick-title')), 'エダニク');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flow-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venue-open')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('venue-query')), '本多');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venue-hit-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flow-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-star-5')));
    await tester.enterText(find.byKey(const Key('quick-note')), '同じ作品を 3 回目。見るたびに発見がある。');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _shot('rating');

    // 半券を切って、ハンコが押された画面
    final before = log.entries;
    await tester.tap(find.byKey(const Key('quick-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2600));
    await _shot('stamp');
    expect(newlyEarned(before, log.entries), isA<List<Achievement>>());
    await tester.tap(find.byKey(const Key('stamped-close')));
    await tester.pumpAndSettle();

    // スタンプ帳と劇場スタンプの地図
    await tester.tap(find.byIcon(Icons.verified_outlined).last);
    await tester.pumpAndSettle();
    await _shot('book');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await _shot('map');

    // ふりかえり
    RecapScreen.open(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    await _shot('recap');
  });
}
