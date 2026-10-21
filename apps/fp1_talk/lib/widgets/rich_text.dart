import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/core.dart';
import '../theme.dart';

/// 先生の本文の飾り（サイトの src/lib/richtext.ts と同じ決まり）。
/// **太字** と ==マーカー== だけを扱う。AI は印を全角（＊＊ / ＝＝）で書くこともある。用語は最初の1回だけ押せるようにする。
class RichBody extends StatelessWidget {
  const RichBody(this.text, {super.key, this.glossary = const [], this.style});
  final String text;
  final List<Term> glossary;
  final TextStyle? style;

  static final _token = RegExp(r'((?:\*\*|＊＊)[^*＊\n]+?(?:\*\*|＊＊)|(?:==|＝＝)[^=＝\n]+?(?:==|＝＝))');

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    return Text.rich(TextSpan(style: base, children: spans(context, text, glossary, base)));
  }

  static List<InlineSpan> spans(BuildContext context, String text, List<Term> glossary, TextStyle base) {
    final lookup = <String, Term>{};
    for (final t in glossary) {
      for (final n in [t.name, ...t.aliases]) {
        if (n.length >= 2) lookup[n] = t;
      }
    }
    final names = lookup.keys.toList()..sort((a, b) => b.length - a.length);
    final termRe = names.isEmpty ? null : RegExp(names.map(RegExp.escape).join('|'));
    final seen = <String>{};
    final out = <InlineSpan>[];

    void plain(String s) {
      if (termRe == null) {
        out.add(TextSpan(text: s));
        return;
      }
      var i = 0;
      for (final m in termRe.allMatches(s)) {
        final term = lookup[m.group(0)!]!;
        if (seen.contains(term.name)) continue;
        seen.add(term.name);
        if (m.start > i) out.add(TextSpan(text: s.substring(i, m.start)));
        out.add(TextSpan(
          text: m.group(0),
          style: const TextStyle(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted, decorationColor: Palette.primary),
          recognizer: TapGestureRecognizer()..onTap = () => showTerm(context, term),
        ));
        i = m.end;
      }
      if (i < s.length) out.add(TextSpan(text: s.substring(i)));
    }

    var last = 0;
    for (final m in _token.allMatches(text)) {
      if (m.start > last) plain(text.substring(last, m.start));
      final s = m.group(0)!;
      final inner = s.substring(2, s.length - 2);
      if (s.startsWith('*') || s.startsWith('＊')) {
        out.add(TextSpan(text: inner, style: const TextStyle(fontWeight: FontWeight.w700)));
      } else {
        out.add(TextSpan(text: inner, style: const TextStyle(fontWeight: FontWeight.w700, backgroundColor: Palette.highlightSoft)));
      }
      last = m.end;
    }
    if (last < text.length) plain(text.substring(last));
    return out;
  }
}

/// 用語の意味（下から出す）
Future<void> showTerm(BuildContext context, Term term) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Palette.paper,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(term.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
              const SizedBox(height: 8),
              Text(term.short, style: const TextStyle(fontSize: 16, height: 1.7, color: Palette.ink)),
              if (term.detail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(term.detail, style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.inkSoft)),
              ],
            ],
          ),
        ),
      ),
    );
