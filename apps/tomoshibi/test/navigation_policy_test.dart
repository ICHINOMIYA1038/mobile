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

  test('アプリ外のページはアプリ内ブラウザで開き、メール・電話はOSのアプリで開く', () {
    expect(opensInAppBrowser(Uri.parse('https://palette.gikyokutosyokan.com/')), isTrue);
    expect(opensInAppBrowser(Uri.parse('https://id.gikyokutosyokan.com/refresh')), isTrue);
    expect(opensInAppBrowser(Uri.parse('http://example.com/')), isTrue);
    expect(opensInAppBrowser(Uri.parse('mailto:support@gikyokutosyokan.com')), isFalse);
    expect(opensInAppBrowser(Uri.parse('tel:0000000000')), isFalse);
    expect(opensInAppBrowser(Uri.parse('sms:0000000000')), isFalse);
  });

  test('戯曲 ID のアカウント・退会の画面はシートで開き、戻り値でログアウトが要るかを見分ける', () {
    expect(isAccountPageRequest(Uri.parse('https://id.gikyokutosyokan.com/account?return_to=tomoshibi%3A%2F%2Faccount')), isTrue);
    expect(isAccountPageRequest(Uri.parse('https://id.gikyokutosyokan.com/delete')), isTrue);
    expect(isAccountPageRequest(Uri.parse('https://id.gikyokutosyokan.com/refresh')), isFalse);
    expect(isAccountPageRequest(Uri.parse('https://gikyokutosyokan.com/mypage')), isFalse);
    final opened = buildAccountPageUri(Uri.parse('https://id.gikyokutosyokan.com/account?return_to=https%3A%2F%2Fevil.example.com'));
    expect(opened.path, '/account');
    expect(opened.queryParameters['return_to'], 'tomoshibi://account');
    expect(needsLogoutAfterAccountPage(Uri.parse('tomoshibi://account?result=deleted')), isTrue);
    expect(needsLogoutAfterAccountPage(Uri.parse('tomoshibi://account?result=logged_out')), isTrue);
    expect(needsLogoutAfterAccountPage(Uri.parse('tomoshibi://account?result=closed')), isFalse);
    expect(needsLogoutAfterAccountPage(Uri.parse('tomoshibi://account?result=kept')), isFalse);
    expect(needsLogoutAfterAccountPage(Uri.parse('tomoshibi://auth-callback?result=deleted')), isFalse);
  });

  test('App Store の管理画面は App Store アプリで開く', () {
    expect(opensInOtherApp(Uri.parse('https://apps.apple.com/account/subscriptions')), isTrue);
    expect(opensInOtherApp(Uri.parse('https://palette.gikyokutosyokan.com/')), isFalse);
  });
}
