import 'package:flutter_test/flutter_test.dart';
import 'package:tomoshibi/navigation_policy.dart';

void main() {
  test('tomoshibi本体・ログイン・解約管理ホストはアプリ内で開く', () {
    expect(isInAppHost('tomoshibi.gikyokutosyokan.com'), isTrue);
    expect(isInAppHost('gikyokutosyokan.com'), isTrue);
    expect(isInAppHost('accounts.google.com'), isTrue);
    expect(isInAppHost('appleid.apple.com'), isTrue);
    expect(isInAppHost('billing.stripe.com'), isTrue);
  });

  test('新規Pro購入 (checkout.stripe.com) はアプリ内WebViewの対象外 (ネイティブIAPに置き換える)', () {
    expect(isInAppHost('checkout.stripe.com'), isFalse);
  });

  test('関係ないホストは端末のブラウザに逃がす', () {
    expect(isInAppHost('github.com'), isFalse);
    expect(isInAppHost('evil.example.com'), isFalse);
  });

  test('tomoshibi://native-purchase は未ログイン購入トリガーとして認識する', () {
    expect(isNativePurchaseRequest(Uri.parse('tomoshibi://native-purchase')), isTrue);
    expect(isNativePurchaseRequest(Uri.parse('tomoshibi://auth-callback')), isFalse);
    expect(isNativePurchaseRequest(Uri.parse('https://native-purchase')), isFalse);
  });

  test('Universal Linkはtomoshibi本体のホストだけをアプリ内で開く', () {
    expect(isUniversalLinkHost('tomoshibi.gikyokutosyokan.com'), isTrue);
    expect(isUniversalLinkHost('gikyokutosyokan.com'), isFalse);
    expect(isUniversalLinkHost('evil-tomoshibi.gikyokutosyokan.com'), isFalse);
  });

  test('OSに渡せるのはhttp(s)・mailto・tel・smsだけ', () {
    expect(canOpenExternally(Uri.parse('https://github.com/x')), isTrue);
    expect(canOpenExternally(Uri.parse('mailto:support@gikyokutosyokan.com')), isTrue);
    expect(canOpenExternally(Uri.parse('about:blank')), isFalse);
    expect(canOpenExternally(Uri.parse('blob:https://tomoshibi.gikyokutosyokan.com/abc')), isFalse);
    expect(canOpenExternally(Uri.parse('javascript:void(0)')), isFalse);
  });
}
