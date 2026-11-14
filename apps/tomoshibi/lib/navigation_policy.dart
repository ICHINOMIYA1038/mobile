// tomoshibi本体とログイン(Google/Apple OAuth)・決済管理(Stripe portal)に必要な
// ホストのみアプリ内WebViewで開き、それ以外(戯曲パレット・GitHubリンク等)はアプリ内ブラウザのシートで開く。
//
// checkout.stripe.com (新規Pro購入) は意図的に含めない。
// App Store審査 3.1.1 によりアプリ内で消費するデジタル機能の新規購入は
// ストア課金(IAP)必須のため、この遷移だけは main.dart が横取りしてネイティブ
// 購入フローに置き換える。billing.stripe.com (既存Web購読者の解約・支払い方法変更)
// は「新規購入」ではないためアプリ内WebViewのままでよい。
const inAppHosts = {
  'tomoshibi.gikyokutosyokan.com',
  'gikyokutosyokan.com',
  'accounts.google.com',
  'appleid.apple.com',
  'billing.stripe.com',
};

const stripeCheckoutHost = 'checkout.stripe.com';

bool isInAppHost(String host) => inAppHosts.contains(host);

// Universal Link (apple-app-site-association) で受け取ったURLのうち、
// アプリ内WebViewで開く対象。tomoshibi本体のホストのみ。
bool isUniversalLinkHost(String host) =>
    host == 'tomoshibi.gikyokutosyokan.com';

// アプリ内で開かないURLをOS(Safari・メール等)に渡してよいか。
// about:blank / blob: / data: / javascript: 等はOSでは開けず、launchUrl が
// 例外を投げるので渡さない。
const _externalSchemes = {'http', 'https', 'mailto', 'tel', 'sms'};

bool canOpenExternally(Uri uri) => _externalSchemes.contains(uri.scheme);

// アプリ内で開かない http(s) のページ（戯曲パレット・戯曲 ID・GitHub 等）は、端末のブラウザではなく
// アプリ内のブラウザ（SFSafariViewController）で開く。端末のブラウザに渡すと、そこから先のリダイレクトや
// ログインを経てもアプリには戻らず、利用者が取り残される（2026-11-14 オーナー報告。
// 戯曲パレットへのリンクが Chrome で開き、アプリに戻れなかった）。
// アプリ内のブラウザなら「完了」でアプリに戻れる。メール・電話・SMS は OS のアプリでしか開けない。
bool opensInAppBrowser(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

// App Store の「サブスクリプション」など、App Store アプリで開くべきページ。アプリ内ブラウザで開くと
// Web の案内ページになり、契約の管理・解約ができない。
bool opensInOtherApp(Uri uri) => uri.host == 'apps.apple.com';

// Googleは埋め込みWebView内でのOAuthをセキュリティ上ブロックすることがあり、
// (accounts.google.comをisInAppHostに含めていても)端末の外部Safariに逃げてしまう
// ことがある(App Store審査 Guideline 4 で指摘)。サインイン導線だけはWebViewで
// 直接開かず、ASWebAuthenticationSession(flutter_web_auth_2)経由でアプリ内シート
// として開く。
const _authSignInHost = 'gikyokutosyokan.com';
const _authSignInPathPrefix = '/auth/signin';

bool isAuthSignInRequest(Uri uri) =>
    uri.host == _authSignInHost && uri.path.startsWith(_authSignInPathPrefix);

// 購入フロー側 (main.dart の _startNativePurchase) が未ログイン検出時に
// サインインへ誘導するために使う。isAuthSignInRequest と対になっている。
Uri buildAuthSignInUri() => Uri.https(_authSignInHost, _authSignInPathPrefix);

// ログアウトも同じ理由でASWebAuthenticationSessionの共有Cookieストア側を
// 明示的にクリアしないと、次回ログイン時に「既にログイン済み」判定のまま
// 別アカウントを選べず元のアカウントに自動ログインされてしまう。
const _logoutPathPrefix = '/api/tomoshibi/logout';

bool isLogoutRequest(Uri uri) =>
    uri.host == _authSignInHost && uri.path.startsWith(_logoutPathPrefix);

// ASWebAuthenticationSessionの終着点として使うカスタムURLスキーム。
// gikyoku_tosyokan側のNextAuth redirectアローリストにも同じ値を許可登録している。
const authCallbackUrlScheme = 'tomoshibi';
const authCallbackUrl = 'tomoshibi://auth-callback';

// Guideline 5.1.1(v)対応: サイト側 (tomoshibi SPA) は本来Web購読者向けに
// ログイン必須のStripe Checkoutへ誘導するが、アプリ内では未ログインでも
// ネイティブIAPで購入できる必要がある。サイト側は window.webkit.messageHandlers.
// TomoshibiSession の有無でアプリ内実行を検知し、未ログイン時はこのカスタム
// スキームへのリンクを出す。ここへの遷移はネットワークに出る前に横取りする。
bool isNativePurchaseRequest(Uri uri) =>
    uri.scheme == authCallbackUrlScheme && uri.host == 'native-purchase';

// アカウントの管理・ログアウト・退会は、戯曲 ID のアカウント画面・退会画面で行う
// （戯曲図書館のマイページや古い退会 API は使わない。2026-11-14 オーナー決定）。
// どちらもログインが要り、Apple の連携の取り消しにはログインしたときの Cookie が要るので、
// ログインと同じシート（ASWebAuthenticationSession）で開く。閉じるとき戯曲 ID が
// tomoshibi://account?result=closed|logged_out|deleted|kept に戻す。
const _portalHost = 'id.gikyokutosyokan.com';
const accountReturnUrl = 'tomoshibi://account';

bool isAccountPageRequest(Uri uri) =>
    uri.host == _portalHost && (uri.path == '/account' || uri.path == '/delete');

/// シートで開く URL。戻り先は必ずアプリにする
Uri buildAccountPageUri(Uri requested) => Uri.https(_portalHost, requested.path, {
  'return_to': accountReturnUrl,
});

/// シートから戻ってきた URL が、アプリの画面もログアウトすべき結果（ログアウト・退会）か
bool needsLogoutAfterAccountPage(Uri uri) =>
    uri.scheme == authCallbackUrlScheme &&
    uri.host == 'account' &&
    (uri.queryParameters['result'] == 'logged_out' ||
        uri.queryParameters['result'] == 'deleted');
