import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

import '../state/app_state.dart';
import '../theme.dart';
import 'ad_service.dart';

/// 画面の下のバナー（学ぶ・過去問・図解・復習の一覧と、過去問を解く画面だけ）。
///
/// **会話・AIに聞く・Pro の画面・設定・模擬試験には置かない。** test/ads_test.dart が置いてよい画面を決めている。
///
/// Pro の人・自分を読めていないあいだ・読み込めなかったときは高さ 0。Pro になったら（AppScope が変わったら）その場で消える。
/// 学習の中身との境目が分かるように、上に線と「広告」の文字を出す（誤って押させる置き方はしない）。
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.safeArea = false});

  /// 画面のいちばん下に置くとき（下のタブが無い画面）は、ホームインジケーターの分をあける
  final bool safeArea;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _banner;
  bool _requested = false;
  bool _allowed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 幅が決まってからでないとアダプティブの大きさを決められないので、ここで読む
    _allowed = adsAllowed(AppScope.of(context));
    if (!_allowed) {
      // Pro になった。広告は描かなくなったあとで捨てる
      final old = _banner;
      _banner = null;
      _requested = false;
      if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      return;
    }
    if (_requested) return;
    _requested = true;
    _load();
  }

  Future<void> _load() async {
    final mq = MediaQuery.of(context);
    final banner = await AdService.instance.loadBanner(width: mq.size.width.truncate(), orientation: mq.orientation);
    if (!mounted || !_allowed) {
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
    if (!_allowed || banner == null) return const SizedBox.shrink();
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Text('広告', style: TextStyle(fontSize: 11, color: Palette.inkFaint)),
        ),
        SizedBox(width: banner.size.width.toDouble(), height: banner.size.height.toDouble(), child: AdWidget(ad: banner)),
      ],
    );
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Palette.desk, border: Border(top: BorderSide(color: Palette.line))),
      child: widget.safeArea ? SafeArea(top: false, child: body) : body,
    );
  }
}
