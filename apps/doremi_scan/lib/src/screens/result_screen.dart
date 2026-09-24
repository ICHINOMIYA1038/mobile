import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../engine/doremi_engine.dart';
import '../models/score.dart';
import '../services/pdf_export.dart';
import '../services/precheck.dart';
import '../services/score_store.dart';
import '../theme/app_theme.dart';
import '../widgets/panels_view.dart';
import '../widgets/score_view.dart';

/// 認識結果画面。複数枚の画像をまとめて認識・結合し、
/// 誤った音はタップで修正できる。認識結果は自動でローカル保存され、
/// ホームの「最近の楽譜」からいつでも開き直せる。
class ResultScreen extends StatefulWidget {
  final DoremiEngine engine;
  final List<String> imagePaths;

  /// 保存済み楽譜を開くとき（再認識せずローカルから読む）。
  final String? savedId;
  ResultScreen(
      {super.key,
      required this.engine,
      List<String>? imagePaths,
      String? imagePath,
      this.savedId})
      : imagePaths = imagePaths ?? [?imagePath];

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  RecognizedScore? _score; // 1枚のときの元画像重ね表示用
  List<DoremiNote>? _notes; // 表示・編集用（複数枚は結合済み）
  final List<ScorePanel> _panels = []; // 段画像＋正確な位置（あれば最優先の表示）
  String? _error;
  String _hint = '';
  final List<String> _warnings = []; // サーバーからの注意（読めない五線など）
  bool _showClean = true; // 清書があるときの表示モード（false=原本＋修正）
  bool _cleanStaleNotified = false; // 「修正で清書が原本に戻る」告知は1回だけ
  int _done = 0;
  RecognizeProgress _progress =
      const RecognizeProgress(RecognizePhase.preparing, 0);

  bool get _multi => widget.imagePaths.length > 1;

  String? _savedId; // 自動保存された楽譜のID（修正の追い保存に使う）

  @override
  void initState() {
    super.initState();
    if (widget.savedId != null) {
      _loadSaved(widget.savedId!);
    } else {
      _run();
    }
  }

  /// 保存済み楽譜を開く（再認識しない）。
  Future<void> _loadSaved(String id) async {
    try {
      final (panels, warnings) = await ScoreStore.load(id);
      if (!mounted) return;
      setState(() {
        _savedId = id;
        _panels.addAll(panels);
        _warnings.addAll(warnings);
        _notes = [];
        _done = 0;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'この楽譜を開けませんでした。削除して撮り直してください。');
      }
    }
  }

  /// 認識結果の自動保存と、修正のたびの追い保存。
  Future<void> _persist() async {
    try {
      if (_savedId == null) {
        _savedId = await ScoreStore.save(_panels, _warnings);
      } else {
        await ScoreStore.update(_savedId!, _panels);
      }
    } catch (_) {
      // 保存失敗で結果表示を邪魔しない
    }
  }

  bool _prechecked = false;

  /// 30秒待つ前に、オンデバイス検出で「楽譜が小さすぎないか」を確かめる。
  /// 小さければ理由と直し方を伝え、それでも読むかをユーザーに委ねる。
  Future<bool> _precheckOk() async {
    if (_prechecked) return true;
    _prechecked = true;
    final small = await Precheck.tooSmallPages(widget.imagePaths);
    if (small.isEmpty || !mounted) return true;
    final label = widget.imagePaths.length == 1
        ? 'この画像'
        : small.map((p) => '$p枚目').join('・');
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('楽譜が小さく写っています'),
        content: Text(
            '$labelは五線が小さすぎるため、読み取れない音符が多くなりそうです。\n\n'
            'ページ全体ではなく、1〜2段だけを画面いっぱいに拡大した'
            'スクリーンショットにすると大きく改善します。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('やめて選び直す')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('このまま読み取る')),
        ],
      ),
    );
    if (go != true) {
      if (mounted) Navigator.of(context).pop();
      return false;
    }
    return true;
  }

  Future<void> _run() async {
    if (!await _precheckOk()) return;
    // リトライで結果が二重にならないよう、毎回まっさらから始める
    _panels.clear();
    _warnings.clear();
    _hint = '';
    _done = 0;
    final merged = <DoremiNote>[];
    RecognizedScore? last;
    final failedPages = <int>[];
    String? firstError;
    for (var i = 0; i < widget.imagePaths.length; i++) {
      if (mounted) setState(() => _done = i);
      try {
        final score = await widget.engine.recognize(
          widget.imagePaths[i],
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        merged.addAll(score.notes);
        _panels.addAll(score.panels);
        for (final w in score.warnings) {
          if (!_warnings.contains(w)) _warnings.add(w);
        }
        last = score;
        if (score.debug.contains('screen') && _hint.isEmpty) {
          _hint = score.debug;
        }
      } on RecognizeException catch (e) {
        failedPages.add(i + 1);
        firstError ??= e.message;
      } catch (_) {
        failedPages.add(i + 1);
      }
    }
    if (!mounted) return;
    // 一部だけ失敗したときは、成功した分を見せて失敗分だけ知らせる（全部捨てない）
    if (failedPages.isNotEmpty && _panels.isNotEmpty) {
      _warnings.add(
          '${failedPages.map((p) => '$p枚目').join('・')}は読み取れませんでした。'
          'その部分だけ撮り直して、もう一度お試しください。');
    }
    setState(() {
      if (_panels.isEmpty && merged.isEmpty) {
        _error = firstError ??
            '楽譜を読み取れませんでした。\n\nうまく読み取るコツ\n・紙の楽譜は 真上から・明るく・影なし で\n・画面の楽譜は 撮影ではなくスクリーンショット で\n・スクショは 楽譜を拡大してから（1〜2段が画面いっぱい）';
      } else {
        _notes = merged;
        _score = widget.imagePaths.length == 1 ? last : null;
        _done = widget.imagePaths.length;
      }
    });
    if (_panels.isNotEmpty) await _persist();
  }

  static const _phaseLabel = {
    RecognizePhase.preparing: '準備しています…',
    RecognizePhase.detectingStaves: '五線を探しています…',
    RecognizePhase.recognizing: '音符を読み取っています…',
    RecognizePhase.rendering: 'ドレミを付けています…',
    RecognizePhase.done: '完了',
  };

  String get _doremiText => _panels.isNotEmpty
      ? _panels
          .expand((p) => p.chords)
          .map((c) => c.rubies.length == 1
              ? c.rubies.first
              // 和音は下の音から（弾く人の読み順）
              : '（${c.rubies.reversed.join('')}）')
          .join(' ')
      : (_notes ?? const []).map((n) => n.ruby).join(' ');

  bool get _hasResult =>
      _panels.isNotEmpty || (_notes != null && _notes!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final notes = _notes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ドレミ楽譜'),
        actions: [
          if (notes != null && _hasResult)
            IconButton(
              tooltip: 'ドレミをコピー',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _doremiText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ドレミをコピーしました')),
                );
              },
            ),
        ],
      ),
      body: _error != null
          ? _ErrorBody(
              message: _error!,
              onRetry: () {
                setState(() {
                  _error = null;
                  _notes = null;
                  _progress =
                      const RecognizeProgress(RecognizePhase.preparing, 0);
                });
                _run();
              },
              onReshoot: () => Navigator.of(context).pop(),
            )
          : notes == null
              ? _Progress(
                  progress: _progress,
                  label: _phaseLabel,
                  pageInfo: _multi
                      ? '${_done + 1} / ${widget.imagePaths.length} 枚目'
                      : null,
                  onCancel: () => Navigator.of(context).pop(),
                )
              : !_hasResult
                  ? _ErrorBody(
                      message:
                          '楽譜を読み取れませんでした。\n\nうまく読み取るコツ\n・紙の楽譜は 真上から・明るく・影なし で\n・画面の楽譜は 撮影ではなくスクリーンショット で\n・スクショは 楽譜を拡大してから（1〜2段が画面いっぱい）',
                      onRetry: () {
                        setState(() {
                          _notes = null;
                          _progress = const RecognizeProgress(
                              RecognizePhase.preparing, 0);
                        });
                        _run();
                      },
                      onReshoot: () => Navigator.of(context).pop(),
                    )
                  : _buildResult(notes),
      bottomNavigationBar: (notes == null || !_hasResult)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('印刷'),
                        onPressed: _exporting ? null : _print,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                        icon: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.ios_share_rounded),
                        label: Text(_exporting ? 'PDFを作成中…' : 'PDFで共有'),
                        onPressed: _exporting ? null : _share,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildResult(List<DoremiNote> notes) {
    final score = _score;
    final anyClean = _panels.any((p) => p.hasClean);
    return Column(
      children: [
        if (anyClean)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('きれいな楽譜'),
                    icon: Icon(Icons.auto_awesome_rounded, size: 16)),
                ButtonSegment(
                    value: false,
                    label: Text('原本＋修正'),
                    icon: Icon(Icons.edit_note_rounded, size: 16)),
              ],
              selected: {_showClean},
              onSelectionChanged: (s) =>
                  setState(() => _showClean = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.brand,
                selectedForegroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        if (_hint.contains('screen_photo'))
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Text(
              '💡 画面を直接撮影したようです。スクリーンショットを使うと精度が大きく上がります。',
              style: TextStyle(fontSize: 12, color: AppColors.brandDark),
            ),
          ),
        for (final w in _warnings)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '⚠️ $w',
              style: const TextStyle(fontSize: 12, color: AppColors.brandDark),
            ),
          ),
        Expanded(
          child: _panels.isNotEmpty
              ? PanelsView(
                  panels: _panels,
                  showClean: _showClean,
                  onEdit: (pi, ci, ri, value) {
                    setState(() {
                      final chord = _panels[pi].chords[ci];
                      if (value == null) {
                        chord.rubies.removeAt(ri);
                        if (chord.rubies.isEmpty) {
                          _panels[pi].chords.removeAt(ci);
                        }
                      } else {
                        chord.rubies[ri] = value;
                      }
                      _invalidateClean(pi);
                    });
                    _persist();
                  },
                  onAdd: (pi, index, chord) {
                    setState(() {
                      _panels[pi].chords.insert(index, chord);
                      _invalidateClean(pi);
                    });
                    _persist();
                  },
                )
              : (score != null && score.overlayOnImage && !_multi)
              ? ScoreView(score: score)
              : _EditableDoremi(
                  notes: notes,
                  onChanged: (i, updated) {
                    setState(() {
                      if (updated == null) {
                        notes.removeAt(i);
                      } else {
                        notes[i] = updated;
                      }
                    });
                  },
                ),
        ),
      ],
    );
  }

  /// 清書には修正が反映できないので、修正した段は原本表示に戻す（初回のみ告知）。
  void _invalidateClean(int pi) {
    final had = _panels[pi].hasClean;
    _panels[pi].cleanBytes = null;
    if (had && !_cleanStaleNotified) {
      _cleanStaleNotified = true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('修正した段は「原本」の表示に切り替わります'),
        duration: Duration(seconds: 3),
      ));
    }
  }

  RecognizedScore _asScore() => RecognizedScore(
        sourceImagePath:
            widget.imagePaths.isNotEmpty ? widget.imagePaths.first : '',
        imageWidth: 1000,
        imageHeight: 1400,
        elapsedMs: 0,
        notes: _notes ?? const [],
        panels: _panels,
        overlayOnImage: false,
      );

  bool _exporting = false;

  Future<void> _export(Future<void> Function(Uint8List bytes) send) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await PdfExport.build(_asScore());
      await send(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('PDFを作れませんでした。通信環境を確認してもう一度お試しください。')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _print() => _export(
      (bytes) => Printing.layoutPdf(onLayout: (_) async => bytes));

  Future<void> _share() => _export((bytes) {
        final d = DateTime.now();
        final name = 'ドレミ楽譜_${d.year}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}.pdf';
        return Printing.sharePdf(bytes: bytes, filename: name);
      });
}

/// タップで修正できるドレミ表示。
class _EditableDoremi extends StatelessWidget {
  final List<DoremiNote> notes;
  final void Function(int index, DoremiNote? updated) onChanged;
  const _EditableDoremi({required this.notes, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('音をタップすると修正できます',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (var i = 0; i < notes.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _edit(context, i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    notes[i].ruby,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, int index) async {
    const steps = ['ド', 'レ', 'ミ', 'ファ', 'ソ', 'ラ', 'シ'];
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('「${notes[index].ruby}」を修正',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in steps) ...[
                    _pick(ctx, s),
                    _pick(ctx, '$s♯'),
                    _pick(ctx, '$s♭'),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => Navigator.of(ctx).pop('__delete__'),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label:
                    const Text('この音を削除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    if (result == '__delete__') {
      onChanged(index, null);
    } else {
      final n = notes[index];
      onChanged(
          index,
          DoremiNote(
              ruby: result,
              pitch: n.pitch,
              xFrac: n.xFrac,
              yFrac: n.yFrac,
              duration: n.duration));
    }
  }

  Widget _pick(BuildContext ctx, String label) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: const BorderSide(color: AppColors.line),
        foregroundColor: AppColors.ink,
      ),
      onPressed: () => Navigator.of(ctx).pop(label),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }
}

class _Progress extends StatefulWidget {
  final RecognizeProgress progress;
  final Map<RecognizePhase, String> label;
  final String? pageInfo;
  final VoidCallback? onCancel;
  const _Progress(
      {required this.progress,
      required this.label,
      this.pageInfo,
      this.onCancel});

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  // 待ち時間を「知って得する時間」に変える小ネタ。4秒ごとに切り替え。
  static const _tips = [
    '読み取ったドレミは、タップで直せます',
    '読み落とした音符は、楽譜をタップして足せます',
    'できあがった楽譜は、印刷やPDFで共有できます',
    '画面の楽譜は、撮影よりスクリーンショットがきれいに読めます',
    '大きな楽譜は、近づいて数回に分けて撮るのがおすすめです',
  ];
  int _tipIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              // 認識はサーバー処理で進捗が取れないため、止まって見えない
              // 不確定リングにする（determinate だと数十秒「凍結」して見える）
              child: CircularProgressIndicator(
                color: AppColors.brand,
                strokeWidth: 5,
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.label[widget.progress.phase] ?? '処理中…',
                style: const TextStyle(color: AppColors.ink, fontSize: 15)),
            const SizedBox(height: 6),
            const Text('通常 20〜30秒ほどかかります',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            if (widget.pageInfo != null) ...[
              const SizedBox(height: 6),
              Text(widget.pageInfo!,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Container(
                key: ValueKey(_tipIndex),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 14)),
                    Flexible(
                      child: Text(_tips[_tipIndex],
                          style: const TextStyle(
                              color: AppColors.ink, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.onCancel != null) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('キャンセル',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onReshoot;
  const _ErrorBody(
      {required this.message, required this.onRetry, this.onReshoot});

  @override
  Widget build(BuildContext context) {
    // 1行目は見出しとして中央、コツの箇条書きは読みやすい左揃えカードに分ける
    final parts = message.split('\n\n');
    final headline = parts.first;
    final rest = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.ink,
                    height: 1.5,
                    fontWeight: FontWeight.w700)),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(rest,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        color: AppColors.ink, height: 1.7, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('もう一度試す')),
            if (onReshoot != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onReshoot,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('もどって撮り直す・選び直す'),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.brandDark),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
