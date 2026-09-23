import 'package:flutter/material.dart';

import '../../data/ad_service.dart';

/// EEA/UK など同意が必要な地域のユーザーに、広告の同意内容をいつでも見直せる
/// 入り口を出す(Google UMP の要件)。それ以外の地域では何も表示しない。
class PrivacyOptionsAction extends StatelessWidget {
  const PrivacyOptionsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdService.isPrivacyOptionsRequired(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return IconButton(
          tooltip: '広告のプライバシー設定',
          icon: const Icon(Icons.privacy_tip_outlined),
          onPressed: () => AdService.showPrivacyOptionsForm(),
        );
      },
    );
  }
}
