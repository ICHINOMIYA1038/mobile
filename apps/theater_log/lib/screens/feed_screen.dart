import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/community_api.dart';
import '../app_scope.dart';
import '../theme.dart';
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
      if (mounted) setState(() { _reviews = r; _failed = false; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plays = {for (final p in AppScope.of(context).catalog.plays) p.id: p};
    final rows = _reviews;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text('みんなのひとこと', style: TextStyle(fontFamily: displayFont, fontSize: 30, height: 1.1, color: Palette.sumi)),
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
                    const Text('まだ、ひとことがありません', key: Key('feed-empty'), style: TextStyle(fontFamily: titleFont, fontSize: 20, fontWeight: FontWeight.w700, color: Palette.navy)),
                    const SizedBox(height: 10),
                    const Text('観た舞台の感想を公開すると、ここに並びます。最初の一人になりませんか。', textAlign: TextAlign.center, style: TextStyle(height: 1.7, color: Palette.inkSoft)),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: () => QuickLogSheet.open(context), child: const Text('観た舞台を記録する')),
                  ],
                ),
              )
            else
              for (final r in rows)
                ReviewTile(
                  review: r,
                  api: _api,
                  onBlocked: (id) => setState(() => _reviews = _reviews?.where((x) => x.authorId != id).toList()),
                  onOpenTitle: plays[r.postId] == null ? null : () => launchUrl(plays[r.postId]!.siteUrl, mode: LaunchMode.externalApplication),
                ),
          ],
        ),
      ),
    );
  }
}
