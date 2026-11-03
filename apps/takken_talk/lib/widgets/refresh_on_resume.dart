import 'package:flutter/widgets.dart';

import '../state/app_state.dart';

/// しばらくアプリを離れて戻ったら、自分とホームを取り直す。
/// 日付が変わって回数が戻った・あとから Pro になった、を開き直さなくても映すため。
class RefreshOnResume extends StatefulWidget {
  const RefreshOnResume({super.key, required this.child, this.after = const Duration(seconds: 60), this.now = DateTime.now});
  final Widget child;

  /// これより短い離席では取り直さない（通知を見て戻っただけのときなど）
  final Duration after;
  final DateTime Function() now;

  @override
  State<RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends State<RefreshOnResume> with WidgetsBindingObserver {
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _leftAt ??= widget.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && widget.now().difference(left) >= widget.after) AppScope.read(context).refreshQuietly();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
