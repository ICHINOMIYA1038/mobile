import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/ad_service.dart';

/// 結果画面の下部に置くバナー。
///
/// **このウィジェットを出題画面や解説画面に置かないこと。** 広告は結果画面だけという約束が
/// このアプリの差別化そのもので、`test/no_ads_during_study_test.dart` がそれを検証している。
///
/// 読み込めなかった場合・購入済みの場合は高さ0で消える（枠だけ残して場所を取らない）。
class ResultBannerAd extends StatefulWidget {
  const ResultBannerAd({super.key, required this.adsRemoved});

  final bool adsRemoved;

  @override
  State<ResultBannerAd> createState() => _ResultBannerAdState();
}

class _ResultBannerAdState extends State<ResultBannerAd> {
  BannerAd? _banner;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面幅が確定してからでないとアダプティブサイズを決められないためここで読む。
    if (_requested || widget.adsRemoved) return;
    _requested = true;
    _load();
  }

  Future<void> _load() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final banner = await AdService().loadResultBanner(width: width);
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
    if (widget.adsRemoved || banner == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 広告と学習内容の境目を明示する。誤タップ狙いの配置はしない。
        Text(
          '広告',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
