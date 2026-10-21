import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/client.dart';
import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/readable.dart';
import 'common/parts.dart';
import 'pro_screen.dart';

/// 設定（サイトの /takken/settings）: 試験日・呼び名・進め方・アカウント・学習データ。
/// App Store の決まり（3.1.1）で、アプリの外での買い方や料金には触れない。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// 進め方（サイトの ChapterOutline.svelte の PACES と同じ言葉）
const _paces = [('drill', 'じっくり演習', '論点の○×を全部解いてから次へ'), ('standard', 'ふつう', '1論点2問くらい'), ('fast', 'テンポよく', '1論点1問で先へ')];

class _SettingsScreenState extends State<SettingsScreen> {
  /// GET settings（examDate / examDateNote / nickname / hasData）
  Map<String, dynamic>? _data;
  Object? _error;
  final _nickname = TextEditingController();
  String _pace = 'standard';
  bool _busy = false;
  bool _visible = false;

  /// GET settings は進め方を返さない（いまは章の会話の画面だけが持つ）ので、この端末で最後に選んだものを覚えておく
  static const _prefPace = 'ps_pace';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // タブを開くたびに取り直す（ホームの「試験日を変える」から来たときなど）
    final visible = Visibility.of(context);
    if (visible && !_visible && _data != null) _load();
    _visible = visible;
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await AppScope.read(context).api.settings();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _nickname.text = d['nickname'] as String? ?? '';
        _pace = d['pace'] as String? ?? prefs.getString(_prefPace) ?? 'standard';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// 渡したものだけ変える。保存できたらホームの残り日数なども取り直す
  Future<bool> _patch(Map<String, Object?> changes, {String ok = '保存しました', String ng = '保存できませんでした。'}) async {
    final state = AppScope.read(context);
    try {
      await state.api.patchSettings(changes);
      _toast(ok);
      state.refresh();
      return true;
    } catch (e) {
      _toast(e is ApiException && (e.message ?? '').isNotEmpty ? e.message! : ng);
      return false;
    }
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_data?['examDate'] as String? ?? '');
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Palette.paper,
      builder: (_) => _DateSheet(initial: current ?? _defaultExamDay()),
    );
    if (picked == null || !mounted) return;
    final v = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (await _patch({'examDate': v}, ng: '保存できませんでした。日付を確かめてください。')) {
      setState(() => _data = {...?_data, 'examDate': v});
    }
  }

  /// 試験日が未設定のときに開く日（今年か来年の10月の第3日曜日）
  static DateTime _defaultExamDay() {
    final now = DateTime.now();
    DateTime third(int y) {
      final first = DateTime(y, 10, 1);
      return first.add(Duration(days: (7 - first.weekday) % 7 + 14));
    }

    final d = third(now.year);
    return d.isBefore(now) ? third(now.year + 1) : d;
  }

  Future<void> _setPace(String key) async {
    final before = _pace;
    setState(() => _pace = key);
    if (await _patch({'pace': key})) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPace, key);
    } else if (mounted) {
      setState(() => _pace = before);
    }
  }

  Future<void> _saveNickname() async {
    FocusScope.of(context).unfocus();
    final v = _nickname.text.trim();
    await _patch({'nickname': v.isEmpty ? null : v});
  }

  Future<void> _wipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('学習データを削除しますか', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text('会話・進捗・試験日をすべて削除します。元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Palette.danger),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final state = AppScope.read(context);
    setState(() => _busy = true);
    try {
      await state.api.deleteMe();
      await state.afterAccountChange();
      await _load();
      _toast('学習データを削除しました');
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: d == null
          ? Center(
              child: _error != null ? LoadError(error: _error!, onRetry: _load) : const CircularProgressIndicator(),
            )
          : AbsorbPointer(absorbing: _busy, child: _body(d)),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final state = AppScope.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final examDate = d['examDate'] as String?;
    final pace = _paces.firstWhere((p) => p.$1 == _pace, orElse: () => _paces[1]);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Heading('試験日'),
              Card(
                child: ListTile(
                  minTileHeight: 52,
                  leading: const Icon(Icons.event_outlined, color: Palette.primary),
                  title: Text(examDate ?? '未設定', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  trailing: const Text(
                    '変える',
                    style: TextStyle(color: Palette.primary, fontWeight: FontWeight.w600),
                  ),
                  onTap: _pickDate,
                ),
              ),
              if ((d['examDateNote'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(d['examDateNote'] as String, style: small),
                ),

              const _Heading('呼び名（任意・20字まで）'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nickname,
                      maxLength: 20,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveNickname(),
                      decoration: InputDecoration(
                        hintText: '先生に呼んでほしい名前',
                        filled: true,
                        fillColor: Palette.paper,
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Palette.lineStrong),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    child: FilledButton(onPressed: _saveNickname, child: const Text('保存する')),
                  ),
                ],
              ),

              const _Heading('進め方'),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [for (final p in _paces) ButtonSegment(value: p.$1, label: Text(p.$2, maxLines: 1, softWrap: false))],
                selected: {pace.$1},
                onSelectionChanged: (s) => _setPace(s.first),
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  selectedBackgroundColor: Palette.primarySoft,
                  selectedForegroundColor: Palette.primaryStrong,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text('${pace.$3}。章の会話の中でも変えられます。', style: small),
              ),

              const _Heading('Pro'),
              Card(
                child: ListTile(
                  minTileHeight: 52,
                  leading: const Icon(Icons.workspace_premium_outlined, color: Palette.primary),
                  title: Text(state.me?['pro'] == true ? 'Pro（1日${state.me?['proCap'] ?? ''}回まで）' : '広告をなくす・AI と話せる回数を増やす',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ProScreen.show(context, reason: 'settings'),
                ),
              ),

              const _Heading('学習データ'),
              if (d['hasData'] == true)
                OutlinedButton(
                  onPressed: _wipe,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.danger,
                    side: const BorderSide(color: Palette.danger, width: 1.5),
                  ),
                  child: const Text('学習データを削除する'),
                )
              else
                Text('まだ学習データはありません。', style: small),

              const _Heading('AI について'),
              const Text(
                '先生役は Anthropic 社の AI（Claude）です。あなたが入力した文章は、返答を作るために Anthropic の API に送られます。○×問題と図解は AI が作ったものではなく、あらかじめ用意して確かめた教材です。AI の説明に誤りがある可能性もあるので、大事なところはテキストでも確かめてください。',
                style: TextStyle(fontSize: 14, height: 1.7, color: Palette.ink),
              ),

              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    _LinkTile('プライバシーポリシー', AppConfig.privacyPolicyUrl),
                    const Divider(height: 1),
                    _LinkTile('利用規約', AppConfig.termsUrl),
                    const Divider(height: 1),
                    _LinkTile('サポート', AppConfig.supportUrl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink),
    ),
  );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile(this.label, this.url);
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 48,
    title: Text(label, style: const TextStyle(fontSize: 15)),
    trailing: const Icon(Icons.open_in_new, size: 18, color: Palette.inkFaint),
    onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
  );
}

/// 年・月・日を回して選ぶ（MaterialApp に日本語の localizations が無いので、日付の部品は自前で日本語にする）
class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.initial});
  final DateTime initial;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late final List<int> _years;
  late int _y = widget.initial.year;
  late int _m = widget.initial.month;
  late int _d = widget.initial.day;
  late final FixedExtentScrollController _yearCtl;
  late final _monthCtl = FixedExtentScrollController(initialItem: _m - 1);
  late final _dayCtl = FixedExtentScrollController(initialItem: _d - 1);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().year;
    _years = [for (var y = now; y <= now + 3; y++) y];
    if (!_years.contains(_y)) _years.insert(_y < now ? 0 : _years.length, _y);
    _yearCtl = FixedExtentScrollController(initialItem: _years.indexOf(_y));
  }

  @override
  void dispose() {
    _yearCtl.dispose();
    _monthCtl.dispose();
    _dayCtl.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateTime(_y, _m + 1, 0).day;

  void _clampDay() {
    if (_d > _daysInMonth) {
      _d = _daysInMonth;
      _dayCtl.jumpToItem(_d - 1);
    }
  }

  Widget _wheel({required int count, required FixedExtentScrollController controller, required String Function(int) label, required ValueChanged<int> onChanged}) => Expanded(
    child: CupertinoPicker(
      itemExtent: 40,
      scrollController: controller,
      onSelectedItemChanged: onChanged,
      children: [
        for (var i = 0; i < count; i++)
          Center(
            child: Text(label(i), style: const TextStyle(fontSize: 20, color: Palette.ink)),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final picked = DateTime(_y, _m, _d);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('試験日（$_y年$_m月$_d日（${weekdays[picked.weekday - 1]}））', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  _wheel(
                    count: _years.length,
                    controller: _yearCtl,
                    label: (i) => '${_years[i]}年',
                    onChanged: (i) => setState(() {
                      _y = _years[i];
                      _clampDay();
                    }),
                  ),
                  _wheel(
                    count: 12,
                    controller: _monthCtl,
                    label: (i) => '${i + 1}月',
                    onChanged: (i) => setState(() {
                      _m = i + 1;
                      _clampDay();
                    }),
                  ),
                  _wheel(count: _daysInMonth, controller: _dayCtl, label: (i) => '${i + 1}日', onChanged: (i) => setState(() => _d = i + 1)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.pop(context, picked), child: const Text('この日にする')),
          ],
        ),
      ),
    );
  }
}
