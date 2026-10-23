import 'dart:async';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../purchase_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/readable.dart';

/// Pro（月額の自動更新サブスクリプション）の案内。価格は RevenueCat の Offerings から出す。
/// Pro でなくても全章・過去問・図解・復習を使える。Pro で変わるのは、広告が出なくなること・1日に AI と話せる回数・
/// Pro だけの学習ツール（苦手分析と学習プラン・模擬試験）。
/// App Review 3.1.1: アプリの外の買い方・値段には触れない。3.1.2: 自動更新・解約の方法・規約を購入の近くに出す。
class ProScreen extends StatefulWidget {
  const ProScreen({super.key, required this.reason});

  /// どこから開いたか（cap = 今日の上限に達した / settings = 設定から / analysis・mock = 学ぶの「Pro の学習ツール」から）
  final String reason;

  static Future<void> show(BuildContext context, {required String reason}) {
    AppInsights.logEvent('paywall_open', parameters: {'reason': reason});
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProScreen(reason: reason), fullscreenDialog: true, settings: const RouteSettings(name: 'pro')),
    );
  }

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  Offerings? _offerings;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String get _userId => AppScope.read(context).api.userId ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      // App Store に繋がらないと RevenueCat の初期化が返ってこないことがある。
      // 待ち続けるとスピナーのまま固まるので、打ち切ってプランの内容だけ見せる。
      _offerings = await PurchaseService.offerings(_userId).timeout(const Duration(seconds: 12));
      if (_offerings != null) _error = null;
    } on TimeoutException {
      _error = '価格の取得に時間がかかっています。通信環境を確認して、もう一度お試しください。';
    } catch (_) {
      _error = 'プラン情報を取得できませんでした。少し待ってからもう一度お試しください。';
    }
    if (mounted) setState(() => _loading = false);
  }

  Package? get _pro {
    final all = _offerings?.all.values.expand((o) => o.availablePackages) ?? const <Package>[];
    for (final p in all) {
      if (p.storeProduct.identifier == AppConfig.proProductId) return p;
    }
    return null;
  }

  /// 購入の通知（Webhook）がサーバーに届くまで数秒かかるので、Pro になるまで少し待って取り直す
  Future<bool> _waitForPro() async {
    final state = AppScope.read(context);
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await state.refresh();
      if (state.me?['pro'] == true) return true;
    }
    return false;
  }

  /// 購入・復元の結果は必ずダイアログで見せる（何も出ないと、買えたのかどうか分からない）
  Future<void> _tell(String title, String body) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: Text(body, style: const TextStyle(height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  /// 買えなかった理由を、利用者に分かる言葉で（コードは問い合わせのときのために添える）
  String _why(Object e) {
    if (e is PlatformException) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      final reason = switch (code) {
        PurchasesErrorCode.networkError => '通信できませんでした。電波のよい所でもう一度お試しください。',
        PurchasesErrorCode.paymentPendingError => '支払いの承認を待っています。承認されると Pro になります。',
        PurchasesErrorCode.purchaseNotAllowedError => 'この端末では購入が許可されていません（スクリーンタイムの設定などを確かめてください）。',
        PurchasesErrorCode.storeProblemError => 'App Store で問題が起きました。少し待ってからもう一度お試しください。',
        _ => '購入を完了できませんでした。少し待ってからもう一度お試しください。',
      };
      return '$reason\n（エラー: ${code.name}）';
    }
    return '購入を完了できませんでした。少し待ってからもう一度お試しください。';
  }

  Future<void> _buy(Package pkg) async {
    setState(() => _busy = true);
    try {
      await PurchaseService.purchase(_userId, pkg);
      AppInsights.logEvent('purchase', parameters: {'product': pkg.storeProduct.identifier});
      final ok = await _waitForPro();
      if (!mounted) return;
      if (ok) {
        await _tell('Pro になりました', 'ありがとうございます。広告が出なくなり、1日に AI と話せる回数が増えました。苦手分析と模擬試験も使えます。');
        if (mounted) Navigator.of(context).pop();
      } else {
        AppInsights.logEvent('purchase_pending');
        await _tell('購入を受け付けました', 'Pro への切り替えをまだ確認できていません。数分たってから、この画面の下の「購入を復元」を押してください。');
      }
    } on PurchaseCancelledException {
      // 自分でやめたので何も出さない
    } catch (e, st) {
      AppInsights.recordError(e, st, reason: 'purchase');
      if (mounted) await _tell('購入できませんでした', _why(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await PurchaseService.restore(_userId);
      final ok = await _waitForPro();
      if (!mounted) return;
      await _tell(ok ? 'Pro を復元しました' : '復元できる購入が見つかりませんでした', ok ? '広告が出なくなり、1日に AI と話せる回数が増えました。苦手分析と模擬試験も使えます。' : 'この Apple ID で購入した Pro が見つかりませんでした。購入した Apple ID でサインインしているか確かめてください。');
    } catch (e, st) {
      AppInsights.recordError(e, st, reason: 'restore');
      if (mounted) await _tell('復元できませんでした', _why(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isPro = state.me?['pro'] == true;
    // 回数はサーバーの設定（/api/v1/me の freeCap / proCap）をそのまま出す
    final freeCap = (state.me?['freeCap'] as num?)?.toInt() ?? 40;
    final proCap = (state.me?['proCap'] as num?)?.toInt() ?? 100;
    final pro = _pro;
    return Scaffold(
      appBar: AppBar(title: const Text('Pro')),
      body: Readable(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              switch (widget.reason) {
                'cap' => '今日の AI の回数を使い切りました',
                'analysis' => '苦手分析と学習プランは Pro の機能です',
                'mock' => '模擬試験は Pro の機能です',
                _ => '広告なしで、AI の先生ともっと話す',
              },
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.ink),
            ),
            const SizedBox(height: 12),
            const _Line('広告が出なくなります。'),
            _Line('1日に AI と話せる回数が $freeCap回 から $proCap回 に増えます（会話・過去問の「AIに聞く」のどちらにも使えます）。'),
            const _Line('苦手分析と AI の学習プラン（答えた記録から苦手な論点を出し、AI が今週やることを決めます）。'),
            const _Line('模擬試験（本番の比率で50問・30分。AI の講評つき）。'),
            const _Line('教材・過去問・図解・復習は、Pro でなくてもすべて使えます。'),
            const SizedBox(height: 20),
            if (isPro)
              const _Box(child: Text('いまは Pro です。ありがとうございます。', style: TextStyle(fontWeight: FontWeight.w700, color: Palette.success)))
            else if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (pro != null)
              _Box(
                highlight: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pro（月額）', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('広告なし・1日$proCap回まで。いつでも解約できます。', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _busy ? null : () => _buy(pro),
                      // 確認のあいだ（最大 16 秒）押したことが分かるように
                      child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(pro.storeProduct.priceString),
                    ),
                  ],
                ),
              )
            else
              _Box(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pro（月額）', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
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
            const SizedBox(height: 16),
            const Text(
              '「1回」は、あなたの1回の発言（○×ボタンでの回答も1回）への AI の返答です。回数は毎日 0時 に戻ります。'
              'Pro は月額の自動更新サブスクリプションで、期間が終わる24時間前までに解約しない限り自動で更新されます。'
              'お支払いは Apple ID のアカウントに請求されます。管理と解約は「設定」アプリの「サブスクリプション」から行えます。',
              style: TextStyle(fontSize: 13, height: 1.7, color: Palette.inkSoft),
            ),
            const SizedBox(height: 16),
            const _Cancel(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                TextButton(onPressed: _busy ? null : _restore, child: const Text('購入を復元')),
                TextButton(onPressed: () => launchUrl(Uri.parse(AppConfig.termsUrl), mode: LaunchMode.externalApplication), child: const Text('利用規約')),
                TextButton(onPressed: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl), mode: LaunchMode.externalApplication), child: const Text('プライバシーポリシー')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pro の解約のしかた（App Store のサブスクリプションなので、アプリの中では解約できない）
class _Cancel extends StatelessWidget {
  const _Cancel();

  static const _steps = [
    'iPhone の「設定」アプリを開く',
    'いちばん上の自分の名前（Apple アカウント）を押す',
    '「サブスクリプション」を押す',
    '「AIとチャットしながら学ぶ宅建 - pAIrOf」を選び、「サブスクリプションをキャンセル」を押す',
  ];

  @override
  Widget build(BuildContext context) => _Box(
        key: const Key('pro-cancel'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('解約のしかた', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final (i, step) in _steps.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 22, child: Text('${i + 1}.', style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.ink))),
                    Expanded(child: Text(step, style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.ink))),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              '期間が終わる24時間前までに解約すれば、次の更新から請求されません。解約しても、いまの期間が終わるまでは Pro のまま使えます。'
              'アプリを削除しても解約にはなりません。',
              style: TextStyle(fontSize: 13, height: 1.7, color: Palette.inkSoft),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('pro-manage'),
                onPressed: () => launchUrl(Uri.parse('https://apps.apple.com/account/subscriptions'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('サブスクリプションの管理を開く'),
              ),
            ),
          ],
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('・', style: TextStyle(fontSize: 15, height: 1.7)),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.7, color: Palette.ink))),
          ],
        ),
      );
}

class _Box extends StatelessWidget {
  const _Box({super.key, required this.child, this.highlight = false});
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight ? Palette.primarySoft : Palette.paper,
          border: Border.all(color: highlight ? Palette.primary : Palette.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );
}
