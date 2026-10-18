import 'package:flutter/material.dart';

import '../screens/pro_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// 今日の AI の回数を使い切ったときの知らせ。Pro でなければ Pro の案内を添える
/// （Pro は1日の上限が上がり、混雑による全体の上限も受けない）。
class CapNotice extends StatelessWidget {
  const CapNotice(this.message, {super.key});
  final String message;

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
            onPressed: () => ProScreen.show(context, reason: 'cap'),
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            label: const Text('Pro で回数を増やす'),
          ),
      ],
    );
  }
}
