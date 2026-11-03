import 'package:flutter/material.dart';

import '../screens/pro_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// 上限で止まった画面から Pro を開く。Pro になって戻ったら onPro で止まっていた送信を戻す。
Future<void> openProFromCap(
  BuildContext context, {
  VoidCallback? onPro,
  String reason = 'cap',
  @visibleForTesting Future<void> Function(BuildContext context, String reason)? open,
}) async {
  final state = AppScope.read(context);
  await (open ?? ((c, r) => ProScreen.show(c, reason: r)))(context, reason);
  if (state.me?['pro'] == true) onPro?.call();
}

/// 今日の AI の回数を使い切ったときの知らせ。Pro でなければ Pro の案内を添える
/// （Pro は1日の上限が上がり、混雑による全体の上限も受けない）。
class CapNotice extends StatelessWidget {
  const CapNotice(this.message, {super.key, this.onPro, this.reason = 'cap'});
  final String message;
  final VoidCallback? onPro;

  /// paywall_open に記録する入口（cap = 送ろうとして止まった / home_cap = ホーム）
  final String reason;

  @override
  Widget build(BuildContext context) {
    final pro = AppScope.of(context).me?['pro'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.danger)),
        if (!pro)
          TextButton.icon(
            onPressed: () => openProFromCap(context, onPro: onPro, reason: reason),
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            label: const Text('Pro で回数を増やす'),
          ),
      ],
    );
  }
}
