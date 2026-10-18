import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// 「この問題を報告」（サイトの QuestionReport.svelte と同じ種類）。報告はサイトの管理画面 /admin/questions に集まる。
/// shownOn: kakomon / learn / review / other
Future<void> showQuestionReport(BuildContext context, {required String questionId, bool? myAnswer, required String shownOn}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Palette.paper,
      builder: (_) => _ReportSheet(questionId: questionId, myAnswer: myAnswer, shownOn: shownOn),
    );

const _kinds = {
  'answer': ('答え（○×）がおかしい', 'なぜそう思いましたか？（例: 〇条では…）'),
  'explain': ('解説が分かりにくい・足りない', 'どこが分かりにくいですか？'),
  'text': ('問題文がおかしい・誤字', 'どこがおかしいですか？（例: 前提が足りない、読み方が2通りある）'),
  'other': ('その他', '気になったことを書いてください'),
};

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.questionId, required this.myAnswer, required this.shownOn});
  final String questionId;
  final bool? myAnswer;
  final String shownOn;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _kind;
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  bool get _ready => _kind != null && (_kind != 'other' || _note.text.trim().isNotEmpty);

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AppScope.read(context).api.reportQuestion(
            questionId: widget.questionId,
            kind: _kind!,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            myAnswer: widget.myAnswer,
            shownOn: widget.shownOn,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('報告ありがとうございます。確かめて直します。')));
    } catch (_) {
      setState(() {
        _sending = false;
        _error = '送れませんでした。もう一度お試しください';
      });
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('この問題の何がおかしいですか？', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _kinds.entries)
                  ChoiceChip(
                    label: Text(e.value.$1),
                    selected: _kind == e.key,
                    onSelected: (_) => setState(() => _kind = e.key),
                    selectedColor: Palette.primarySoft,
                    labelStyle: TextStyle(color: _kind == e.key ? Palette.primary : Palette.inkSoft, fontWeight: _kind == e.key ? FontWeight.w700 : FontWeight.w400),
                  ),
              ],
            ),
            if (_kind != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 1000,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '${_kinds[_kind]!.$2}${_kind == 'other' ? '' : '（任意）'}',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, style: const TextStyle(color: Palette.danger))),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(onPressed: _ready && !_sending ? _send : null, child: const Text('送る')),
                const SizedBox(width: 12),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('やめる')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
