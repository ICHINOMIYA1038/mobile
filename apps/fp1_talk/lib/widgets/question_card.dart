import 'package:flutter/material.dart';

import '../models/core.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'report_sheet.dart';
import 'rich_text.dart';

/// ○×問題の用紙（サイトの QuestionCard.svelte と同じ形）。白い紙に罫線1本、答えたら赤ペンで丸かバツ。
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    this.graded,
    this.onAnswer,
    this.disabled = false,
    this.showBookmark = true,
    this.showOrigin = true,
    this.shownOn = 'other',
    this.glossary = const [],
  });

  final PublicQuestion question;
  final Graded? graded;
  final ValueChanged<bool>? onAnswer;
  final bool disabled;
  final bool showBookmark;

  /// 過去問の出典の行（過去問の画面は上に別に出すので false）
  final bool showOrigin;

  /// 報告に付ける出どころ（kakomon / learn / review / other）
  final String shownOn;
  final List<Term> glossary;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = graded;
    final bookmarked = state.bookmarks.contains(question.id);
    return Container(
      decoration: BoxDecoration(color: Palette.paper, border: Border.all(color: Palette.lineStrong), borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.line))),
            child: Row(
              children: [
                Expanded(child: Text(question.topic, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.primary))),
                Text('難易度 ${'★' * question.difficulty}', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                if (showBookmark) ...[
                  const SizedBox(width: 8),
                  _BookmarkButton(on: bookmarked, onTap: () => state.toggleBookmark(question.id, !bookmarked)),
                ],
              ],
            ),
          ),
          if (showOrigin && question.origin != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text.rich(
                TextSpan(children: [
                  const WidgetSpan(alignment: PlaceholderAlignment.middle, child: _Tag('過去問')),
                  TextSpan(text: ' ${question.origin}'),
                  const TextSpan(text: ' の論点（文は作り直し）', style: TextStyle(color: Palette.inkFaint)),
                ]),
                style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
              ),
            ),
          const SizedBox(height: 8),
          Text(question.statement, style: const TextStyle(fontSize: 16, height: 1.75, color: Palette.ink)),
          const SizedBox(height: 12),
          if (g == null)
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: disabled ? null : () => onAnswer?.call(true), child: const Text('○ 正しい'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: disabled ? null : () => onAnswer?.call(false), child: const Text('× 誤り'))),
              ],
            )
          else
            _Result(graded: g, glossary: glossary),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showQuestionReport(context, questionId: question.id, myAnswer: g?.answer, shownOn: shownOn),
              style: TextButton.styleFrom(foregroundColor: Palette.inkFaint, textStyle: const TextStyle(fontSize: 13, decoration: TextDecoration.underline)),
              child: const Text('この問題を報告'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.graded, required this.glossary});
  final Graded graded;
  final List<Term> glossary;

  @override
  Widget build(BuildContext context) {
    final ok = graded.correct;
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.lineStrong, style: BorderStyle.solid))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(ok ? '○' : '×', textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, height: 1, color: Palette.hanamaru)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: ok ? '正解' : '不正解', style: TextStyle(fontWeight: FontWeight.w700, color: ok ? Palette.success : Palette.danger)),
                  TextSpan(text: '　あなたの答え ${graded.answer ? '○' : '×'}', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                ])),
                if (graded.explanation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RichBody(graded.explanation, glossary: glossary, style: const TextStyle(fontSize: 14, height: 1.75, color: Palette.ink)),
                ],
                if (graded.reference.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('根拠: ${graded.reference}', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        toggled: on,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: on ? Palette.warningSoft : Palette.paper,
              border: Border.all(color: on ? Palette.warning : Palette.lineStrong),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(on ? '★ 復習に入れた' : '☆ あとで復習', style: TextStyle(fontSize: 13, color: on ? Palette.warning : Palette.inkSoft)),
          ),
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(color: Palette.primarySoft, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.primaryStrong)),
      );
}
