import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/auth_service.dart';
import '../app_scope.dart';
import '../catalog/log_flow_prefs.dart';
import '../theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AccountScreen(), settings: const RouteSettings(name: 'account')),
  );

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _say(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _signIn(String provider) async {
    final scope = AppScope.of(context);
    setState(() => _busy = true);
    try {
      await scope.auth.signIn(provider);
      AppInsights.logEvent('login', parameters: {'provider': provider});
      await scope.sync.run();
    } on SignInCancelled {
      // 自分でやめたので何も出さない
    } catch (e, st) {
      AppInsights.recordError(e, st, reason: 'sign_in');
      _say('ログインできませんでした。少し待ってからもう一度お試しください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final auth = AppScope.of(context).auth;
    _name.text = auth.user?.displayName ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('公開の名前'),
        content: TextField(key: const Key('name-field'), controller: _name, maxLength: 30, decoration: const InputDecoration(helperText: '公開した感想に表示されます。本名でなくて構いません')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('やめる')),
          TextButton(onPressed: () => Navigator.pop(ctx, _name.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await auth.setDisplayName(name);
    } on DisplayNameRejected catch (e) {
      _say(e.message);
    } catch (_) {
      _say('名前を変更できませんでした');
    }
  }

  Future<void> _signOut() async {
    final sync = AppScope.of(context).sync;
    setState(() => _busy = true);
    final done = await sync.signOut();
    if (!done && mounted) {
      final force = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('送信していない記録があります'),
          content: const Text('通信できないため、一部の記録がまだ保存されていません。このままログアウトすると、その記録は消えます。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('消してログアウト')),
          ],
        ),
      );
      if (force == true) await sync.signOut(force: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント')),
      body: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: auth.signedIn
              ? [
                  const Text('ログインしています。観劇の記録はクラウドにも保存され、機種を変えても引き継げます。写真は端末の中だけに保存します。', style: TextStyle(height: 1.7)),
                  const SizedBox(height: 16),
                  ListTile(key: const Key('rename'), contentPadding: EdgeInsets.zero, title: const Text('公開の名前'), subtitle: Text(auth.user?.displayName ?? '未設定（名無しの観客と表示されます）'), trailing: const Icon(Icons.edit, size: 18), onTap: _rename),
                  const Divider(),
                  TextButton(key: const Key('sign-out'), onPressed: _busy ? null : _signOut, child: const Text('ログアウト')),
                  TextButton(
                    key: const Key('delete-account'),
                    onPressed: () => launchUrl(Uri.parse('https://id.gikyokutosyokan.com/delete'), mode: LaunchMode.externalApplication),
                    child: const Text('アカウントを削除', style: TextStyle(color: Palette.vermilion)),
                  ),
                  const Text('削除すると、観劇の記録と公開した感想も消えます。戯曲 ID のページで手続きします。', style: TextStyle(fontSize: 12, height: 1.6, color: Palette.inkSoft)),
                  const SizedBox(height: 28),
                  const LogFlowSettings(),
                ]
              : [
                  const Text('戯曲 ID でログインすると、機種を変えても記録を引き継げ、感想を公開できます。ログインしなくても、記録は端末の中で使えます。', style: TextStyle(height: 1.7)),
                  const SizedBox(height: 20),
                  FilledButton.icon(key: const Key('sign-in-apple'), onPressed: _busy ? null : () => _signIn('apple'), icon: const Icon(Icons.apple), label: const Text('Apple でログイン')),
                  const SizedBox(height: 10),
                  OutlinedButton(key: const Key('sign-in-google'), onPressed: _busy ? null : () => _signIn('google'), child: const Text('Google でログイン')),
                  const SizedBox(height: 16),
                  const Text('戯曲図書館、戯曲パレット、TOMOSHIBI と同じアカウントです。', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                  const SizedBox(height: 28),
                  const LogFlowSettings(),
                ],
        ),
      ),
    );
  }
}

/// 記録の手順で出す画面。チケットと写真だけ切り替えられる
class LogFlowSettings extends StatefulWidget {
  const LogFlowSettings({super.key});

  @override
  State<LogFlowSettings> createState() => _LogFlowSettingsState();
}

class _LogFlowSettingsState extends State<LogFlowSettings> {
  ({bool ticket, bool photos})? _show;

  @override
  void initState() {
    super.initState();
    LogFlowPrefs.load().then((v) {
      if (mounted) setState(() => _show = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final show = _show;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('記録の手順', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('観た舞台を記録するときに出す画面です。題名・劇場・評価は毎回聞きます。', style: TextStyle(fontSize: 12, height: 1.6, color: Palette.inkSoft)),
        SwitchListTile(
          key: const Key('flow-setting-ticket'),
          contentPadding: EdgeInsets.zero,
          title: const Text('チケットを撮る'),
          value: show?.ticket ?? true,
          onChanged: show == null
              ? null
              : (v) async {
                  setState(() => _show = (ticket: v, photos: show.photos));
                  await LogFlowPrefs.showTicket(v);
                },
        ),
        SwitchListTile(
          key: const Key('flow-setting-photos'),
          contentPadding: EdgeInsets.zero,
          title: const Text('写真を残す'),
          value: show?.photos ?? true,
          onChanged: show == null
              ? null
              : (v) async {
                  setState(() => _show = (ticket: show.ticket, photos: v));
                  await LogFlowPrefs.showPhotos(v);
                },
        ),
      ],
    );
  }
}
