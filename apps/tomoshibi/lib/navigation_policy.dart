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
