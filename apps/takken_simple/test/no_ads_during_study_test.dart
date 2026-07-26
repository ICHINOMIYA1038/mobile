import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// このアプリの約束を、実装が破れないように固定するテスト。
///
/// 競合の最大の不満は「広告が邪魔で集中できない」であり、広告を結果画面だけに閉じ込めることが
/// 本アプリの差別化の根幹。将来うっかり出題画面にバナーを足したらここで落ちる。
///
/// ウィジェットを描画して確かめる方法もあるが、テスト環境では AdMob SDK が動かず
/// 「広告が出ない」ことが常に真になってしまい、テストとして意味をなさない。
/// そのため、広告ウィジェットを参照している画面はどれかをソースコードで検査している。
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('広告は結果画面にしか置かない', () {
    test('出題・解説画面が広告ウィジェットを参照していない', () {
      final quiz = read('lib/ui/screens/quiz_screen.dart');
      expect(quiz.contains('ResultBannerAd'), isFalse,
          reason: '出題・解説画面に広告を置いてはいけません');
      expect(quiz.contains('google_mobile_ads'), isFalse,
          reason: '出題・解説画面から広告SDKを参照してはいけません');
    });

    test('ホーム画面が広告ウィジェットを参照していない', () {
      final home = read('lib/ui/screens/home_screen.dart');
      expect(home.contains('ResultBannerAd'), isFalse);
      expect(home.contains('google_mobile_ads'), isFalse);
    });

    test('成績画面が広告ウィジェットを参照していない', () {
      final stats = read('lib/ui/screens/stats_screen.dart');
      expect(stats.contains('ResultBannerAd'), isFalse);
      expect(stats.contains('google_mobile_ads'), isFalse);
    });

    test('広告を参照してよいのは結果画面だけ', () {
      final dir = Directory('lib/ui/screens');
      final referencing = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('ResultBannerAd'))
          .map((f) => f.uri.pathSegments.last)
          .toList();

      expect(referencing, ['result_screen.dart']);
    });

    test('インタースティシャル・リワード等の割り込み広告を使っていない', () {
      // 全画面広告は学習の流れを断ち切るため、種類を問わず入れない。
      final banned = ['InterstitialAd', 'RewardedAd', 'RewardedInterstitialAd', 'AppOpenAd'];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final source = file.readAsStringSync();
        for (final type in banned) {
          expect(source.contains(type), isFalse,
              reason: '${file.path} が $type を使っています。割り込み広告は入れない方針です');
        }
      }
    });
  });

  group('広告IDの取り違え防止', () {
    test('AdMobのテストIDが本番IDの定数に紛れ込んでいない', () {
      final source = read('lib/data/ad_service.dart');
      // Google公開のテスト用IDプレフィックス。本番IDとして設定されていたら事故。
      final prodLines = source
          .split('\n')
          .where((l) => l.contains('_prodBanner'))
          .where((l) => l.contains('ca-app-pub-3940256099942544'));
      expect(prodLines, isEmpty, reason: '本番IDの定数にテストIDが入っています');
    });
  });
}
