@Tags(['release'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ストア提出前に必ず直さないといけない箇所を洗い出す。
///
/// このファイルのテストは、未対応の項目が残っている限り **skip ではなく明確に落ちる**。
/// 「テストは全部通ったのに審査に出したらテスト広告のままだった」を防ぐのが目的。
///
/// 提出直前にこれを実行し、落ちた項目を潰してから archive すること。
///   flutter test --run-skipped --tags release
///
/// 日常の `flutter test` では dart_test.yaml の設定により除外される。
void main() {
  String read(String path) => File(path).readAsStringSync();

  // まだ差し替えていない項目はここに列挙される。
  // 対応が済んだら、そのテストは自然と通るようになる。
  group('提出前チェック', () {
    test('AdMob のバナーIDが本番のものになっている', () {
      final source = read('lib/data/ad_service.dart');
      final prodIos = RegExp(r"_prodBannerIos = '([^']*)'").firstMatch(source)?.group(1);
      final prodAndroid =
          RegExp(r"_prodBannerAndroid = '([^']*)'").firstMatch(source)?.group(1);

      expect(prodIos, isNotEmpty,
          reason: 'lib/data/ad_service.dart の _prodBannerIos が空です。'
              'AdMob で発行した実際のバナーIDを入れてください（テストIDのままだと収益が出ません）');
      expect(prodAndroid, isNotEmpty,
          reason: 'lib/data/ad_service.dart の _prodBannerAndroid が空です');
    });

    test('AdMob のアプリIDが本番のものになっている', () {
      const testAppId = 'ca-app-pub-3940256099942544';

      final plist = read('ios/Runner/Info.plist');
      expect(plist.contains(testAppId), isFalse,
          reason: 'ios/Runner/Info.plist の GADApplicationIdentifier がテストIDのままです');

      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains(testAppId), isFalse,
          reason: 'android/.../AndroidManifest.xml の APPLICATION_ID がテストIDのままです');
    });

    test('プライバシーポリシーと問い合わせ先のURLが実在のものになっている', () {
      final source = read('lib/ui/screens/stats_screen.dart');
      // 仮で置いた pairof.jp のパスのままなら、実際に公開したURLに差し替える必要がある。
      final policy = RegExp(r"privacyPolicyUrl = '([^']*)'").firstMatch(source)?.group(1);
      final support = RegExp(r"supportUrl = '([^']*)'").firstMatch(source)?.group(1);

      expect(policy, isNot('https://pairof.jp/takken/privacy'),
          reason: 'privacyPolicyUrl が仮のURLのままです。'
              'docs/privacy-policy.md を公開し、そのURLに差し替えてください');
      expect(support, isNot('https://pairof.jp/takken/support'),
          reason: 'supportUrl が仮のURLのままです');
    });

    test('プライバシーポリシーに連絡先が書かれている', () {
      final policy = read('docs/privacy-policy.md');
      expect(policy.contains('（メールアドレスをここに記載してください）'), isFalse,
          reason: 'docs/privacy-policy.md の連絡先が未記入です。審査で指摘されます');
    });
  });

  // ここから下は既に対応済み。壊れたら気付けるように残す。
  group('対応済みの項目（退行防止）', () {
    test('Bundle ID が全プラットフォームで揃っている', () {
      const id = 'jp.pairof.takken';

      final ios = read('ios/Runner.xcodeproj/project.pbxproj');
      expect(ios.contains('PRODUCT_BUNDLE_IDENTIFIER = $id;'), isTrue);
      expect(ios.contains('jp.takken.simple'), isFalse, reason: '旧IDが残っています');

      final android = read('android/app/build.gradle.kts');
      expect(android.contains('applicationId = "$id"'), isTrue);
      expect(android.contains('namespace = "$id"'), isTrue);
    });

    test('iOS のプライバシーマニフェストが存在し、Xcode に登録されている', () {
      expect(File('ios/Runner/PrivacyInfo.xcprivacy').existsSync(), isTrue);
      final project = read('ios/Runner.xcodeproj/project.pbxproj');
      expect(project.contains('PrivacyInfo.xcprivacy'), isTrue,
          reason: 'Xcode に登録されていないとアプリにバンドルされません');
    });

    test('AdMob のアプリIDが両プラットフォームに設定されている', () {
      // 値の有無に関わらず、キー自体が無いと起動時にクラッシュする。
      expect(read('ios/Runner/Info.plist').contains('GADApplicationIdentifier'), isTrue);
      expect(
        read('android/app/src/main/AndroidManifest.xml')
            .contains('com.google.android.gms.ads.APPLICATION_ID'),
        isTrue,
      );
    });

    test('Android のリリースビルドが debug 署名にフォールバックしない設定になっている', () {
      final gradle = read('android/app/build.gradle.kts');
      expect(gradle.contains('key.properties'), isTrue,
          reason: 'リリース署名の仕組みがありません');
      expect(gradle.contains('isMinifyEnabled = true'), isTrue);
    });

    test('署名鍵が誤ってリポジトリに入っていない', () {
      final ignore = read('android/.gitignore');
      expect(ignore.contains('key.properties'), isTrue);
      expect(ignore.contains('**/*.jks'), isTrue);
      expect(File('android/key.properties').existsSync(), isFalse,
          reason: 'key.properties が存在します。.gitignore 済みですがコミットしないよう注意');
    });

    test('輸出コンプライアンスの申告が入っている', () {
      // これが無いと提出のたびに暗号化の質問に答えることになる。
      expect(read('ios/Runner/Info.plist').contains('ITSAppUsesNonExemptEncryption'), isTrue);
    });

    test('アプリ表示名が日本語になっている', () {
      expect(read('ios/Runner/Info.plist').contains('シンプルに学ぶ宅建'), isTrue);
      expect(
        read('android/app/src/main/AndroidManifest.xml').contains('シンプルに学ぶ宅建'),
        isTrue,
      );
    });
  });
}
