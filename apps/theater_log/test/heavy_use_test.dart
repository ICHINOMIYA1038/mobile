import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theater_log/app_scope.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/screens/log_edit_screen.dart';
import 'package:theater_log/screens/log_screen.dart';
import 'package:theater_log/theme.dart';

import 'test_support.dart';

/// たくさん使う人、写真の多い人、消す人の使い方を通す（中身は動作確認用の仮のデータ）
Widget _scope(TheaterLog log, {Widget home = const Scaffold(body: LogScreen())}) => AppScope(
  catalog: Catalog(generatedAt: DateTime.utc(2026), categories: const [], plays: const [], venues: const []),
  log: log,
  auth: offlineAuth(),
  sync: offlineSync(offlineAuth(), log),
  child: MaterialApp(theme: buildTheme(), home: home),
);

TheaterLogEntry _e(String id, DateTime on, {String? title, String note = '', List<String> photos = const [], String? showTime}) =>
    TheaterLogEntry(id: id, title: title ?? '舞台$id', watchedOn: on, note: note, photos: photos, showTime: showTime, venue: '仮の劇場', rating: 4);

void _phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('1000 本記録した人: 写真表示は 1 本の線、一覧は見える分だけ作り、いちばん下まで行ける。検索で当たらなければそう出す', (tester) async {
    _phone(tester, const Size(393, 852));
    final log = TheaterLog();
    for (var i = 0; i < 1000; i++) {
      await log.upsert(_e('$i', DateTime(2020, 1, 1).add(Duration(days: i))));
    }
    await tester.pumpWidget(_scope(log));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1000'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.byKey(const Key('log-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('舞台').evaluate().length, lessThan(30));
    await tester.scrollUntilVisible(find.text('舞台0'), 3000, scrollable: find.descendant(of: find.byKey(const Key('log-list')), matching: find.byType(Scrollable)).first);
    expect(find.text('舞台0'), findsOneWidget);

    await tester.drag(find.byKey(const Key('log-list')), const Offset(0, 400000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('log-search')), '存在しない題名');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('log-search-empty')), findsOneWidget);

    // 一覧の古い 1 本を選ぶと、写真表示でその 1 本が出る
    await tester.enterText(find.byKey(const Key('log-search')), '舞台3');
    await tester.pumpAndSettle();
    // 当たった 111 本の、いちばん下にある半券を押す（検索欄の文字は除く）
    final stub = find.byWidgetPredicate((w) => w is Text && w.data == '舞台3');
    await tester.scrollUntilVisible(stub, 600, scrollable: find.descendant(of: find.byKey(const Key('log-list')), matching: find.byType(Scrollable)).first);
    await tester.tap(stub);
    await tester.pumpAndSettle();
    expect(find.text('舞台3'), findsOneWidget);
    expect(find.text('997 / 1000'), findsOneWidget);
  });

  testWidgets('見ている途中で記録を足すと足した 1 本へ、日付を直して並びが変わっても同じ 1 本のまま', (tester) async {
    _phone(tester, const Size(393, 852));
    final log = TheaterLog();
    for (var i = 0; i < 5; i++) {
      await log.upsert(_e('$i', DateTime(2026, 10, 1 + i)));
    }
    await tester.pumpWidget(_scope(log));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('舞台2'), findsOneWidget);

    // 今見ている 1 本の日付を、いちばん古くする
    await log.upsert(_e('2', DateTime(2025, 1, 1)));
    await tester.pumpAndSettle();
    expect(find.text('舞台2'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);

    // 新しく記録すると、その 1 本が出る（日付は途中）
    await log.upsert(_e('new', DateTime(2026, 10, 3, 12), title: '今足した舞台'));
    await tester.pumpAndSettle();
    expect(find.text('今足した舞台'), findsOneWidget);
    expect(find.text('3 / 6'), findsOneWidget);
  });

  testWidgets('見ている 1 本を消すと隣の 1 本、全部消すと最初の案内に戻り、タブも明るく戻る', (tester) async {
    _phone(tester, const Size(393, 852));
    final log = TheaterLog();
    for (var i = 0; i < 3; i++) {
      await log.upsert(_e('$i', DateTime(2026, 10, 1 + i)));
    }
    await tester.pumpWidget(_scope(log));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    await log.remove('0');
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('舞台1'), findsOneWidget);
    expect(LogScreen.immersive.value, isTrue);

    await log.remove('1');
    await log.remove('2');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first-stub')), findsOneWidget);
    expect(LogScreen.immersive.value, isFalse);
  });

  testWidgets('写真が何枚もある記録は、押すとまず写真を送り、最後の 1 枚から次の記録へ', (tester) async {
    _phone(tester, const Size(393, 852));
    final log = TheaterLog();
    await log.upsert(_e('old', DateTime(2026, 10, 1)));
    await log.upsert(_e('new', DateTime(2026, 10, 2), photos: const ['p1.jpg', 'p2.jpg', 'p3.jpg']));
    await tester.pumpWidget(_scope(log));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-photo-dots')), findsOneWidget);
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tapAt(const Offset(30, 300));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('長い感想は「続きを読む」で開け、開いている間に押しても次へ行かない', (tester) async {
    _phone(tester, const Size(393, 852));
    final log = TheaterLog();
    await log.upsert(_e('a', DateTime(2026, 10, 1)));
    await log.upsert(_e('b', DateTime(2026, 10, 2), note: List.filled(40, '長い感想の文です。').join()));
    await tester.pumpWidget(_scope(log));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-note-more')), findsOneWidget);
    await tester.tap(find.byKey(const Key('story-note')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-note-more')), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  for (final (name, size) in [('iPhone SE', Size(375, 667)), ('iPhone 16 Pro Max', Size(440, 956))]) {
    testWidgets('$name: 長い題名・長い感想・写真 10 枚・文字を大きくしても、はみ出さない', (tester) async {
      _phone(tester, size);
      final log = TheaterLog();
      await log.upsert(
        TheaterLogEntry(
          id: 'x',
          title: 'とても長い題名の舞台、あるいは終わらない夏の夜の夢とその後日譚 第二部',
          watchedOn: DateTime(2026, 11, 3),
          showTime: 'matinee',
          venue: '東京芸術劇場 シアターイースト',
          seat: '1階 XA列 120番',
          group: 'とても長い名前の劇団プロデュース',
          rating: 5,
          note: List.filled(60, '長い感想。').join(),
          photos: [for (var i = 0; i < 10; i++) 'p$i.jpg'],
        ),
      );
      await log.upsert(TheaterLogEntry(id: 'y', title: List.filled(30, '題').join(), watchedOn: DateTime(2026, 11, 1)));
      await tester.pumpWidget(MediaQuery(data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.3)), child: _scope(log)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('story-note')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byKey(const Key('log-story')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('同じ日のマチネとソワレは、ソワレを上にして、保存し直しても並びが変わらない', () async {
    final log = TheaterLog();
    final day = DateTime(2026, 11, 3);
    await log.upsert(_e('s', day, showTime: 'soiree'));
    await log.upsert(_e('m', day, showTime: 'matinee'));
    await log.upsert(_e('n', day));
    expect(log.entries.map((e) => e.id), ['s', 'n', 'm']);
    for (var i = 0; i < 5; i++) {
      await log.upsert(_e('m', day, showTime: 'matinee', note: '$i'));
      expect(log.entries.map((e) => e.id), ['s', 'n', 'm']);
    }
  });

  group('記録の編集', () {
    testWidgets('チケットから読んだ下書きで編集画面を開くと、座席・金額・昼夜も引き継ぐ', (tester) async {
      _phone(tester, const Size(393, 852));
      final draft = TheaterLogEntry(id: 'draft', title: '読んだ舞台', watchedOn: DateTime(2026, 11, 3), seat: '1階C列12番', price: 5500, showTime: 'matinee');
      await tester.pumpWidget(_scope(TheaterLog(), home: LogEditScreen(draft: draft)));
      await tester.pumpAndSettle();
      expect(find.text('1階C列12番'), findsOneWidget);
      expect(find.text('5500'), findsOneWidget);
    });

    testWidgets('写真は押すと表紙になり、外した写真は保存したときに消える', (tester) async {
      _phone(tester, const Size(393, 852));
      final log = TheaterLog();
      final e = _e('a', DateTime(2026, 11, 3), photos: const ['p0.jpg', 'p1.jpg', 'p2.jpg']);
      await log.upsert(e);
      await tester.pumpWidget(_scope(log, home: LogEditScreen(entry: e)));
      await tester.pumpAndSettle();
      expect(find.text('表紙'), findsOneWidget);
      final photo = find.byKey(const Key('edit-photo-2'));
      await tester.scrollUntilVisible(photo, 200, scrollable: find.ancestor(of: photo, matching: find.byType(Scrollable)).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-photo-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-photo-remove-1')));
      await tester.pump();
      expect(find.byKey(const Key('edit-photo-2')), findsNothing);
      await tester.tap(find.byKey(const Key('log-save')));
      await tester.pumpAndSettle();
      expect(log.entries.single.photos, ['p2.jpg', 'p1.jpg']);
    });

    testWidgets('10 枚あれば、足すボタンは出さない', (tester) async {
      _phone(tester, const Size(393, 852));
      final e = _e('a', DateTime(2026, 11, 3), photos: [for (var i = 0; i < 10; i++) 'p$i.jpg']);
      await tester.pumpWidget(_scope(TheaterLog(), home: LogEditScreen(entry: e)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-photo-9')), findsOneWidget);
      expect(find.byKey(const Key('edit-photo-add')), findsNothing);
      expect(find.text('写真 10 / 10 枚　押すと表紙にできます'), findsOneWidget);
    });

    testWidgets('削除するときは、写真も消えて戻せないと伝え、やめれば何も消さない', (tester) async {
      _phone(tester, const Size(393, 852));
      final log = TheaterLog();
      final e = _e('a', DateTime(2026, 11, 3), photos: const ['p0.jpg', 'p1.jpg']);
      await log.upsert(e);
      await tester.pumpWidget(_scope(log, home: LogEditScreen(entry: e)));
      await tester.pumpAndSettle();
      final del = find.text('この記録を削除');
      await tester.scrollUntilVisible(del, 200, scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      await tester.tap(del);
      await tester.pumpAndSettle();
      expect(find.text('写真 2 枚も一緒に消え、元に戻せません。'), findsOneWidget);
      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();
      expect(log.entries.single.photos, ['p0.jpg', 'p1.jpg']);
    });
  });
}
