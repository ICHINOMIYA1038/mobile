import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/terms_data.dart';
import '../screens/term_detail_screen.dart';

/// 重要用語を自動検出し、太字（およびテーマカラー、下線）で強調表示し、
/// タップすると用語解説画面に遷移するインタラクティブなテキストウィジェット。
class HighlightedText extends StatefulWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.style,
    this.excludeName,
  });

  final String text;
  final TextStyle style;
  final String? excludeName;

  @override
  State<HighlightedText> createState() => _HighlightedTextState();
}

class _HighlightedTextState extends State<HighlightedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightStyle = widget.style.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
    );

    // 用語名のリストを長い順にソート（部分一致で短い方が先にマッチするのを防ぐため）
    final termNames =
        baseTerms
            .expand((t) => [t.name, ...t.aliases])
            .where((name) => name != widget.excludeName)
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));

    if (termNames.isEmpty) {
      return Text(widget.text, style: widget.style);
    }

    // 正規表现の作成
    final pattern = termNames.map((name) => RegExp.escape(name)).join('|');
    final regex = RegExp('($pattern)');

    final matches = regex.allMatches(widget.text);
    if (matches.isEmpty) {
      return Text(widget.text, style: widget.style);
    }

    // 古いレコグナイザーをクリアして再生成
    _clearRecognizers();

    final List<InlineSpan> spans = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: widget.text.substring(start, match.start)));
      }
      final matchText = match.group(0)!;

      // 対応する用語を検索
      final term = baseTerms.firstWhere(
        (t) => t.name == matchText || t.aliases.contains(matchText),
      );

      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TermDetailScreen(term: term)),
          );
        };
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: matchText,
          style: highlightStyle,
          recognizer: recognizer,
        ),
      );
      start = match.end;
    }

    if (start < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(start)));
    }

    return RichText(
      text: TextSpan(style: widget.style, children: spans),
    );
  }
}
