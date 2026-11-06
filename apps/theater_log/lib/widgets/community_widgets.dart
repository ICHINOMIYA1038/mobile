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
          TextButton(
            onPressed: () => launchUrl(Uri.parse('https://gikyokutosyokan.com/support/tos'), mode: LaunchMode.externalApplication),
            child: const Text('利用規約'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          TextButton(key: const Key('rules-agree'), onPressed: () => Navigator.pop(ctx, true), child: const Text('同意する')),
        ],
      ),
    );
    if (ok == true) await prefs.setBool(_key, true);
    return ok == true;
  }
}

/// 感想 1 件。他の人の感想には通報とブロックを出す
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, required this.api, required this.onBlocked, this.onOpenTitle});
  final Review review;
  final CommunityApi api;
  final ValueChanged<String> onBlocked;
  final VoidCallback? onOpenTitle;

  void _say(BuildContext context, String text) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _needLogin(BuildContext context) async {
    final auth = AppScope.of(context).auth;
    if (auth.signedIn) return true;
    await AccountScreen.open(context);
    return auth.signedIn;
  }

  Future<void> _report(BuildContext context) async {
    if (!await _needLogin(context) || !context.mounted) return;
    final reason = await showModalBottomSheet<String>(
      context: context,
      routeSettings: const RouteSettings(name: 'report'),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('通報の理由', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final x in const ['中傷や差別', '個人情報', 'スパムや宣伝', 'その他の不適切な内容']) ListTile(title: Text(x), onTap: () => Navigator.pop(ctx, x)),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await api.report(review.id, reason);
      AppInsights.logEvent('review_report');
      if (context.mounted) _say(context, '通報しました。運営が確認します');
    } on CommunityError catch (e) {
      if (context.mounted) _say(context, e.message);
    } catch (_) {
      if (context.mounted) _say(context, '通信できませんでした');
    }
  }

  Future<void> _block(BuildContext context) async {
    if (!await _needLogin(context) || !context.mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${review.authorName}さんをブロックしますか'),
        content: const Text('この人の感想が表示されなくなります。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ブロック')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await api.block(review.authorId);
      AppInsights.logEvent('user_block');
      onBlocked(review.authorId);
      if (context.mounted) _say(context, 'ブロックしました');
    } on CommunityError catch (e) {
      if (context.mounted) _say(context, e.message);
    } catch (_) {
      if (context.mounted) _say(context, '通信できませんでした');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = review;
    final me = AppScope.of(context).auth.user?.id;
    final place = [r.groupName, r.venueName, r.watchedMonth?.replaceAll('-', '.')].whereType<String>().join('／');
    // 枠で囲まず、線で区切った読み物として並べる。公演名を先に、書いた人は最後に小さく
    return Container(
      key: Key('review-${r.id}'),
      padding: const EdgeInsets.fromLTRB(2, 16, 0, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.title != null)
            InkWell(
              onTap: onOpenTitle,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  r.title!,
                  style: const TextStyle(fontFamily: titleFont, fontSize: 17, height: 1.4, fontWeight: FontWeight.w700, color: Palette.ink),
                ),
              ),
            ),
          Row(
            children: [
              if (r.rating != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('★' * r.rating!, style: const TextStyle(fontSize: 13, color: Palette.vermilion)),
                ),
              if (place.isNotEmpty)
                Expanded(
                  child: Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 4),
            child: Text(r.note, style: const TextStyle(fontSize: 15, height: 1.8, color: Palette.ink)),
          ),
          Row(
            children: [
              Expanded(
                child: Text(r.authorName, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
              ),
              if (r.authorId != me)
                PopupMenuButton<String>(
                  key: Key('review-menu-${r.id}'),
                  tooltip: 'この感想の操作',
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onSelected: (v) => v == 'report' ? _report(context) : _block(context),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'report', child: Text('通報する')),
                    // 未ログインで書かれたサイトのコメントには、ブロックする相手がいない
                    if (r.authorId.isNotEmpty) const PopupMenuItem(value: 'block', child: Text('この人をブロック')),
                  ],
                )
              else
                const SizedBox(height: 40, width: 8),
            ],
          ),
          if (onOpenTitle != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Palette.moegi, padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                onPressed: onOpenTitle,
                icon: const Icon(Icons.menu_book_outlined, size: 15),
                label: const Text('この作品の台本', style: TextStyle(fontSize: 12)),
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
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rows = const [];
          _error = '公演を読み込めませんでした';
        });
      }
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
                decoration: InputDecoration(
                  labelText: _creating ? '公演名（必須）' : '公演名・劇団・劇場で探す',
                  border: border,
                  suffixIcon: _creating ? null : IconButton(tooltip: '探す', icon: const Icon(Icons.search), onPressed: _search),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Palette.vermilion)),
                ),
              if (!_creating) ...[
                for (final p in _rows ?? const <Production>[])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.title),
                    subtitle: Text([p.groupName, p.venueName, p.startDate, if (p.status == 'pending') '確認待ち'].whereType<String>().join('／')),
                    onTap: () => Navigator.pop(context, p),
                  ),
                if (_rows != null && _rows!.isEmpty && _error == null)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('見つかりませんでした。', style: TextStyle(color: Palette.inkSoft)),
                  ),
                TextButton.icon(key: const Key('production-new'), onPressed: () => setState(() => _creating = true), icon: const Icon(Icons.add), label: const Text('この公演を登録する')),
              ] else ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _group,
                  decoration: const InputDecoration(labelText: '劇団・団体', border: border),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _venue,
                  decoration: const InputDecoration(labelText: '劇場', border: border),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _start,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(labelText: '初日 2026-12-01', border: border),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _end,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(labelText: '千秋楽', border: border),
                      ),
                    ),
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
