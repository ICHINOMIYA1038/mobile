import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/ad_service.dart';
import '../../theme/app_colors.dart';

/// 結果画面の中に置く控えめなバナー。
///
/// **このウィジェットを他の画面（ホーム・入力画面）に置かないこと。**
/// `test/no_ads_during_activity_test.dart` がこの約束を検証している。
///
/// 読み込めなかった場合は高さ0で消える（枠だけ残して場所を取らない）。
class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key});

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _banner;
  bool _requested = false;

  Future<void> _load(int width) async {
    final banner = await AdService().loadBanner(width: width);
    if (!mounted) {
      banner?.dispose();
      return;
    }
    setState(() => _banner = banner);
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 画面幅ではなく、このスロットに実際に与えられた幅でサイズを決める
    // (親に左右24ptの余白があり、画面幅で要求すると右端が48pt切れていた)。
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_requested && constraints.maxWidth.isFinite) {
          _requested = true;
          _load(constraints.maxWidth.truncate());
        }
        final banner = _banner;
        if (banner == null) return const SizedBox.shrink();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 広告とコンテンツの境目を明示する。誤タップ狙いの配置はしない。
            Text(
              '広告',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: 4),
            Center(
              child: SizedBox(
                width: banner.size.width.toDouble(),
                height: banner.size.height.toDouble(),
                child: AdWidget(ad: banner),
              ),
            ),
          ],
        );
      },
    );
  }
}
