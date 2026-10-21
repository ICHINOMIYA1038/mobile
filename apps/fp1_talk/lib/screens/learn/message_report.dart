import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';

/// 「この返答を報告」（サイトの ReportButton.svelte と同じ理由）。運営者が会話ビューアで読む。
/// 送れたら true を返す（画面はその返答の報告の欄を「報告しました」に変える）
Future<bool> showMessageReport(BuildContext context, {required String messageId}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Palette.paper,
      builder: (_) => _MessageReportSheet(messageId: messageId),
    ) ==
    true;

const _reasons = [
  ('wrong', '内容・数字がおかしい'),
  ('confusing', '分かりにくい'),
  ('off_topic', '話がそれた・飛んだ'),
  ('no_choice', '答え方が分からない質問'),
  ('other', 'その他'),
];

class _MessageReportSheet extends StatefulWidget {
  const _MessageReportSheet({required this.messageId});
  final String messageId;

  @override
  State<_MessageReportSheet> createState() => _MessageReportSheetState();
}

class _MessageReportSheetState extends State<_MessageReportSheet> {
  String _kind = 'wrong';
  final _note = TextEditingController();
  bool _sending = false;
  bool _failed = false;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      final note = _note.text.trim();
      await AppScope.read(context).api.reportMessage(messageId: widget.messageId, kind: _kind, note: note.isEmpty ? null : note);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('報告しました。ありがとうございます。')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _failed = true;
        });
      }
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
            const Text('この返答を報告', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (kind, label) in _reasons)
                  ChoiceChip(
                    label: Text(label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                    selectedColor: Palette.primarySoft,
                    labelStyle: TextStyle(color: _kind == kind ? Palette.primary : Palette.inkSoft, fontWeight: _kind == kind ? FontWeight.w700 : FontWeight.w400),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'どこがおかしいか一言（任意）', border: OutlineInputBorder()),
            ),
            if (_failed) const Padding(padding: EdgeInsets.only(top: 4), child: Text('送れませんでした', style: TextStyle(color: Palette.danger))),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(onPressed: _sending ? null : _send, child: const Text('報告する')),
                const SizedBox(width: 12),
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('やめる')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
