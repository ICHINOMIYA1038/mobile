import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../account/community_api.dart';
import '../app_scope.dart';
import '../catalog/log_photos.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';
import '../widgets/community_widgets.dart';
import 'account_screen.dart';
import 'venue_stamps_screen.dart';

class LogEditScreen extends StatefulWidget {
  const LogEditScreen({super.key, this.entry, this.play, this.draft, this.productionLabel});
  final TheaterLogEntry? entry;
  final Play? play;

  /// 入力の途中から続けるときの下書き。まだ保存されていない
  final TheaterLogEntry? draft;
  final String? productionLabel;

  static Future<void> open(BuildContext context, {TheaterLogEntry? entry, Play? play, TheaterLogEntry? draft, String? productionLabel}) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LogEditScreen(entry: entry, play: play, draft: draft, productionLabel: productionLabel), fullscreenDialog: true, settings: const RouteSettings(name: 'log_edit')),
  );

  @override
  State<LogEditScreen> createState() => _LogEditScreenState();
}

class _LogEditScreenState extends State<LogEditScreen> {
  TheaterLogEntry? get _seed => widget.entry ?? widget.draft;
  late final _group = TextEditingController(text: _seed?.group);
  late final _venue = TextEditingController(text: _seed?.venue);
  late final _note = TextEditingController(text: _seed?.note);
  late DateTime _date = _seed?.watchedOn ?? DateUtils.dateOnly(DateTime.now());
  late int? _rating = _seed?.rating;
  late Play? _play = widget.play;
  late final _seat = TextEditingController(text: _seed?.seat);
  late final _price = TextEditingController(text: _seed?.price?.toString());
  late String? _showTime = _seed?.showTime;
  late bool _public = widget.entry?.visibility == 'public';
  late int? _productionId = _seed?.productionId;
  late String? _productionLabel = widget.productionLabel;
  late final List<String> _photos = [...?widget.entry?.photos];
  // 保存せずに閉じたら消す写真
  final List<String> _added = [];
  bool _saved = false;
  TextEditingController? _title;

  @override
  void dispose() {
    _group.dispose();
    _venue.dispose();
    _note.dispose();
    _seat.dispose();
    _price.dispose();
    if (!_saved) {
      for (final name in _added) {
        LogPhotos.delete(name);
      }
    }
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
        showTime: _showTime,
        seat: _text(_seat),
        price: int.tryParse(_price.text.replaceAll(RegExp(r'[,，円\s]'), '')),
        photos: _photos,
        productionId: _productionId,
        visibility: _public ? 'public' : 'private',
        hidden: old?.hidden ?? false,
      ),
    );
    _saved = true;
    for (final name in _removed) {
      await LogPhotos.delete(name);
    }
    if (mounted) Navigator.of(context).pop();
  }

  final List<String> _removed = [];

  bool _adding = false;

  /// 残りの枚数まで、まとめて選べる
  Future<void> _addPhotos() async {
    final room = LogPhotos.maxPerEntry - _photos.length;
    if (room <= 0 || _adding) return;
    setState(() => _adding = true);
    try {
      final picked = room == 1
          ? [?await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85)]
          : await ImagePicker().pickMultiImage(maxWidth: 2000, imageQuality: 85, limit: room);
      final names = <String>[];
      for (final x in picked.take(room)) {
        names.add(await LogPhotos.save(File(x.path)));
      }
      if (!mounted) {
        for (final n in names) {
          LogPhotos.delete(n);
        }
        return;
      }
      setState(() {
        _photos.addAll(names);
        _added.addAll(names);
      });
      if (picked.length > room && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('写真は 1 つの記録に ${LogPhotos.maxPerEntry} 枚までです。先の $room 枚を入れました')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('写真を読み込めませんでした。写真へのアクセスを許可しているか確かめてください')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _removePhoto(String name) => setState(() {
    _photos.remove(name);
    // 今回足した写真はすぐ消す。保存済みの写真は、保存を押すまで残す
    if (_added.remove(name)) {
      LogPhotos.delete(name);
    } else {
      _removed.add(name);
    }
  });

  /// 押した写真を 1 枚目（半券帳の表紙）にする
  void _makeCover(String name) => setState(() {
    _photos
      ..remove(name)
      ..insert(0, name);
  });

  Future<void> _togglePublic(bool on) async {
    if (!on) return setState(() => _public = false);
    final scope = AppScope.of(context);
    if (!scope.auth.signedIn) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('公開にはログインが必要です'),
          content: const Text('感想を公開するにはログインしてください。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ログイン')),
          ],
        ),
      );
      if (go != true || !mounted) return;
      await AccountScreen.open(context);
      if (!mounted || !scope.auth.signedIn) return;
    }
    if (scope.auth.user?.banned == true) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('運営の判断により、感想の公開を止めています。記録は引き続き使えます')));
      return;
    }
    if (await CommunityRules.confirm(context) && mounted) setState(() => _public = true);
  }

  Future<void> _pickProduction() async {
    final picked = await showModalBottomSheet<Production>(
      context: context,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: 'production_pick'),
      builder: (_) => ProductionPicker(initialQuery: _play?.title ?? _title?.text ?? '', postId: _play?.id),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _productionId = picked.id;
      _productionLabel = picked.label;
      if (_title != null && _title!.text.trim().isEmpty) _title!.text = picked.title;
      if (picked.groupName != null) _group.text = picked.groupName!;
      if (picked.venueName != null) _venue.text = picked.venueName!;
    });
  }

  Future<void> _delete() async {
    final log = AppScope.of(context).log;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この記録を削除しますか'),
        content: Text(widget.entry!.photos.isEmpty ? '元に戻せません。' : '写真 ${widget.entry!.photos.length} 枚も一緒に消え、元に戻せません。'),
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
    final initialTitle = _seed?.title ?? widget.play?.title ?? '';
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
          if (AppScope.of(context).auth.signedIn)
            ListTile(
              key: const Key('log-production'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.confirmation_number_outlined),
              title: Text(_productionLabel ?? (_productionId == null ? '公演を選ぶ、または登録する' : '公演を選択済み')),
              subtitle: const Text('同じ公演を観た人の感想とつながります', style: TextStyle(fontSize: 12)),
              trailing: _productionId == null ? const Icon(Icons.chevron_right) : IconButton(tooltip: '公演を外す', icon: const Icon(Icons.close), onPressed: () => setState(() { _productionId = null; _productionLabel = null; })),
              onTap: _pickProduction,
            ),
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
          if (_play == null || _play!.groups.isEmpty) _Suggestions(values: AppScope.of(context).log.recent((e) => e.group), onPick: (v) => setState(() => _group.text = v)),
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
          TextField(
            key: const Key('log-venue'),
            controller: _venue,
            decoration: InputDecoration(
              labelText: '劇場',
              border: border,
              suffixIcon: IconButton(
                key: const Key('log-venue-pick'),
                tooltip: '劇場を探す',
                icon: const Icon(Icons.place_outlined),
                onPressed: () async {
                  final v = await VenuePickerSheet.open(context);
                  if (v != null && mounted) setState(() => _venue.text = v.name);
                },
              ),
            ),
          ),
          _Suggestions(values: AppScope.of(context).log.recent((e) => e.venue), onPick: (v) => setState(() => _venue.text = v)),
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
          SwitchListTile(
            key: const Key('log-public'),
            contentPadding: EdgeInsets.zero,
            title: const Text('感想をみんなに公開する'),
            subtitle: Text(_public ? 'アプリと戯曲図書館のサイトに、感想、評価、劇団、劇場、観た月、公開の名前が出ます。写真、座席、チケット代は出ません。' : '自分だけが見られます。', style: const TextStyle(fontSize: 12)),
            value: _public,
            onChanged: _togglePublic,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            key: const Key('log-details'),
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: _showTime != null || _seat.text.isNotEmpty || _price.text.isNotEmpty || _photos.isNotEmpty,
            title: const Text('写真・座席・チケット代（任意）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: const [ButtonSegment(value: 'matinee', label: Text('昼公演')), ButtonSegment(value: 'soiree', label: Text('夜公演'))],
                  selected: {?_showTime},
                  onSelectionChanged: (v) => setState(() => _showTime = v.isEmpty ? null : v.first),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _seat, decoration: const InputDecoration(labelText: '座席（例: C列12番）', border: border)),
              const SizedBox(height: 12),
              TextField(key: const Key('log-price'), controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'チケット代（円）', border: border)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _photos.length < 2 ? '写真（${LogPhotos.maxPerEntry} 枚まで）' : '写真 ${_photos.length} / ${LogPhotos.maxPerEntry} 枚　押すと表紙にできます',
                  style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, name) in _photos.indexed)
                    SizedBox(
                      key: Key('edit-photo-$i'),
                      width: 84,
                      height: 84,
                      child: Stack(
                        children: [
                          // 写真が読めなくても（消えていても）押せるようにする
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: i == 0 ? null : () => _makeCover(name),
                            child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LogPhotoImage(name: name, size: 84)),
                          ),
                          if (i == 0 && _photos.length > 1)
                            Positioned(
                              left: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(3)),
                                child: const Text('表紙', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                            ),
                          // 指で押しやすいよう、見た目より広く取る
                          Positioned(
                            right: -6,
                            top: -6,
                            child: IconButton(
                              key: Key('edit-photo-remove-$i'),
                              tooltip: '写真を外す',
                              onPressed: () => _removePhoto(name),
                              icon: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_photos.length < LogPhotos.maxPerEntry)
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: OutlinedButton(
                        key: const Key('edit-photo-add'),
                        onPressed: _adding ? null : _addPhotos,
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                        child: _adding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
          if (widget.entry != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: _delete, child: const Text('この記録を削除', style: TextStyle(color: Palette.vermilion))),
          ],
        ],
      ),
    );
  }
}

/// 自分が前に入れた値を、押すだけで入れられるようにする
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.values, required this.onPick});
  final List<String> values;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        children: [for (final v in values.take(5)) ActionChip(label: Text(v), onPressed: () => onPick(v))],
      ),
    );
  }
}
