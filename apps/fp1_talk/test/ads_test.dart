import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fp1_talk/ads/ad_service.dart';

/// 広告の約束を、実装が破れないように固定するテスト（takken_simple の no_ads_during_study_test と同じ考え方）。
///   - 会話・AIに聞く・Pro の画面・設定・模擬試験には広告を置かない（学ぶ流れを広告で切らない）
///   - バナーを置くのは一覧の画面（学ぶ・過去問・図解・復習）と、過去問を解く画面だけ
///   - 全画面広告は過去問の「次の問題」だけ。リワード・起動時の広告は使わない
/// テストの環境では AdMob の SDK が動かず「広告が出ない」が常に真になるので、どの画面が広告を参照しているかをソースで調べる。
void main() {
  String read(String path) => File(path).readAsStringSync();
  List<File> dartFiles(String dir) => Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  bool refersAds(String src) => src.contains('AdBanner') || src.contains('AdService') || src.contains('google_mobile_ads') || src.contains('ads/ad_');

  group('広告を置かない画面', () {
    final noAds = [
      'lib/screens/learn_screen.dart',
      'lib/screens/kakomon/explain_sheet.dart',
      'lib/screens/pro_screen.dart',
      'lib/screens/settings_screen.dart',
      // 本試験形式を解く画面（計算に集中するので広告を出さない）
      'lib/screens/items/item_set_screen.dart',
      ...dartFiles('lib/screens/learn').map((f) => f.path),
      ...dartFiles('lib/screens/pro').map((f) => f.path),
    ];
    for (final path in noAds) {
      test(path, () => expect(refersAds(read(path)), isFalse, reason: '$path に広告を置いてはいけません'));
    }
  });

  test('バナーを置いてよいのは一覧の画面と過去問を解く画面だけ', () {
    final referencing = dartFiles('lib/screens').where((f) => f.readAsStringSync().contains('AdBanner(')).map((f) => f.path.replaceFirst('lib/screens/', '')).toList()..sort();
    expect(referencing, ['figure_library_screen.dart', 'home_screen.dart', 'items_screen.dart', 'kakomon/set_screen.dart', 'review_screen.dart']);
  });

  test('全画面広告を出すのは過去問を解く画面だけ', () {
    final referencing = dartFiles('lib/screens').where((f) => f.readAsStringSync().contains('maybeShowInterstitial')).map((f) => f.path.replaceFirst('lib/screens/', '')).toList();
    expect(referencing, ['kakomon/set_screen.dart']);
    final sdk = dartFiles('lib').where((f) => f.readAsStringSync().contains('InterstitialAd.load')).map((f) => f.path).toList();
    expect(sdk, ['lib/ads/ad_service.dart']);
  });

  test('リワード・起動時の広告を使っていない', () {
    for (final file in dartFiles('lib')) {
      final src = file.readAsStringSync();
      for (final type in ['RewardedAd', 'RewardedInterstitialAd', 'AppOpenAd']) {
        expect(src.contains(type), isFalse, reason: '${file.path} が $type を使っています');
      }
    }
  });

  test('広告は非パーソナライズだけ', () {
    final src = read('lib/ads/ad_service.dart');
    expect(src.contains('AdRequest(nonPersonalizedAds: true)'), isTrue);
    expect(RegExp(r'AdRequest\((?!nonPersonalizedAds: true)').hasMatch(src), isFalse);
  });

  group('全画面広告の間隔（InterstitialPolicy）', () {
    late DateTime now;
    late InterstitialPolicy p;
    final start = DateTime(2026, 10, 21, 9);
    setUp(() {
      now = start;
      p = InterstitialPolicy(clock: () => now, launchedAt: start);
    });
    void answer(int n) {
      for (var i = 0; i < n; i++) {
        p.onAnswered();
      }
    }

    test('10問に届くまでは出さない', () {
      now = start.add(const Duration(minutes: 10));
      answer(9);
      expect(p.due, isFalse);
      answer(1);
      expect(p.due, isTrue);
    });

    test('起動して3分のあいだは出さない（数えるのは続ける）', () {
      answer(12);
      now = start.add(const Duration(minutes: 2, seconds: 59));
      expect(p.due, isFalse);
      now = start.add(const Duration(minutes: 3));
      expect(p.due, isTrue);
    });

    test('出したら数え直し、前から3分はあける', () {
      now = start.add(const Duration(minutes: 5));
      answer(10);
      expect(p.due, isTrue);
      p.onShown();
      expect(p.answered, 0);
      answer(10);
      now = start.add(const Duration(minutes: 7));
      expect(p.due, isFalse, reason: '前に出してから2分');
      now = start.add(const Duration(minutes: 8));
      expect(p.due, isTrue);
    });

    test('Pro の人には出さない（me が無いあいだも）', () {
      expect(adsAllowedFor(null), isFalse);
      expect(adsAllowedFor({'pro': true}), isFalse);
      expect(adsAllowedFor({'pro': false}), isTrue);
    });
  });
}
