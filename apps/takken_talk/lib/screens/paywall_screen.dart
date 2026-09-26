import 'dart:async';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../purchase_service.dart';
import '../state/app_state.dart';
import '../widgets/readable.dart';

/// Pro(月額)と会話パック(買い切り)の案内。RevenueCat の Offerings から価格を出す。
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.reason});
  final String reason;

  static Future<void> show(BuildContext context, {required String reason}) {
    AppInsights.logEvent('paywall_open', parameters: {'reason': reason});
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaywallScreen(reason: reason),
        fullscreenDialog: true,
        settings: const RouteSettings(name: 'paywall'),
      ),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final me = AppScope.of(context).me!;
    try {
      // App Store に繋がらないと RevenueCat の初期化が返ってこないことがある。
      // 待ち続けるとスピナーのまま固まるので、打ち切ってプランの内容だけ見せる。
      _offerings = await PurchaseService.offerings(me.userId).timeout(const Duration(seconds: 12));
      if (_offerings != null) _error = null;
    } on TimeoutException {
      _error = '価格の取得に時間がかかっています。通信環境を確認して、もう一度お試しください。';
    } catch (e) {
      _error = 'プラン情報を取得できませんでした。少し待ってからもう一度お試しください。';
    }
    if (mounted) setState(() => _loading = false);
  }

  Package? _find(String productId) {
    final all = _offerings?.all.values.expand((o) => o.availablePackages) ?? const <Package>[];
    for (final p in all) {
      if (p.storeProduct.identifier == productId) return p;
    }
    return null;
  }

  Future<void> _buy(Package pkg) async {
    final state = AppScope.of(context);
    setState(() => _busy = true);
    try {
      await PurchaseService.purchase(state.me!.userId, pkg);
      AppInsights.logEvent('purchase', parameters: {'product': pkg.storeProduct.identifier});
      // Webhook が届くまで数秒かかることがあるので、少し待ってから状態を取り直す
      await Future<void>.delayed(const Duration(seconds: 2));
      await state.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ありがとうございます。続きを話しましょう。')));
      Navigator.of(context).pop();
    } on PurchaseCancelledException {
      // 何もしない
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('購入できませんでした: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final state = AppScope.of(context);
    setState(() => _busy = true);
    try {
      await PurchaseService.restore(state.me!.userId);
      await Future<void>.delayed(const Duration(seconds: 2));
      await state.refresh();
      if (!mounted) return;
      final pro = state.me!.plan.isPro;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pro ? 'Proを復元しました' : '復元できる購入が見つかりませんでした')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('復元できませんでした: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = AppScope.of(context).me!;
    final pro = _find(AppConfig.proProductId);
    final pack100 = _find(AppConfig.pack100ProductId);
    final pack300 = _find(AppConfig.pack300ProductId);
    final headline = switch (widget.reason) {
      'free_cap' => '第1章の無料枠を使い切りました',
      'locked' => 'この章はProまたは会話パックで',
      'pack_empty' => '会話パックを使い切りました',
      'pro_cap' => '今月のPro上限に達しました',
      _ => '全11章を、最後まで話して受かる',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('プラン'), backgroundColor: theme.scaffoldBackgroundColor),
      body: Readable(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(headline, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const _Line('・宅建業法・権利関係・法令上の制限・税その他、全11章'),
          const _Line('・300問の○×を、忘れる前にAIが再出題'),
          const _Line('・会話の続きと進捗はいつでも引き継がれます'),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (!PurchaseService.isAvailable || _offerings == null) ...[
            // 価格が取れなくても、何が買えるのかは伝える。
            // 通信が細いときやサインインしていないときにここへ来る。
            const _PlanOutline(title: 'Pro（月額）', subtitle: '全章・毎月800回まで会話し放題。いつでも解約できます。'),
            const _PlanOutline(title: '会話パック 100回', subtitle: '買い切り。期限なし。全章で使えます。'),
            const _PlanOutline(title: '会話パック 300回', subtitle: '買い切り。期限なし。まとめてお得。'),
            const SizedBox(height: 4),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error ?? '価格を読み込めませんでした。通信環境を確認して、もう一度お試しください。'),
                    if (PurchaseService.isAvailable) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() => _loading = true);
                                _load();
                              },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('もう一度読み込む'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            if (pro != null)
              _PlanCard(
                title: 'Pro（月額）',
                price: pro.storeProduct.priceString,
                subtitle: '全章・毎月${_proCapText()}回まで会話し放題。いつでも解約できます。',
                primary: true,
                busy: _busy,
                onTap: () => _buy(pro),
              ),
            if (pack100 != null)
              _PlanCard(
                title: '会話パック 100回',
                price: pack100.storeProduct.priceString,
                subtitle: '買い切り。期限なし。全章で使えます。',
                busy: _busy,
                onTap: () => _buy(pack100),
              ),
            if (pack300 != null)
              _PlanCard(
                title: '会話パック 300回',
                price: pack300.storeProduct.priceString,
                subtitle: '買い切り。期限なし。まとめてお得。',
                busy: _busy,
                onTap: () => _buy(pack300),
              ),
            if (pro == null && pack100 == null && pack300 == null)
              const Card(color: Colors.white, child: Padding(padding: EdgeInsets.all(16), child: Text('購入は現在準備中です。'))),
          ],
          const SizedBox(height: 16),
          Text(
            '「1回」= あなたの1発言（○×ボタンの回答も1回）に対するAIの返答です。'
            '${me.plan.isPro ? '' : '第1章の無料枠は残り${me.plan.freeLeft}回。'}'
            'Proは月額の自動更新サブスクリプションで、期間終了の24時間前までに解約しない限り自動で更新されます。'
            '管理と解約はApp StoreのアカウントSettingsから行えます。',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton(onPressed: _busy ? null : _restore, child: const Text('購入を復元')),
              TextButton(onPressed: () => launchUrl(Uri.parse(AppConfig.termsUrl), mode: LaunchMode.externalApplication), child: const Text('利用規約')),
              TextButton(onPressed: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl), mode: LaunchMode.externalApplication), child: const Text('プライバシー')),
            ],
          ),
        ],
        ),
      ),
    );
  }

  String _proCapText() => '800';
}

/// 価格が取れないときに出す、プランの見出しだけのカード。
class _PlanOutline extends StatelessWidget {
  const _PlanOutline({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(text));
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.busy,
    required this.onTap,
    this.primary = false,
  });
  final String title;
  final String price;
  final String subtitle;
  final bool busy;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: primary ? theme.colorScheme.primaryContainer : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(price, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
