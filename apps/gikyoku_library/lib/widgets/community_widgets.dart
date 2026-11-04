import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/community_api.dart';
import '../app_scope.dart';
import '../screens/account_screen.dart';
import '../theme.dart';

/// 公開する前に一度だけ、投稿のルールに同意してもらう（App Store の要件）
class CommunityRules {
  static const _key = 'community_rules_v1';

  static Future<bool> confirm(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) == true) return true;
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('公開の前に'),
        content: const Text(
          '他の人や団体への中傷、差別、個人情報、ネタバレを隠さない重大な内容の書き込みは禁止です。'
          '不適切な投稿は削除し、繰り返す場合は利用をお断りします。通報には運営が確認して対応します。',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => launchUrl(Uri.parse('https://gikyokutosyokan.com/support/tos'), mode: LaunchMode.externalApplication), child: const Text('利用規約')),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          TextButton(key: const Key('rules-agree'), onPressed: () => Navigator.pop(ctx, true), child: const Text('同意する')),
        ],
      ),
    );
    if (ok == true) await prefs.setBool(_key, true);
    return ok == true;
  }
}

/// 作品ページの「みんなの感想」
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({super.key, required this.postId, this.api});
  final int postId;
  final CommunityApi? api;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
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
      final r = await _api.reviews(postId: widget.postId);
      if (mounted) setState(() { _reviews = r; _failed = false; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<bool> _needLogin() async {
    final auth = AppScope.of(context).auth;
    if (auth.signedIn) return true;
    await AccountScreen.open(context);
    return auth.signedIn;
  }

  void _say(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _report(Review r) async {
    if (!await _needLogin() || !mounted) return;
    final reason = await showModalBottomSheet<String>(
      context: context,
      routeSettings: const RouteSettings(name: 'report'),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('通報の理由', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final x in const ['中傷や差別', '個人情報', 'スパムや宣伝', 'その他の不適切な内容']) ListTile(title: Text(x), onTap: () => Navigator.pop(ctx, x)),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await _api.report(r.id, reason);
      AppInsights.logEvent('review_report');
      _say('通報しました。運営が確認します');
    } on CommunityError catch (e) {
      _say(e.message);
    } catch (_) {
      _say('通信できませんでした');
    }
  }

  Future<void> _block(Review r) async {
    if (!await _needLogin() || !mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${r.authorName}さんをブロックしますか'),
        content: const Text('この人の感想が表示されなくなります。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ブロック')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.block(r.authorId);
      AppInsights.logEvent('user_block');
      if (mounted) setState(() => _reviews = _reviews?.where((x) => x.authorId != r.authorId).toList());
      _say('ブロックしました');
    } on CommunityError catch (e) {
      _say(e.message);
    } catch (_) {
      _say('通信できませんでした');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).auth.user?.id;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('みんなの感想', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.vermilion)),
          const SizedBox(height: 6),
          if (_failed)
            const Text('感想を読み込めませんでした。', style: TextStyle(fontSize: 14, color: Palette.inkSoft))
          else if (_reviews == null)
            const Text('読み込み中です…', style: TextStyle(fontSize: 14, color: Palette.inkSoft))
          else if (_reviews!.isEmpty)
            const Text('まだ感想がありません。観たら最初の感想を残してみませんか。', style: TextStyle(fontSize: 14, height: 1.6, color: Palette.inkSoft))
          else
            for (final r in _reviews!)
              Container(
                key: Key('review-${r.id}'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
                decoration: BoxDecoration(color: Palette.card, border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.authorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                        if (r.rating != null) Text('★' * r.rating!, style: const TextStyle(fontSize: 12, color: Palette.vermilion)),
                        if (r.authorId != me)
                          PopupMenuButton<String>(
                            key: Key('review-menu-${r.id}'),
                            tooltip: 'この感想の操作',
                            icon: const Icon(Icons.more_horiz, size: 18),
                            onSelected: (v) => v == 'report' ? _report(r) : _block(r),
                            itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('通報する')), PopupMenuItem(value: 'block', child: Text('この人をブロック'))],
                          )
                        else
                          const SizedBox(height: 40, width: 8),
                      ],
                    ),
                    Padding(padding: const EdgeInsets.only(right: 8), child: Text(r.note, style: const TextStyle(fontSize: 14, height: 1.7))),
                    if (r.groupName != null || r.venueName != null || r.watchedMonth != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Text([r.groupName, r.venueName, r.watchedMonth?.replaceAll('-', '.')].whereType<String>().join('／'), style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// 公演を探して選ぶ。無ければ登録する
class ProductionPicker extends StatefulWidget {
  const ProductionPicker({super.key, required this.initialQuery, this.postId, this.api});
  final String initialQuery;
  final int? postId;
  final CommunityApi? api;

  @override
  State<ProductionPicker> createState() => _ProductionPickerState();
}

class _ProductionPickerState extends State<ProductionPicker> {
  late final _q = TextEditingController(text: widget.initialQuery);
  final _group = TextEditingController();
  final _venue = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  List<Production>? _rows;
  bool _creating = false;
  String? _error;
  CommunityApi get _api => widget.api ?? CommunityApi(AppScope.of(context).auth);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rows == null) _search();
  }

  @override
  void dispose() {
    for (final c in [_q, _group, _venue, _start, _end]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _search() async {
    try {
      final rows = await _api.productions(query: _q.text.trim().isEmpty ? null : _q.text, postId: _q.text.trim().isEmpty ? widget.postId : null);
      if (mounted) setState(() { _rows = rows; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _rows = const []; _error = '公演を読み込めませんでした'; });
    }
  }

  String? _date(TextEditingController c) {
    final t = c.text.trim().replaceAll('/', '-');
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t) ? t : null;
  }

  Future<void> _create() async {
    if (_q.text.trim().isEmpty) return setState(() => _error = '公演名を入れてください');
    try {
      final p = await _api.createProduction({
        'title': _q.text.trim(),
        'postId': widget.postId,
        'groupName': _group.text.trim(),
        'venueName': _venue.text.trim(),
        'startDate': _date(_start),
        'endDate': _date(_end),
      });
      AppInsights.logEvent('production_create');
      if (mounted) Navigator.pop(context, p);
    } on CommunityError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '通信できませんでした');
    }
  }

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('production-query'),
                controller: _q,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(labelText: _creating ? '公演名（必須）' : '公演名・劇団・劇場で探す', border: border, suffixIcon: _creating ? null : IconButton(tooltip: '探す', icon: const Icon(Icons.search), onPressed: _search)),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Palette.vermilion))),
              if (!_creating) ...[
                for (final p in _rows ?? const <Production>[])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.title),
                    subtitle: Text([p.groupName, p.venueName, p.startDate, if (p.status == 'pending') '確認待ち'].whereType<String>().join('／')),
                    onTap: () => Navigator.pop(context, p),
                  ),
                if (_rows != null && _rows!.isEmpty && _error == null) const Padding(padding: EdgeInsets.all(12), child: Text('見つかりませんでした。', style: TextStyle(color: Palette.inkSoft))),
                TextButton.icon(key: const Key('production-new'), onPressed: () => setState(() => _creating = true), icon: const Icon(Icons.add), label: const Text('この公演を登録する')),
              ] else ...[
                const SizedBox(height: 12),
                TextField(controller: _group, decoration: const InputDecoration(labelText: '劇団・団体', border: border)),
                const SizedBox(height: 12),
                TextField(controller: _venue, decoration: const InputDecoration(labelText: '劇場', border: border)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _start, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: '初日 2026-12-01', border: border))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _end, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: '千秋楽', border: border))),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('運営の確認が済むまで、他の人には表示されません。自分の記録にはすぐ使えます。', style: TextStyle(fontSize: 12, height: 1.5, color: Palette.inkSoft)),
                const SizedBox(height: 8),
                FilledButton(key: const Key('production-create'), onPressed: _create, child: const Text('登録する')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
