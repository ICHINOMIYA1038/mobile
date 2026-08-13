import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/elements.dart';
import '../../data/glossary_terms.dart';
import '../../data/progress_repository.dart';
import '../theme.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final _tabController = TabController(length: 3, vsync: this);
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用語集'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '用語'),
            Tab(text: '元素周期表'),
            Tab(text: '暗記カード'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsTab(context),
          const _PeriodicTableTab(),
          const _FlashcardTab(),
        ],
      ),
    );
  }

  Widget _buildTermsTab(BuildContext context) {
    final colors = AppColors.of(context);
    final query = _query.trim();
    final terms = query.isEmpty
        ? kGlossaryTerms
        : kGlossaryTerms.where((term) {
            return term.term.contains(query) ||
                term.unit.contains(query) ||
                term.explanation.contains(query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: '用語・単元名で検索',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: colors.cardBackground,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: terms.isEmpty
              ? Center(
                  child: Text(
                    '「$query」に一致する用語が見つかりません',
                    style: TextStyle(
                      color: colors.textPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: terms.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _GlossaryTile(term: terms[index]);
                  },
                ),
        ),
      ],
    );
  }
}

class _GlossaryTile extends StatelessWidget {
  const _GlossaryTile({required this.term});

  final GlossaryTerm term;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                term.term,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: labMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    term.unit,
                    style: const TextStyle(
                      color: labMint,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedAlignment: Alignment.centerLeft,
              children: [
                Text(
                  term.explanation,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 用語集の内容をカード形式でめくりながら覚える暗記モード。
/// スワイプではなく、タップでの裏返し+ボタン操作でシンプルに実装している。
class _FlashcardTab extends StatefulWidget {
  const _FlashcardTab();

  @override
  State<_FlashcardTab> createState() => _FlashcardTabState();
}

class _FlashcardTabState extends State<_FlashcardTab> {
  final _repository = ProgressRepository();
  Set<String> _known = {};
  int _index = 0;
  bool _flipped = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final known = await _repository.loadKnownTerms();
    if (!mounted) return;
    setState(() {
      _known = known;
      _loaded = true;
    });
  }

  void _next({required bool markKnown}) {
    final term = kGlossaryTerms[_index].term;
    if (markKnown && !_known.contains(term)) {
      setState(() => _known = {..._known, term});
      unawaited(_repository.toggleKnownTerm(term));
    }
    setState(() {
      _index++;
      _flipped = false;
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final colors = AppColors.of(context);
    final total = kGlossaryTerms.length;

    if (_index >= total) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration, color: nekoOrange, size: 48),
              const SizedBox(height: 16),
              Text('全部終わりました!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '覚えた用語: ${_known.length} / $total',
                style: TextStyle(
                  color: colors.textPrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _restart, child: const Text('はじめから')),
            ],
          ),
        ),
      );
    }

    final term = kGlossaryTerms[_index];
    final isKnown = _known.contains(term.term);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_index + 1} / $total',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '覚えた: ${_known.length}',
                style: TextStyle(color: labMint, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _flipped = !_flipped),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isKnown
                        ? labMint.withValues(alpha: 0.5)
                        : nekoOrange.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: labMint.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          term.unit,
                          style: const TextStyle(
                            color: labMint,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _flipped ? term.explanation : term.term,
                        textAlign: TextAlign.center,
                        style: _flipped
                            ? Theme.of(context).textTheme.bodyLarge
                            : Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _flipped ? 'タップして表に戻す' : 'タップして意味を見る',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _next(markKnown: false),
                  child: const Text('もう一度'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _next(markKnown: true),
                  child: const Text('覚えた'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _categoryColor(ElementCategory category) {
  switch (category) {
    case ElementCategory.alkaliMetal:
      return const Color(0xFFE8873A);
    case ElementCategory.alkalineEarthMetal:
      return const Color(0xFFD9A441);
    case ElementCategory.transitionMetal:
      return const Color(0xFF8C6E54);
    case ElementCategory.metalloid:
      return const Color(0xFF4FB286);
    case ElementCategory.nonmetal:
      return const Color(0xFF3E9C7B);
    case ElementCategory.halogen:
      return const Color(0xFFD1615A);
    case ElementCategory.nobleGas:
      return const Color(0xFF8A7FBB);
    case ElementCategory.otherMetal:
      return const Color(0xFF6E8AA6);
  }
}

/// 高校化学の範囲に絞った簡易周期表。タップすると詳細をボトムシートで表示する。
class _PeriodicTableTab extends StatelessWidget {
  const _PeriodicTableTab();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('第1〜4周期の典型元素', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'タップすると詳しい説明が見られます',
            style: TextStyle(
              fontSize: 12,
              color: colors.textPrimary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          ...kPeriodicTableGrid.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: row.map((symbol) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: symbol == null
                          ? const SizedBox(height: 54)
                          : _ElementTile(symbol: symbol),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('代表的な遷移金属', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: kOtherElements.map((symbol) {
              return SizedBox(
                width: 76,
                height: 54,
                child: _ElementTile(symbol: symbol),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ElementTile extends StatelessWidget {
  const _ElementTile({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    final info = kElements[symbol]!;
    final color = _categoryColor(info.category);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showElementDetail(context, info, color),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${info.atomicNumber}',
              style: TextStyle(fontSize: 8, color: color),
            ),
            Text(
              info.symbol,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showElementDetail(BuildContext context, ElementInfo info, Color color) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      info.symbol,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '原子番号 ${info.atomicNumber}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              info.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
