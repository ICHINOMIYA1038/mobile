import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// このアプリの約束を、実装が破れないように固定するテスト。
///
/// 広告(AdBannerSlot)は結果画面(ResultScreen)にだけ許可する。
/// カテゴリ選択画面(HomeScreen)・名前入力画面(InputScreen)には出さない。
/// 既存の同ジャンルアプリで「ほぼ一問やるごとに広告」「診断結果を見る前に
/// 毎回広告」といった低評価が集中していたため、コア体験を広告で遮らない
/// という方針をこのテストで固定する。
///
/// ウィジェットを描画して確かめる方法もあるが、テスト環境では AdMob SDK が動かず
/// 「広告が出ない」ことが常に真になってしまい、テストとして意味をなさない。
/// そのため、`AdBannerSlot` を呼び出しているのがどのファイルかをソースコードで
/// 検査している。
void main() {
  test('AdBannerSlotを呼び出しているのは結果画面だけ', () {
    final screenFiles = Directory('lib/ui/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    final filesUsingAd = <String>{};
    for (final file in screenFiles) {
      final source = file.readAsStringSync();
      if (source.contains('AdBannerSlot(')) {
        filesUsingAd.add(file.uri.pathSegments.last);
      }
    }

    expect(filesUsingAd, isNotEmpty, reason: 'AdBannerSlotが使われていません');
    expect(filesUsingAd, {'result_screen.dart'});
  });

  test('ホーム画面・入力画面が広告ウィジェット・広告SDKを参照していない', () {
    for (final name in ['home_screen.dart', 'input_screen.dart']) {
      final source = File('lib/ui/screens/$name').readAsStringSync();
      expect(source.contains('AdBannerSlot'), isFalse, reason: name);
      expect(source.contains('google_mobile_ads'), isFalse, reason: name);
    }
  });

  test('インタースティシャル・リワード等の割り込み広告を使っていない', () {
    // 全画面広告は診断体験の流れを断ち切るため、種類を問わず入れない。
    final banned = [
      'InterstitialAd',
      'RewardedAd',
      'RewardedInterstitialAd',
      'AppOpenAd',
    ];
    final files = Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>().where(
      (f) => f.path.endsWith('.dart'),
    );

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final type in banned) {
        expect(
          source.contains(type),
          isFalse,
          reason: '${file.path} が $type を使っています。割り込み広告は入れない方針です',
        );
      }
    }
  });

  test('AdMobのテストIDが本番IDの定数に紛れ込んでいない', () {
    final source = File('lib/data/ad_service.dart').readAsStringSync();
    final prodLines = source
        .split('\n')
        .where((l) => l.contains('_prodBanner'))
        .where((l) => l.contains('ca-app-pub-3940256099942544'));
    expect(prodLines, isEmpty, reason: '本番IDの定数にテストIDが入っています');
  });
}
