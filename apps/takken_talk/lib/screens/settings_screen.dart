import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../purchase_service.dart';
import '../state/app_state.dart';
import '../widgets/readable.dart';
import '../widgets/exam_date.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _pickExamDate() async {
    final state = AppScope.of(context);
    final current = parseDate(state.me!.examDate) ?? nextExamDate();
    final d = await showDatePicker(
      context: context,
      initialDate: current.isBefore(DateTime.now()) ? DateTime.now() : current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (d == null) return;
    await state.api.patchMe(examDate: formatDate(d));
    await state.refresh();
  }

  Future<void> _editNickname() async {
    final state = AppScope.of(context);
    final c = TextEditingController(text: state.me!.nickname ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('呼び名'),
        content: TextField(controller: c, maxLength: 20, decoration: const InputDecoration(hintText: 'AIがあなたを呼ぶ名前')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (v == null) return;
    await state.api.patchMe(nickname: v);
    await state.refresh();
  }

  Future<void> _restore() async {
    final state = AppScope.of(context);
    setState(() => _busy = true);
    try {
      await PurchaseService.restore(state.me!.userId);
      await Future<void>.delayed(const Duration(seconds: 2));
      await state.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.me!.plan.isPro ? 'Proを復元しました' : '復元できる購入が見つかりませんでした')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('復元できませんでした: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll() async {
    final state = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('学習データを削除'),
        content: const Text('会話の履歴と進捗をサーバーから削除し、新しいユーザーとして始めます。購入済みのProは「購入を復元」で戻せますが、会話パックの残りは戻りません。よろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await state.api.deleteMe();
      await state.init();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除できませんでした: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final theme = Theme.of(context);
    final exam = parseDate(me.examDate);
    return Scaffold(
      appBar: AppBar(title: const Text('設定'), backgroundColor: theme.scaffoldBackgroundColor),
      body: Readable(
        child: ListView(
        children: [
          const _Header('学習'),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('試験日'),
            subtitle: Text(exam == null ? '未設定' : '${formatDateJa(exam)}（あと${daysUntil(exam)}日）'),
            onTap: _pickExamDate,
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('呼び名'),
            subtitle: Text(me.nickname?.isNotEmpty == true ? me.nickname! : '未設定'),
            onTap: _editNickname,
          ),
          const _Header('プラン'),
          ListTile(
            leading: Icon(me.plan.isPro ? Icons.workspace_premium : Icons.bolt),
            title: Text(me.plan.isPro ? 'Pro（有効）' : '無料プラン'),
            subtitle: Text(
              me.plan.isPro
                  ? '全章で会話できます'
                  : '第1章の無料枠 残り${me.plan.freeLeft}回${me.plan.turnBalance > 0 ? '、会話パック 残り${me.plan.turnBalance}回' : ''}',
            ),
            trailing: me.plan.isPro ? null : const Icon(Icons.chevron_right),
            onTap: me.plan.isPro ? null : () => PaywallScreen.show(context, reason: 'settings'),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('購入を復元'),
            enabled: !_busy,
            onTap: _restore,
          ),
          const _Header('このアプリについて'),
          const ListTile(
            leading: Icon(Icons.smart_toy_outlined),
            title: Text('AIについて'),
            subtitle: Text('返答はAI（Anthropic Claude）が生成しています。誤りを含むことがあるので、数字や法改正はテキストや公式情報で確認してください。会話内容は学習の継続と品質改善のためサーバーに保存されます。個人を特定する情報の入力は避けてください。'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            onTap: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            onTap: () => launchUrl(Uri.parse(AppConfig.termsUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('サポート・お問い合わせ'),
            onTap: () => launchUrl(Uri.parse(AppConfig.supportUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('ライセンス'),
            onTap: () => showLicensePage(context: context, applicationName: '話して受かる宅建'),
          ),
          const _Header('データ'),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text('学習データを削除', style: TextStyle(color: theme.colorScheme.error)),
            enabled: !_busy,
            onTap: _deleteAll,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('ユーザーID: ${me.userId}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ),
        ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
