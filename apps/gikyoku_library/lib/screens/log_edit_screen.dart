import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../catalog/models.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';

class LogEditScreen extends StatefulWidget {
  const LogEditScreen({super.key, this.entry, this.play});
  final TheaterLogEntry? entry;
  final Play? play;

  static Future<void> open(BuildContext context, {TheaterLogEntry? entry, Play? play}) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LogEditScreen(entry: entry, play: play), fullscreenDialog: true, settings: const RouteSettings(name: 'log_edit')),
  );

  @override
  State<LogEditScreen> createState() => _LogEditScreenState();
}

class _LogEditScreenState extends State<LogEditScreen> {
  late final _group = TextEditingController(text: widget.entry?.group);
  late final _venue = TextEditingController(text: widget.entry?.venue);
  late final _note = TextEditingController(text: widget.entry?.note);
  late DateTime _date = widget.entry?.watchedOn ?? DateUtils.dateOnly(DateTime.now());
  late int? _rating = widget.entry?.rating;
  late Play? _play = widget.play;
  TextEditingController? _title;

  @override
  void dispose() {
    _group.dispose();
    _venue.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(1970), lastDate: DateTime(now.year + 1, 12, 31), locale: const Locale('ja'));
    if (picked != null) setState(() => _date = picked);
  }

  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final title = _title?.text.trim() ?? '';
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('作品名を入れてください')));
      return;
    }
    // 作品名を書き換えたら、前に選んだ作品とのつながりは外す
    final play = _play?.title == title ? _play : null;
    final old = widget.entry;
    final linkedId = play?.id ?? (old?.title == title ? old?.playId : null);
    await AppScope.of(context).log.upsert(
      TheaterLogEntry(
        id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        watchedOn: _date,
        playId: linkedId,
        author: play?.author ?? (old?.title == title ? old?.author : null),
        group: _text(_group),
        venue: _text(_venue),
        rating: _rating,
        note: _note.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final log = AppScope.of(context).log;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この記録を削除しますか'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
        ],
      ),
    );
    if (yes == true) {
      await log.remove(widget.entry!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plays = AppScope.of(context).catalog.plays;
    const border = OutlineInputBorder();
    final initialTitle = widget.entry?.title ?? widget.play?.title ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? '観劇を記録' : '記録を編集'),
        actions: [TextButton(key: const Key('log-save'), onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Autocomplete<Play>(
            initialValue: TextEditingValue(text: initialTitle),
            displayStringForOption: (p) => p.title,
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<Play>.empty();
              return plays.where((p) => p.title.toLowerCase().contains(q) || p.author.toLowerCase().contains(q)).take(8);
            },
            onSelected: (p) => setState(() => _play = p),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 3,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280, maxWidth: 340),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final p in options) ListTile(dense: true, title: Text(p.title), subtitle: Text(p.author), onTap: () => onSelected(p)),
                    ],
                  ),
                ),
              ),
            ),
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              _title = controller;
              return TextField(
                key: const Key('log-title'),
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(labelText: '作品名（必須）', helperText: '戯曲図書館の作品を選ぶと、台本につながります', border: border),
              );
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            key: const Key('log-date'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text('${_date.year}年${_date.month}月${_date.day}日に観た'),
            trailing: const Text('変更', style: TextStyle(color: Palette.navy)),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          TextField(controller: _group, decoration: const InputDecoration(labelText: '劇団・団体', border: border)),
          // 同じ作品を別の劇団が上演することがあるので、自動では入れない
          if (_play != null && _play!.groups.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('この作品を上演した劇団（押すと入ります）', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
            Wrap(
              spacing: 6,
              children: [
                for (final g in _play!.groups.take(8))
                  ActionChip(
                    key: Key('group-chip-$g'),
                    label: Text(g),
                    onPressed: () => setState(() => _group.text = g),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(controller: _venue, decoration: const InputDecoration(labelText: '劇場', border: border)),
          const SizedBox(height: 16),
          const Text('評価', style: TextStyle(fontSize: 13, color: Palette.inkSoft)),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: Key('star-$i'),
                  tooltip: '$i',
                  onPressed: () => setState(() => _rating = _rating == i ? null : i),
                  icon: Icon((_rating ?? 0) >= i ? Icons.star : Icons.star_border, color: Palette.vermilion),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('log-note'),
            controller: _note,
            maxLines: 6,
            minLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'ひとこと・感想', alignLabelWithHint: true, border: border),
          ),
          const Text('この試作では、記録は端末の中だけに保存されます。', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
          if (widget.entry != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: _delete, child: const Text('この記録を削除', style: TextStyle(color: Palette.vermilion))),
          ],
        ],
      ),
    );
  }
}
