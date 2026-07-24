import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// このアプリの約束を、実装が破れないように固定するテスト。
///
/// 役を引く画面（RoleDrawScreen）は他人に見せてはいけない内容が映るため、広告を出さない。
/// 広告は実演画面（PerformanceScreen）と振り返り画面（ReflectionScreen）にだけ許可する。
///
/// ウィジェットを描画して確かめる方法もあるが、テスト環境では AdMob SDK が動かず
/// 「広告が出ない」ことが常に真になってしまい、テストとして意味をなさない。
/// そのため、`AdBannerSlot` を呼び出しているのがどのクラスかをソースコードで検査している。
void main() {
  test('AdBannerSlotを呼び出しているのは実演画面・振り返り画面だけ', () {
    final source = File('lib/main.dart').readAsStringSync();
    final classStarts = RegExp(
      r'^class (\w+)',
      multiLine: true,
    ).allMatches(source).toList();

    String ownerClassAt(int index) {
      var owner = 'top-level';
      for (final m in classStarts) {
        if (m.start > index) break;
        owner = m.group(1)!;
      }
      return owner;
    }

    final usageIndexes = RegExp(
      r'AdBannerSlot\(',
    ).allMatches(source).map((m) => m.start).toList();
    expect(usageIndexes, isNotEmpty, reason: 'AdBannerSlotが使われていません');

    final callers = usageIndexes.map(ownerClassAt).toSet();
    expect(callers, {'_PerformanceScreenState', 'ReflectionScreen'});
  });

  test('役引き画面が広告ウィジェット・広告SDKを参照していない', () {
    final source = File('lib/main.dart').readAsStringSync();
    final classStarts = RegExp(
      r'^class (\w+)',
      multiLine: true,
    ).allMatches(source).toList();
    final roleDrawStart = classStarts
        .firstWhere((m) => m.group(1) == 'RoleDrawScreen')
        .start;
    final nextClassStart = classStarts
        .map((m) => m.start)
        .firstWhere((s) => s > roleDrawStart, orElse: () => source.length);
    final roleDrawSection = source.substring(roleDrawStart, nextClassStart);

    expect(roleDrawSection.contains('AdBannerSlot'), isFalse);
    expect(roleDrawSection.contains('google_mobile_ads'), isFalse);
  });

  test('インタースティシャル・リワード等の割り込み広告を使っていない', () {
    // 全画面広告は稽古の流れを断ち切るため、種類を問わず入れない。
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
