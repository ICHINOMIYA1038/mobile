import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../catalog/filter.dart';
import '../catalog/models.dart';
import '../theme.dart';
import '../widgets/play_card.dart';
import 'about_screen.dart';
import 'shortlist_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  PlayFilter _filter = const PlayFilter();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(PlayFilter f, String kind) {
    setState(() => _filter = f);
    AppInsights.logEvent('filter_change', parameters: {'kind': kind});
  }

  Future<void> _pickCategories(List<Category> all) async {
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: 'categories'),
      builder: (_) => _CategorySheet(all: all, selected: _filter.categoryIds),
    );
    if (picked != null) _set(_filter.copyWith(categoryIds: picked), 'category');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = AppScope.of(context).catalog;
    final hits = _filter.apply(catalog.plays);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('台本をさがす', style: TextStyle(fontFamily: titleFont, fontSize: 26, fontWeight: FontWeight.w700, color: Palette.navy)),
                      ),
                      ListenableBuilder(
                        listenable: AppScope.of(context).shortlist,
                        builder: (context, _) {
                          final n = AppScope.of(context).shortlist.ids.length;
                          return TextButton.icon(key: const Key('open-shortlist'), onPressed: () => ShortlistScreen.open(context), icon: const Icon(Icons.bookmark_border, size: 18), label: Text(n == 0 ? '気になる' : '気になる $n'));
                        },
                      ),
                      IconButton(tooltip: 'このアプリについて', icon: const Icon(Icons.info_outline, color: Palette.inkSoft), onPressed: () => AboutScreen.open(context)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text('戯曲図書館の作品を、人数と時間から', style: TextStyle(fontSize: 13, color: Palette.inkSoft)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _filter = _filter.copyWith(keyword: v)),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '作品名・作者名',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Palette.card,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ChipRow(
              label: '人数',
              ranges: castRanges,
              selected: _filter.cast,
              onSelected: (r) => _set(_filter.copyWith(cast: () => r), 'cast'),
            ),
          ),
          SliverToBoxAdapter(
            child: _ChipRow(
              label: '時間',
              ranges: minuteRanges,
              selected: _filter.minutes,
              onSelected: (r) => _set(_filter.copyWith(minutes: () => r), 'minutes'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    key: const Key('category-button'),
                    avatar: const Icon(Icons.theater_comedy_outlined, size: 18),
                    label: Text(_filter.categoryIds.isEmpty ? 'ジャンル' : 'ジャンル ${_filter.categoryIds.length}'),
                    onPressed: () => _pickCategories(catalog.categories),
                  ),
                  _SelectChip(
                    label: '読み先あり',
                    selected: _filter.readableOnly,
                    onSelected: (v) => _set(_filter.copyWith(readableOnly: v), 'readable'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${hits.length} 作品', key: const Key('hit-count'), style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink)),
                  ),
                  if (!_filter.isEmpty)
                    TextButton(
                      onPressed: () {
                        _controller.clear();
                        setState(() => _filter = const PlayFilter());
                      },
                      child: const Text('条件を消す'),
                    ),
                ],
              ),
            ),
          ),
          if (hits.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('条件に合う作品がありません。人数や時間の条件をゆるめてみてください。人数や時間が不明の作品は、絞り込むと表示されません。', style: TextStyle(height: 1.7, color: Palette.inkSoft)),
              ),
            )
          else
            SliverList.builder(itemCount: hits.length, itemBuilder: (_, i) => PlayCard(play: hits[i])),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.selected, required this.onSelected});
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label, style: TextStyle(color: selected ? Colors.white : Palette.ink)),
    selected: selected,
    onSelected: onSelected,
  );
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.ranges, required this.selected, required this.onSelected});
  final String label;
  final List<Range> ranges;
  final Range? selected;
  final ValueChanged<Range?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Center(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.inkSoft))),
        const SizedBox(width: 10),
        for (final r in ranges)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _SelectChip(label: r.label, selected: identical(r, selected), onSelected: (on) => onSelected(on ? r : null)),
          ),
      ],
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.all, required this.selected});
  final List<Category> all;
  final Set<int> selected;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final Set<int> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('ジャンル', style: TextStyle(fontWeight: FontWeight.w700)),
            trailing: FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('決定')),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  for (final c in widget.all)
                    _SelectChip(
                      label: c.name,
                      selected: _selected.contains(c.id),
                      onSelected: (on) => setState(() => on ? _selected.add(c.id) : _selected.remove(c.id)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
