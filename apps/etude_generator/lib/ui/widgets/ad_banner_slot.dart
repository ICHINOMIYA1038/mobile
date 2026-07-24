import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/ad_service.dart';

/// 実演画面・振り返り画面の中に置く控えめなバナー。
///
/// **このウィジェットを他の画面（タイトル・生成・役引き・お気に入り）に置かないこと。**
/// 役を引く画面は他人に見せてはいけない内容が映るため、広告表示の対象にしない。
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面幅が確定してからでないとアダプティブサイズを決められないためここで読む。
    if (_requested) return;
    _requested = true;
    _load();
  }

  Future<void> _load() async {
    final width = MediaQuery.of(context).size.width.truncate();
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
    final banner = _banner;
    if (banner == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 広告とコンテンツの境目を明示する。誤タップ狙いの配置はしない。
        Text(
          '広告',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF9A8E87),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: banner.size.width.toDouble(),
          height: banner.size.height.toDouble(),
          child: AdWidget(ad: banner),
        ),
      ],
    );
  }
}
