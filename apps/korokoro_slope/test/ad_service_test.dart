import 'package:flutter_test/flutter_test.dart';
import 'package:korokoro_slope/data/ad_service.dart';

void main() {
  // flutter_test_config.dart で AdService.disableForTests = true が設定済み。

  test('テスト環境では同意なし扱いとなり広告をリクエストできない', () async {
    expect(await AdService.canRequestAds(), isFalse);
  });

  test('テスト環境ではインタースティシャルはプラットフォームチャンネルを叩かずfalseを返す', () async {
    expect(await AdService().showInterstitial(), isFalse);
  });

  test('テスト環境ではリワード広告はプラットフォームチャンネルを叩かずfalseを返す', () async {
    expect(await AdService().showRewarded(), isFalse);
  });
}
