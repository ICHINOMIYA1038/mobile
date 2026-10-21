import 'package:flutter/material.dart';

import '../ads/ad_banner.dart';
import '../models/core.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/figure/figure_view.dart';
import '../widgets/readable.dart';
import 'common/parts.dart';

/// 図解ライブラリ（サイトの /takken/figures）。全部の図を、中身の文字（text）と「どんなときに見る図か」で引ける。
/// 図の一覧はみんなに同じもので重い（400枚超）ので、タブを初めて開いたときに1回だけ取って持っておく。
class FigureLibraryScreen extends StatefulWidget {
  const FigureLibraryScreen({super.key});

  @override
  State<FigureLibraryScreen> createState() => _FigureLibraryScreenState();
}

class _Entry {
  const _Entry(this.figure, this.text);
  final FigureData figure;
  final String text;
}

class _Chapter {
  const _Chapter(this.id, this.order, this.title, this.subject);
  final String id;
  final int order;
  final String title;
  final String subject;
}

class _FigureLibraryScreenState extends State<FigureLibraryScreen> {
  List<_Entry>? _all;
  List<_Chapter> _chapters = const [];
  List<String> _subjects = const [];
  Object? _error;
  bool _loading = false;

  final _search = TextEditingController();
  String _query = '';
  String _subject = '';
  bool _onlyFav = false;

  /// お気に入りだけを見ているあいだに外した図は、すぐには消さない（押し間違いをその場で戻せるように）。
  /// 「★ お気に入り」に切り替えた時点のお気に入りを覚えておき、それも出す
  Set<String> _favView = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack は見えないタブを Visibility で隠している。見えたときに初めて取る（build の途中で setState しないよう次の番に）
    if (Visibility.of(context) && _all == null && !_loading) Future.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => (_loading = true, _error = null));
    try {
      final d = await AppScope.read(context).api.figures();
      final chapters = [
        for (final c in (d['chapters'] as List? ?? const []).cast<Map>()) _Chapter(c['id'] as String, (c['order'] as num?)?.toInt() ?? 0, c['title'] as String? ?? '', c['subject'] as String? ?? ''),
      ];
      final all = [for (final f in (d['figures'] as List? ?? const []).cast<Map>()) _Entry(FigureData.fromJson((f['figure'] as Map).cast<String, dynamic>()), f['text'] as String? ?? '')];
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _subjects = [for (final s in (d['subjects'] as List? ?? const []).cast<Map>()) s['name'] as String];
        _all = all;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setOnlyFav(bool on, Set<String> favs) => setState(() {
    _onlyFav = on;
    _favView = {...favs};
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final all = _all;
    return Scaffold(
      // Pro でない人にだけ、一覧の下にバナー（下のタブの上）
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(
        title: const Text('図解ライブラリ', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: all == null
          ? Center(
              child: _error != null ? LoadError(error: _error!, onRetry: _load) : const CircularProgressIndicator(),
            )
          : Column(
              children: [
                _filters(state.figureFavs),
                // 一覧を動かしたらキーボードを閉じる（ListView の keyboardDismissBehavior）
                Expanded(child: _list(all, state.figureFavs)),
              ],
            ),
    );
  }

  Widget _filters(Set<String> favs) => Readable(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: false, label: Text('すべて')),
              ButtonSegment(value: true, label: Text('★ お気に入り（${favs.length}）')),
            ],
            selected: {_onlyFav},
            onSelectionChanged: (s) => _setOnlyFav(s.first, favs),
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(0, 44),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              selectedBackgroundColor: Palette.primarySoft,
              selectedForegroundColor: Palette.primaryStrong,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Palette.paper,
              prefixIcon: const Icon(Icons.search),
              hintText: '中身を検索（例: 2週間、保証協会、農地）',
              hintStyle: const TextStyle(fontSize: 14, color: Palette.inkFaint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Palette.lineStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Palette.lineStrong),
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '消す',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in ['', ..._subjects])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(s.isEmpty ? 'すべての科目' : s),
                      selected: _subject == s,
                      onSelected: (_) => setState(() => _subject = s),
                      showCheckmark: false,
                      selectedColor: Palette.primarySoft,
                      backgroundColor: Palette.paper,
                      side: BorderSide(color: _subject == s ? Palette.primary : Palette.lineStrong),
                      labelStyle: TextStyle(fontSize: 13, color: _subject == s ? Palette.primaryStrong : Palette.inkSoft, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _list(List<_Entry> all, Set<String> favs) {
    final subjectOf = {for (final c in _chapters) c.id: c.subject};
    final shown = all.where((e) {
      final f = e.figure;
      if (_onlyFav && !favs.contains(f.id) && !_favView.contains(f.id)) return false;
      if (_subject.isNotEmpty && subjectOf[f.chapterId] != _subject) return false;
      return _query.isEmpty || e.text.contains(_query) || f.hint.contains(_query);
    }).toList();

    // 章の見出しと図を1列に並べる（ListView.builder で見えている分だけ作る）
    final rows = <Object>[];
    for (final c in _chapters) {
      final items = shown.where((e) => e.figure.chapterId == c.id);
      if (items.isEmpty) continue;
      rows.add(c);
      rows.addAll(items);
    }

    final small = Theme.of(context).textTheme.bodySmall;
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: rows.length + 1 + (rows.isEmpty ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Readable(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('会話の中で先生が出す図を、章をまたいで探せます。「2週間」「保証協会」のように、数字や用語で引けます。\n${shown.length}枚', style: small),
            ),
          );
        }
        if (rows.isEmpty) {
          final text = _onlyFav && favs.isEmpty && _favView.isEmpty
              ? 'まだお気に入りの図はありません。図の右上の「☆ お気に入り」を押すと、ここに集まります。'
              : _query.isNotEmpty
              ? '「$_query」に当てはまる図解はありません。別の言葉で探してみてください。'
              : '当てはまる図解はありません。';
          return Readable(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.inkSoft),
              ),
            ),
          );
        }
        final row = rows[i - 1];
        if (row is _Chapter) {
          return Readable(
            child: Container(
              // Readable は中央に寄せるので、短い見出しも左に置くため幅いっぱいにする
              width: double.infinity,
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                '第${row.order}章 ${row.title}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink),
              ),
            ),
          );
        }
        final e = row as _Entry;
        return Readable(
          key: ValueKey(e.figure.id),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FigureView(figure: e.figure, shownOn: 'library'),
                if (e.figure.hint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(e.figure.hint, style: const TextStyle(fontSize: 13, height: 1.6, color: Palette.inkSoft)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
