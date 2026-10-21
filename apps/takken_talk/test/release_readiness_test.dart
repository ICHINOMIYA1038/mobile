import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takken_talk/ads/ad_service.dart';

/// 提出前に壊れていてはいけない設定（takken_simple の release_readiness_test と同じ考え方）。
/// 「テストは通ったのに、出したらテスト広告のまま／本番の ID で開発していた」を防ぐ。
void main() {
  String read(String path) => File(path).readAsStringSync();
  const googleTest = 'ca-app-pub-3940256099942544';
  const publisher = 'ca-app-pub-8691137965825158';

  group('AdMob の ID', () {
    test('本番の広告ユニットの ID が入っていて、Google のテスト用ではない', () {
      for (final id in [AdService.bannerUnitIdFor(test: false), AdService.interstitialUnitIdFor(test: false)]) {
        expect(id, isNotEmpty);
        expect(id.startsWith(googleTest), isFalse, reason: '$id は Google のテスト用 ID です');
        expect(id, startsWith('$publisher/'), reason: '$id はこのアカウントの広告ユニットではありません');
      }
      expect(AdService.bannerUnitIdFor(test: false), isNot(AdService.interstitialUnitIdFor(test: false)));
    });

    test('debug ビルド（このテストも）では Google のテスト用 ID を使う', () {
      expect(AdService.isUsingTestAds, isTrue);
      expect(AdService.bannerUnitId, startsWith(googleTest));
      expect(AdService.interstitialUnitId, startsWith(googleTest));
    });

    test('Info.plist のアプリ ID が本番のもの', () {
      final m = RegExp(r'<key>GADApplicationIdentifier</key>\s*<string>([^<]*)</string>').firstMatch(read('ios/Runner/Info.plist'));
      expect(m, isNotNull, reason: 'GADApplicationIdentifier が無いと起動時に落ちます');
      final appId = m!.group(1)!;
      expect(appId.startsWith(googleTest), isFalse, reason: 'アプリ ID が Google のサンプルのままです');
      expect(appId, startsWith('$publisher~'));
    });

    test('Info.plist に SKAdNetworkItems がある（Google の分）', () {
      final plist = read('ios/Runner/Info.plist');
      expect(plist.contains('<key>SKAdNetworkItems</key>'), isTrue);
      expect(plist.contains('cstr6suwn9.skadnetwork'), isTrue, reason: 'Google の SKAdNetwork ID');
    });
  });
}
