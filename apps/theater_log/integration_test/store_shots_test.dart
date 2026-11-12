// App Store の画像の素材を撮る。iPhone 16 Pro Max（1320×2868）のシミュレーターで流し、
// 「SHOT 名前」が出たところで xcrun simctl io screenshot する（tool/store_compose/shoot.sh）。
// 作品名・劇団名・劇場名・写真はすべて架空（実在の公演と取り違えられないように）。カタログの劇場もこのテストの中だけ架空のものに差し替える。
// 写真は tool/store_compose/photos/ の JPEG を --dart-define=PHOTOS=<そのフォルダの絶対パス> で読む（シミュレーターは Mac のファイルを読める）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theater_log/account/auth_service.dart';
import 'package:theater_log/catalog/achievements.dart';
import 'package:theater_log/catalog/log_photos.dart';
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
    final real = await repository.load();
    // 架空の劇場（都道府県だけは実在。地図に足あとを付けるため）
    const fictional = [
      ('下北沢ほとり座', '東京都'), ('中野こもれび劇場', '東京都'), ('高円寺あかり小劇場', '東京都'), ('池袋まわり舞台', '東京都'),
      ('横浜みなと座', '神奈川県'), ('京都いとへん劇場', '京都府'), ('大阪ともしびホール', '大阪府'), ('名古屋ひだまり座', '愛知県'),
      ('福岡なぎさ劇場', '福岡県'), ('札幌ゆきあかり劇場', '北海道'), ('仙台けやき座', '宮城県'), ('金沢こはく劇場', '石川県'),
      ('広島みずべ劇場', '広島県'), ('松山いでゆ座', '愛媛県'), ('那覇あおぞら劇場', '沖縄県'), ('新潟こめどころ座', '新潟県'),
      ('静岡ちゃばたけ劇場', '静岡県'), ('神戸はとば座', '兵庫県'), ('岡山ももいろ劇場', '岡山県'), ('熊本ひのくに座', '熊本県'),
      ('長野やまなみ劇場', '長野県'), ('盛岡いわて座', '岩手県'), ('高松うどん座', '香川県'), ('鹿児島さくらじま劇場', '鹿児島県'),
    ];
    final catalog = Catalog(
      generatedAt: real.generatedAt,
      categories: real.categories,
      plays: const [],
      venues: [for (final (i, v) in fictional.indexed) Venue(9001 + i, v.$1, v.$2)],
    );
    const photoDir = String.fromEnvironment('PHOTOS');
    Future<List<String>> photos(List<String> names) async => [
      for (final n in names)
        if (photoDir.isNotEmpty) await LogPhotos.save(File('$photoDir/$n.jpg')),
    ];
    final log = TheaterLog();
    final y = DateTime.now().year;
    // （題名, 月, 日, 劇場, 劇団, 評価, 昼夜, ひとこと, 写真）
    const rows = [
      ('夜明けの待合室', 1, 18, '下北沢ほとり座', 'ユニット灯台', 5, 'soiree', '駅の待合室だけで、ひと晩の人生が見えてくる。', ['stage_blue']),
      ('港町クロニクル', 3, 14, '横浜みなと座', '劇団あおぞら座', 4, 'matinee', '', ['flyer_minato']),
      ('さよならの温度', 4, 5, '中野こもれび劇場', '劇団ひとつぶ', 4, 'soiree', '台詞の少ない場面ほど、ずっと覚えている。', ['stage_amber']),
      ('月曜日の鯨', 5, 11, '下北沢ほとり座', 'ユニット灯台', 5, 'matinee', '笑って、最後に少し泣いた。帰り道ずっと考えていた。', ['flyer_kujira', 'stage_green']),
      ('赤い傘の午後', 7, 2, '中野こもれび劇場', '劇団ひとつぶ', 3, 'soiree', '', ['flyer_kasa']),
      ('三番線のベンチ', 7, 26, '京都いとへん劇場', '東風舎', 4, 'matinee', '京都まで遠征。小さな劇場の近さがいい。', ['stage_red']),
      ('ひとりぼっちの合唱', 8, 30, '大阪ともしびホール', '劇団つきよみ', 4, 'soiree', '大阪でもう一度。客席の笑いの起き方が違う。', <String>[]),
      ('星を数える部屋', 9, 14, '名古屋ひだまり座', '東風舎', 4, 'matinee', '', ['flyer_hoshi']),
      ('灯台守の娘', 10, 4, '福岡なぎさ劇場', '劇団つきよみ', 5, 'soiree', '福岡で。最後の明かりがずっと目に残っている。', ['flyer_tomoshibi', 'stage_dawn']),
      ('透明な隣人', 10, 25, '高円寺あかり小劇場', '劇団ひとつぶ', 5, 'soiree', '', ['stage_green']),
      ('雨宿りの研究', 11, 3, '下北沢ほとり座', 'ユニット灯台', 5, 'matinee', '同じ劇団を観るのは 3 回目。毎回ちがう顔がある。', ['stage_amber']),
    ];
    for (final (i, r) in rows.indexed) {
      await log.upsert(TheaterLogEntry(
        id: 'shot$i',
        title: r.$1,
        watchedOn: DateTime(y, r.$2, r.$3),
        venue: r.$4,
        group: r.$5,
        rating: r.$6,
        showTime: r.$7,
        note: r.$8,
        photos: await photos(r.$9),
      ));
    }
    // 撮影中に本物のカタログに入れ替わらないよう、取りに行く先は「変わりなし」を返す
    final offline = CatalogRepository(client: MockClient((_) async => http.Response('', 304)));
    await tester.pumpWidget(App(repository: offline, catalog: catalog, log: log, auth: AuthService()));
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
    await tester.enterText(find.byKey(const Key('quick-title')), '雨宿りの研究');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flow-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venue-open')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('venue-query')), 'ほとり');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venue-hit-9001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flow-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-star-5')));
    await tester.enterText(find.byKey(const Key('quick-note')), '同じ劇団を観るのは 4 回目。毎回ちがう顔がある。');
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
