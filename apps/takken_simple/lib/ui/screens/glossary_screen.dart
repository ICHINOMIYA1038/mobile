import 'package:flutter/material.dart';

import '../../data/terms_data.dart';
import '../../models/term.dart';
import 'term_detail_screen.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _query = '';
  String? _category;

  List<Term> get _visibleTerms {
    final normalized = _query.trim().toLowerCase();
    return baseTerms.where((term) {
      final categoryMatches = _category == null || term.category == _category;
      final searchable = [
        term.name,
        ...term.aliases,
        term.shortDescription,
        term.detailedDescription,
      ].join(' ').toLowerCase();
      return categoryMatches &&
          (normalized.isEmpty || searchable.contains(normalized));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terms = _visibleTerms;

    return Scaffold(
      appBar: AppBar(title: const Text('重要用語集')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SearchBar(
                hintText: '用語や説明を検索',
                leading: const Icon(Icons.search_rounded),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('すべて'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final category in const [
                    '宅建業法',
                    '権利関係',
                    '法令上の制限',
                    '税その他',
                  ]) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${terms.length}語',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: terms.isEmpty
                  ? const Center(child: Text('該当する用語はありません'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: terms.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final term = terms[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            title: Text(
                              term.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(term.shortDescription),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                settings: const RouteSettings(
                                  name: 'term_detail',
                                ),
                                builder: (_) => TermDetailScreen(term: term),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
