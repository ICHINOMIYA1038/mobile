import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/community_api.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/illustrations.dart';
import '../widgets/community_widgets.dart';
import 'quick_log_sheet.dart';

/// みんなのひとこと。最近公開された感想を流す
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, this.api});
  final CommunityApi? api;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Review>? _reviews;
  String? _next;
  bool _more = false;
  bool _failed = false;
  CommunityApi get _api => widget.api ?? CommunityApi(AppScope.of(context).auth);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reviews == null && !_failed) _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.feed();
      if (mounted) setState(() { _reviews = r.reviews; _next = r.next; _failed = false; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// 続きを読む。読めなかったら、ボタンを残してもう一度押せるようにする
  Future<void> _loadMore() async {
    final next = _next;
    if (next == null || _more) return;
    setState(() => _more = true);
    try {
      final r = await _api.feed(before: next);
      if (!mounted) return;
      final have = {for (final x in _reviews ?? const <Review>[]) x.id};
      setState(() {
        _reviews = [...?_reviews, ...r.reviews.where((x) => !have.contains(x.id))];
        _next = r.next;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('続きを読み込めませんでした')));
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plays = {for (final p in AppScope.of(context).catalog.plays) p.id: p};
    final rows = _reviews;
    // 紙の画面なので、時刻や電池の表示は黒に
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text('みんなのひとこと', style: TextStyle(fontFamily: displayFont, fontSize: 30, height: 1.1, color: Palette.sumi)),
            const SizedBox(height: 6),
            // 自分の記録や写真が勝手に出るのではと不安にならないよう、何が並ぶかを先に言う
            const Text(
              '自分で「公開する」にした感想だけが並びます。記録は自動では公開されず、写真はどこにも公開・送信されません。',
              key: Key('feed-note'),
              style: TextStyle(fontSize: 12, height: 1.6, color: Palette.inkSoft),
            ),
            const SizedBox(height: 12),
            if (_failed)
              const Padding(padding: EdgeInsets.all(24), child: Text('読み込めませんでした。下に引っぱると、もう一度読み込みます。', style: TextStyle(height: 1.7, color: Palette.inkSoft)))
            else if (rows == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 40, 8, 8),
                child: Column(
                  children: [
                    const LineArt.seats(key: Key('art-seats'), width: 200),
                    const SizedBox(height: 18),
                    const Text('まだ、ひとことがありません', key: Key('feed-empty'), style: TextStyle(fontFamily: titleFont, fontSize: 20, fontWeight: FontWeight.w700, color: Palette.navy)),
                    const SizedBox(height: 10),
                    const Text('観た舞台の感想を公開すると、ここに並びます。最初の一人になりませんか。', textAlign: TextAlign.center, style: TextStyle(height: 1.7, color: Palette.inkSoft)),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: () => QuickLogSheet.open(context), child: const Text('観た舞台を記録する')),
                  ],
                ),
              )
            else ...[
              for (final r in rows)
                ReviewTile(
                  review: r,
                  api: _api,
                  onBlocked: (id) => setState(() => _reviews = _reviews?.where((x) => x.authorId != id).toList()),
                  onOpenTitle: plays[r.postId] == null ? null : () => launchUrl(plays[r.postId]!.siteUrl, mode: LaunchMode.externalApplication),
                ),
              if (_next != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: _more
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                        : TextButton(key: const Key('feed-more'), onPressed: _loadMore, child: const Text('もっと見る')),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}
