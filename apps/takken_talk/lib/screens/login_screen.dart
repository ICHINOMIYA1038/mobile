import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/readable.dart';
import 'common/parts.dart';

/// Web（shikaku.pairof.jp）で作ったアカウントにログインする。
/// この端末で学んだ分はアカウントへ引き継がれる（サーバーの POST /api/v1/login）。成功したら true で閉じる。
/// 新規登録・パスワードの再設定はアプリでは扱わない（Web の画面に任せる）。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'メールアドレスとパスワードを入れてください。');
      return;
    }
    FocusScope.of(context).unfocus();
    final state = AppScope.read(context);
    setState(() => (_sending = true, _error = null));
    try {
      await state.api.login(email, password);
      await state.afterAccountChange();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Palette.paper,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Palette.lineStrong),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Readable(
            maxWidth: 480,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Web のアカウントでログインすると、別の端末でも学習の続きから話せます。この端末で学んだ分は、ログインしたアカウントに引き継ぎます。', style: TextStyle(fontSize: 14, height: 1.7, color: Palette.ink)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: _deco('メールアドレス'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _submit(),
                    decoration: _deco('パスワード'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_error!, style: const TextStyle(color: Palette.danger, fontSize: 14)),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _sending ? null : _submit, child: Text(_sending ? 'ログインしています…' : 'ログイン')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
