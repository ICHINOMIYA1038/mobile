// tomoshibi本体とログイン(Google/Apple OAuth)・決済管理(Stripe portal)に必要な
// ホストのみアプリ内WebViewで開き、それ以外(GitHubリンク等)は端末のブラウザに逃がす。
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

// Googleは埋め込みWebView内でのOAuthをセキュリティ上ブロックすることがあり、
// (accounts.google.comをisInAppHostに含めていても)端末の外部Safariに逃げてしまう
// ことがある(App Store審査 Guideline 4 で指摘)。サインイン導線だけはWebViewで
// 直接開かず、ASWebAuthenticationSession(flutter_web_auth_2)経由でアプリ内シート
// として開く。
const _authSignInHost = 'gikyokutosyokan.com';
const _authSignInPathPrefix = '/auth/signin';

bool isAuthSignInRequest(Uri uri) =>
    uri.host == _authSignInHost && uri.path.startsWith(_authSignInPathPrefix);

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
