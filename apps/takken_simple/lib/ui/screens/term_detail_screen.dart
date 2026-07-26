import 'package:flutter/material.dart';

import '../../models/term.dart';
import '../../data/terms_data.dart';
import '../widgets/highlighted_text.dart';

/// 用語解説詳細画面。
/// わかりやすく親切なUIで、用語の詳細な定義や学習ポイントを解説する。
class TermDetailScreen extends StatelessWidget {
  const TermDetailScreen({super.key, required this.term});

  final Term term;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // カテゴリごとの配色を定義
    final (categoryColor, categoryBg) = switch (term.category) {
      '宅建業法' => (const Color(0xFF2E7D5B), const Color(0xFFE8F5E9)),
      '権利関係' => (const Color(0xFF2F5D8A), const Color(0xFFE3F2FD)),
      '法令上の制限' => (const Color(0xFFC57B1E), const Color(0xFFFFF3E0)),
      _ => (theme.colorScheme.primary, theme.colorScheme.primaryContainer),
    };

    final hasHighlights = baseTerms.any(
      (t) =>
          t.name != term.name &&
          [t.name, ...t.aliases].any(term.detailedDescription.contains),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '戻る',
        ),
        title: const Text('用語解説'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 用語名とカテゴリバッジを収めたメインカード
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.04,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // カテゴリバッジ
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? categoryColor.withValues(alpha: 0.2)
                            : categoryBg,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: categoryColor.withValues(
                            alpha: isDark ? 0.4 : 0.2,
                          ),
                        ),
                      ),
                      child: Text(
                        term.category,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? categoryColor.withValues(alpha: 0.9)
                              : categoryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 用語名（Heroで繋ぐ）
                    Hero(
                      tag: 'term-title-${term.id}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          term.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 端的な説明
                    Text(
                      term.shortDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 詳細説明カード
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '詳しい解説',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    HighlightedText(
                      text: term.detailedDescription,
                      excludeName: term.name,
                      style:
                          theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            height: 1.8,
                          ) ??
                          const TextStyle(fontSize: 16, height: 1.8),
                    ),
                    if (hasHighlights) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.8,
                            ),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '下線付きの言葉をタップすると、その用語解説を開きます。',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.9,
                                ),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // 戻るボタン
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('解説画面に戻る'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide(color: theme.colorScheme.primary),
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
