import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../api/client.dart';
import '../models/core.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/figure/figure_view.dart';
import '../widgets/question_card.dart';
import '../widgets/readable.dart';
import '../widgets/rich_text.dart';
import 'common/parts.dart';
import 'pro_screen.dart';
import 'learn/chapter_sheet.dart';
import 'learn/learn_models.dart';
import 'learn/message_report.dart';

/// 章ごとに AI の先生と話して学ぶ画面（サイトの /takken/learn/[chapter]）。
/// 先生の返答は、本文・○×カード・図・選択肢が届いた順に並ぶ。カードはその場で答えられる。
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, required this.chapterId, this.startPointId});
  final String chapterId;

  /// 開いたらこの論点の説明を頼む（過去問の「この論点を先生と学ぶ」から）
  final String? startPointId;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

/// 入力欄の上の返答の候補（サイトの quickReplies と同じ決まり）
class _Quick {
  const _Quick(this.label, {this.message, this.point, this.chapter, this.kakomon});
  final String label;
  final String? message;
  final OutlinePoint? point;
  final String? chapter;

  /// この論点の過去問を解く画面を開く
  final OutlinePoint? kakomon;
}

class _LearnScreenState extends State<LearnScreen> {
  // ---- 章のデータ（GET learn） ----
  LearnChapter? _chapter;
  int _pointsTotal = 0;
  Map<String, FigureData> _figures = const {};
  List<Term> _glossary = const [];
  Neighbor? _prev;
  Neighbor? _next;
  String _pace = 'standard';

  /// 過去問の数（この章ぜんぶ・論点ごと）。古いサーバーでは 0
  int _kakomonTotal = 0;
  Map<String, int> _kakomonByPoint = const {};
  bool _loading = true;
  String? _loadError;

  // ---- 会話 ----
  final _items = <Item>[];
  String? _topicKey;
  String? _currentPoint;
  final _taught = <String>{};
  final _answered = <String>{};
  bool _busy = false;

  /// 1日の上限（429/503）。出ているあいだは送れない
  String? _limitMessage;

  /// 直前の○×の結果。返答の候補を変える（次に何かを送ったら消える）
  String? _lastGrade;

  /// 先生が別の章に切り替えたとき、返答を読み終えてから移る先
  Neighbor? _moveTo;

  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _disposed = false;

  /// 送ったときに画面の上端に合わせるもの（自分の発言、カードで答えたときはそのカード）
  final _pinKey = GlobalKey();
  Object? _pinTarget;

  /// この画面で送ったあとは、最後の返答に画面1つ分の高さを持たせる。
  /// そうしないと返答が短いうちは自分の発言を上端まで送れない
  bool _grow = false;

  /// 一番下から離れて読んでいるか（「↓ 最新の返答へ」を出す）
  bool _away = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _disposed = true;
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final away = _scroll.position.maxScrollExtent - _scroll.offset > 240;
    if (away != _away) setState(() => _away = away);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final d = await AppScope.read(context).api.learn(widget.chapterId);
      if (_disposed) return;
      final chapter = LearnChapter.fromJson(d['chapter'] as Map<String, dynamic>);
      _items.clear();
      for (final m in (d['messages'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        if (m['role'] == 'user') {
          _items.add(UserItem(m['text'] as String? ?? ''));
        } else {
          final segs = [for (final s in (m['segments'] as List? ?? const []).cast<Map<String, dynamic>>()) ?segFromJson(s)];
          _items.add(AssistantItem(segments: segs, id: m['id'] as String?));
        }
      }
      _topicKey = d['currentTopic'] as String?;
      _taught
        ..clear()
        ..addAll(chapter.points.where((p) => p.taught).map((p) => p.id));
      _answered
        ..clear()
        ..addAll(((d['answered'] as List?) ?? const []).cast<String>());
      // 開き直したときは、いまのテーマで最後に説明を受けた論点を現在地にする
      // テーマがまだ分からないときは、章の中で最後に説明を受けた論点
      _currentPoint = (_topicKey == null ? chapter.points : chapter.topics.where((t) => t.key == _topicKey).firstOrNull?.points ?? const <OutlinePoint>[]).where((p) => p.taught).lastOrNull?.id;
      setState(() {
        _chapter = chapter;
        _pointsTotal = (d['pointsTotal'] as num?)?.toInt() ?? chapter.points.length;
        _figures = {for (final e in ((d['figures'] as Map?) ?? const {}).entries) e.key as String: FigureData.fromJson(e.value as Map<String, dynamic>)};
        _glossary = Term.listFrom(d['glossary']);
        final nb = d['neighbors'] as Map<String, dynamic>? ?? const {};
        _prev = Neighbor.fromJson(nb['prev']);
        _next = Neighbor.fromJson(nb['next']);
        _pace = d['pace'] as String? ?? 'standard';
        final k = d['kakomon'] as Map?;
        _kakomonTotal = (k?['total'] as num?)?.toInt() ?? 0;
        _kakomonByPoint = {for (final e in ((k?['byPoint'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()};
        _loading = false;
      });
      final start = chapter.point(widget.startPointId);
      if (start != null) {
        // 過去問から来たときは、その論点の説明から（それまでの会話の続きに足す）
        if (_items.isNotEmpty) _jumpToEnd();
        unawaited(_teach(start));
      } else if (_items.isEmpty) {
        unawaited(_send({'start': true}));
      } else {
        _jumpToEnd();
      }
    } catch (e) {
      if (_disposed) return;
      setState(() {
        _loading = false;
        _loadError = e is ApiException && e.message != null ? e.message : '会話を読み込めませんでした。通信環境を確認してもう一度お試しください。';
      });
    }
  }

  // ---------- 会話の状況 ----------

  /// まだ答えていない最後の問題。返答の候補と入力欄の案内を変える
  PublicQuestion? get _pending {
    for (final it in _items.reversed) {
      if (it is! AssistantItem) continue;
      for (final s in it.segments.reversed) {
        if (s is QuestionSeg) return s.graded == null ? s.question : null;
      }
    }
    return null;
  }

  /// 最新の先生の返答にある選択肢だけ押せる（前の返答の選択肢は押せない）
  ChoicesSeg? get _openChoices {
    final last = _items.lastOrNull;
    if (last is! AssistantItem) return null;
    return last.segments.whereType<ChoicesSeg>().lastOrNull;
  }

  bool get _canSend => !_busy && _limitMessage == null && _chapter != null;

  List<_Quick> get _quickReplies {
    final chapter = _chapter;
    if (chapter == null) return const [];
    if (_pending != null) return const [_Quick('ヒントちょうだい'), _Quick('わからない')];
    final all = chapter.points;
    final start = _currentPoint == null ? -1 : all.indexWhere((p) => p.id == _currentPoint);
    final nextPoint = [...all.skip(start + 1), ...all.take(start + 1 < 0 ? 0 : start + 1)].where((p) => !_taught.contains(p.id)).firstOrNull;
    final next = nextPoint == null ? const <_Quick>[] : [_Quick('次は「${nextPoint.title.length > 14 ? '${nextPoint.title.substring(0, 14)}…' : nextPoint.title}」へ', point: nextPoint)];
    const more = _Quick('この論点をもっと解く', message: 'この論点の○×をもっと解きたい');
    const drill = _Quick('このテーマをまとめて解く', message: 'このテーマの○×をまとめて解きたい（間違えた問題とまだ解いていない問題を中心に）');
    // 説明を聞いた論点に過去問があれば、その論点の過去問を解く入口。候補の数に数えず、いつも最後に足す
    final here = chapter.point(_currentPoint);
    final kakomon = here != null && _taught.contains(here.id) && (_kakomonByPoint[here.id] ?? 0) > 0 ? [_Quick('過去問 ${_kakomonByPoint[here.id]}問', kakomon: here)] : const <_Quick>[];
    // 選択肢が出ているときは、それに答えてもらうのが先
    if (_openChoices != null) {
      if (_lastGrade == 'wrong') return const [_Quick('どこが違ったか教えて'), _Quick('もう一度説明して')];
      if (_lastGrade == 'right') return [...(_pace == 'drill' ? [more, ...next] : [...next, more]).take(2), ...kakomon];
      return [const _Quick('もう少しかみくだいて'), ...kakomon];
    }
    final chapterDone = all.isNotEmpty && all.every((p) => _taught.contains(p.id) && p.questionIds.every(_answered.contains));
    final done = chapterDone && _next != null ? [_Quick('次の章へ進む', chapter: _next!.id)] : const <_Quick>[];
    final cur = chapter.point(_currentPoint);
    List<_Quick> out;
    if (_lastGrade == 'wrong') {
      out = const [_Quick('どこが違ったか教えて'), _Quick('似た問題をもう1問'), _Quick('もう一度説明して')];
    } else if (_lastGrade == 'right') {
      out = switch (_pace) {
        'drill' => [more, drill, ...next],
        'fast' => [...next, const _Quick('似た問題をもう1問'), const _Quick('今どのくらい？')],
        _ => [...next, more, drill],
      };
    } else if (cur != null && _taught.contains(cur.id)) {
      final shown = {for (final it in _items.whereType<AssistantItem>()) ...it.segments.whereType<FigureSeg>().map((s) => s.figure.id)};
      final unseenFig = cur.figureIds.any((f) => !shown.contains(f));
      out = [const _Quick('○×で確かめる'), unseenFig ? const _Quick('図で見せて') : const _Quick('例を挙げて'), ...next];
    } else {
      out = [...next, const _Quick('○×を出して'), const _Quick('今どのくらい？')];
    }
    return [...[...done, ...out].take(3), ...kakomon];
  }

  // ---------- 送る ----------

  /// 1ターン送る。shown は自分の吹き出しに出す文（カードで答えたときは出さない）
  Future<void> _send(Map<String, Object?> body, {String? shown, Object? pinTo}) async {
    if (_busy || _chapter == null) return;
    final reply = AssistantItem()
      ..body = body
      ..shown = shown;
    final user = shown == null ? null : UserItem(shown);
    setState(() {
      _busy = true;
      _limitMessage = null;
      _lastGrade = null;
      if (user != null) _items.add(user);
      _items.add(reply);
      _grow = true;
      _pinTarget = pinTo ?? user;
    });
    _pin();
    final state = AppScope.read(context);
    try {
      await for (final e in state.api.chat({'chapterId': widget.chapterId, ...body})) {
        if (_disposed) return;
        setState(() => _apply(reply, e, state));
      }
      if (_disposed) return;
      if (reply.segments.isEmpty && reply.error == null) reply.error = '返答を受け取れませんでした。もう一度送ってください。';
    } on ApiException catch (e) {
      if (_disposed) return;
      if (e.isOverCap) {
        _items.remove(reply);
        if (user != null) {
          _items.remove(user);
          // 書いた文が消えないように入力欄に戻す
          if (body['message'] != null && _input.text.isEmpty) _input.text = body['message'] as String;
        }
        _limitMessage = e.message ?? '今日はもう話せません。';
      } else {
        reply.error = e.message ?? '送れませんでした。もう一度試してください。';
      }
    } catch (_) {
      if (_disposed) return;
      reply.error = '通信が切れました。もう一度送ってください。';
    }
    if (_disposed) return;
    setState(() => _busy = false);
  }

  void _apply(AssistantItem reply, Map<String, dynamic> e, AppState state) {
    final chapter = _chapter;
    switch (e['type']) {
      case 'text':
        reply.appendText(e['delta'] as String? ?? '');
      case 'question':
        reply.segments.add(QuestionSeg(PublicQuestion.fromJson(e['question'] as Map<String, dynamic>)));
      case 'figure':
        reply.segments.add(FigureSeg(FigureData.fromJson(e['figure'] as Map<String, dynamic>)));
      case 'choices':
        reply.segments.add(ChoicesSeg(e['question'] as String? ?? '', ((e['choices'] as List?) ?? const []).cast<String>()));
      case 'graded':
        final id = e['questionId'] as String;
        _markGraded(id, Graded.fromJson(e));
        _lastGrade = e['correct'] == true ? 'right' : 'wrong';
        _answered.add(id);
      case 'topic':
        if (e['chapterId'] == null || e['chapterId'] == chapter?.id) _topicKey = e['topicKey'] as String?;
      case 'point':
        final id = e['pointId'] as String;
        _taught.add(id);
        _currentPoint = id;
      case 'navigate':
        _moveTo = Neighbor(e['chapterId'] as String, e['title'] as String? ?? '');
      case 'done':
        reply.id = e['messageId'] as String? ?? reply.id;
        state.applyTurn(e['turn'] as Map<String, dynamic>?);
      case 'error':
        reply.error = e['message'] as String? ?? '返答を作れませんでした。もう一度送ってください。';
    }
  }

  /// 採点は、その問題がいちばん最後に出たカードにだけ付ける（同じ問題がもう一度出ても、前の答えを見せない）
  void _markGraded(String questionId, Graded g) {
    for (final it in _items.reversed) {
      if (it is! AssistantItem) continue;
      for (final s in it.segments.reversed) {
        if (s is QuestionSeg && s.question.id == questionId && s.graded == null) {
          s.graded = g;
          return;
        }
      }
    }
  }

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty || !_canSend) return;
    _input.clear();
    // 送ったらキーボードを閉じて、返答を広く見せる
    FocusScope.of(context).unfocus();
    _send({'message': text}, shown: text);
  }

  void _answer(QuestionSeg s, bool a) => _send({
    'answer': {'questionId': s.question.id, 'answer': a},
  }, pinTo: s);

  /// 論点の名前が「」で始まるときは、さらに「」で囲まない
  Future<void> _teach(OutlinePoint p) => _send({'pointId': p.id}, shown: p.title.startsWith('「') ? '${p.title}を教えて' : '「${p.title}」を教えて');

  /// この章（point を渡すとその論点だけ）の過去問を解く。解き終えたら戻るボタンでこの会話に戻る
  Future<void> _openKakomon({OutlinePoint? point}) async {
    final chapter = _chapter;
    if (chapter == null) return;
    await openKakomon(context, set: chapter.id, label: '第${chapter.order}章', point: point?.id, pointTitle: point?.title ?? chapter.short, fromChapter: chapter.id);
  }

  void _quick(_Quick q) {
    if (q.kakomon != null) {
      _openKakomon(point: q.kakomon);
    } else if (q.chapter != null) {
      _openChapter(q.chapter!);
    } else if (q.point != null) {
      _teach(q.point!);
    } else {
      _send({'message': q.message ?? q.label}, shown: q.label);
    }
  }

  /// 失敗した1往復を消して、同じ頼みをもう一度
  void _retry(AssistantItem failed) {
    final body = failed.body;
    if (body == null || _busy) return;
    setState(() {
      final i = _items.indexOf(failed);
      _items.removeAt(i);
      if (failed.shown != null && i > 0 && _items[i - 1] is UserItem) _items.removeAt(i - 1);
    });
    _send(body, shown: failed.shown);
  }

  void _openChapter(String id) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LearnScreen(chapterId: id),
        settings: RouteSettings(name: 'learn_$id'),
      ),
    );
  }

  Future<void> _openSheet({String? textPointId}) async {
    final chapter = _chapter;
    if (chapter == null) return;
    final action = await showChapterSheet(
      context,
      chapter: chapter,
      taught: _taught,
      answered: _answered,
      currentTopic: _topicKey ?? _topicOf(_currentPoint),
      currentPoint: _currentPoint,
      figures: _figures,
      glossary: _glossary,
      canTeach: _canSend,
      pace: _pace,
      onPace: (p) {
        setState(() => _pace = p);
        AppScope.read(context).api.patchSettings({'pace': p}).catchError((_) {});
      },
      prev: _prev,
      next: _next,
      textPointId: textPointId,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case TeachPoint(:final point):
        _teach(point);
      case QuizPoint(:final point):
        _send({'message': '「${point.title}」の○×を解きたい'}, shown: '「${point.title}」の○×を解きたい');
      case OpenChapter(:final chapterId):
        _openChapter(chapterId);
    }
  }

  // ---------- スクロール ----------

  /// 送った発言（カードで答えたときはそのカード）を画面の上端に合わせる。
  /// 返答はその下に流れてくるので、聞いたことと返答の書き出しが必ず見える。返答が伸びても追いかけない（自分で動かすのを邪魔しない）
  void _pin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      // 遠くを見ていると目当ての行がまだ作られていないので、先に一番下へ
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      // 上の行の高さは作ってみるまで見積もりなので、一度合わせてから次のフレームでもう一度合わせる
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealPinned(animate: false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealPinned(animate: true));
      });
    });
  }

  /// 目当ての行の頭を、上端から少し空けたところに合わせる
  void _revealPinned({required bool animate}) {
    final ro = _pinKey.currentContext?.findRenderObject();
    if (ro == null || !ro.attached || !_scroll.hasClients) return;
    final viewport = RenderAbstractViewport.maybeOf(ro);
    if (viewport == null) return;
    final p = _scroll.position;
    final to = (viewport.getOffsetToReveal(ro, 0).offset - 12).clamp(p.minScrollExtent, p.maxScrollExtent);
    animate ? _scroll.animateTo(to, duration: const Duration(milliseconds: 200), curve: Curves.easeOut) : _scroll.jumpTo(to);
  }

  void _jumpToEnd({bool animated = false}) {
    // 下の行は作られてから高さが決まるので、2回に分けて送る
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final max = _scroll.position.maxScrollExtent;
        animated ? _scroll.animateTo(max, duration: const Duration(milliseconds: 300), curve: Curves.easeOut) : _scroll.jumpTo(max);
      });
    });
  }

  // ---------- 画面 ----------

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter ?? _summaryChapter(context);
    return Scaffold(
      backgroundColor: Palette.desk,
      appBar: AppBar(
        backgroundColor: Palette.paper,
        shape: const Border(bottom: BorderSide(color: Palette.line)),
        // 戻るボタンがあるときだけ詰める（無いと見出しが画面の端に付く）
        titleSpacing: ModalRoute.of(context)?.canPop == true ? 0 : null,
        title: chapter == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('第${chapter.order}章', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                  Text(
                    chapter.short,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
        actions: [
          if (_chapter != null && _kakomonTotal > 0)
            TextButton.icon(
              onPressed: _openKakomon,
              icon: const Icon(Icons.edit_note, size: 22),
              label: const Text('過去問'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          if (_chapter != null)
            IconButton(
              tooltip: 'テキスト',
              onPressed: () => _openSheet(textPointId: _currentPoint ?? _chapter!.points.firstOrNull?.id),
              icon: const Icon(Icons.menu_book_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _LoadError(message: _loadError!, onRetry: _load)
          : Column(
              children: [
                _Where(chapter: _chapter!, topicKey: _topicKey ?? _topicOf(_currentPoint), point: _chapter!.point(_currentPoint), taught: _taught.length, pointsTotal: _pointsTotal, onTap: _openSheet),
                Expanded(
                  child: Stack(
                    children: [
                      // 返答が伸びて下に続きができたときも「↓ 最新の返答へ」を出す（スクロールしなくても届く）
                      NotificationListener<ScrollMetricsNotification>(
                        onNotification: (_) {
                          _onScroll();
                          return false;
                        },
                        child: LayoutBuilder(builder: (context, box) => _log(box.maxHeight)),
                      ),
                      if (_away)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: FilledButton.tonal(
                              onPressed: () => _jumpToEnd(animated: true),
                              style: FilledButton.styleFrom(backgroundColor: Palette.ink, foregroundColor: Colors.white, minimumSize: const Size(0, 44), textStyle: const TextStyle(fontSize: 14)),
                              child: const Text('↓ 最新の返答へ'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _compose(context),
              ],
            ),
    );
  }

  /// topic が届いていないときは、いまの論点のテーマを現在地にする
  String? _topicOf(String? pointId) => pointId == null ? null : _chapter?.topics.where((t) => t.points.any((p) => p.id == pointId)).firstOrNull?.key;

  /// 読み込み中も見出しを出す（ホームの章の一覧から引ける）
  LearnChapter? _summaryChapter(BuildContext context) {
    final c = AppScope.of(context).chapter(widget.chapterId);
    return c == null ? null : LearnChapter(id: c.id, order: c.order, title: c.title, short: c.short, goal: c.goal, topics: const []);
  }

  Widget _log(double viewport) {
    final extra = (_limitMessage != null ? 1 : 0) + (_moveTo != null && !_busy ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      // 会話を動かしたらキーボードを閉じる（開いたままだと返答が半分しか見えない）
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _items.length + extra,
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          final k = i - _items.length;
          if (k == 0 && _limitMessage != null) {
            final pro = AppScope.of(context).me?['pro'] == true;
            return Readable(
              child: _Notice(
                _limitMessage!,
                tone: Palette.warning,
                soft: Palette.warningSoft,
                action: pro ? null : ('Pro で増やす', () => ProScreen.show(context, reason: 'cap')),
              ),
            );
          }
          return Readable(
            child: _MoveTo(to: _moveTo!, onOpen: () => _openChapter(_moveTo!.id)),
          );
        }
        final it = _items[i];
        final last = i == _items.length - 1;
        Widget child = switch (it) {
          UserItem() => _UserBubble(it.text),
          AssistantItem() => _assistant(it, last),
        };
        if (identical(it, _pinTarget)) child = KeyedSubtree(key: _pinKey, child: child);
        // 送ったあとの最後の返答は画面1つ分の高さを取る（自分の発言を上端に合わせられるように。40 は下の余白と行の間）
        if (last && _grow && it is AssistantItem) {
          child = ConstrainedBox(
            constraints: BoxConstraints(minHeight: (viewport - 40).clamp(0, double.infinity)),
            child: Align(alignment: Alignment.topCenter, child: child),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Readable(child: child),
        );
      },
    );
  }

  Widget _assistant(AssistantItem it, bool last) {
    final streaming = last && _busy;
    final open = _openChoices;
    final children = <Widget>[];
    for (final s in it.segments) {
      final Widget w = switch (s) {
        TextSeg(:final text) =>
          text.trim().isEmpty
              ? const SizedBox.shrink()
              : RichBody(
                  text.trimLeft(),
                  glossary: _glossary,
                  style: const TextStyle(fontSize: 16, height: 1.8, color: Palette.ink),
                ),
        QuestionSeg() => QuestionCard(question: s.question, graded: s.graded, disabled: !_canSend, onAnswer: (a) => _answer(s, a), shownOn: 'learn', glossary: _glossary),
        FigureSeg(:final figure) => FigureView(figure: figure, shownOn: 'learn'),
        ChoicesSeg() => _Choices(
          seg: s,
          enabled: _canSend && identical(s, open),
          onPick: (c) => _send({'message': c}, shown: c),
        ),
      };
      children.add(identical(s, _pinTarget) ? KeyedSubtree(key: _pinKey, child: w) : w);
    }
    if (it.segments.isEmpty && streaming && it.error == null) {
      children.add(const _Typing());
    }
    if (it.error != null) {
      children.add(_Notice(it.error!, tone: Palette.danger, soft: Palette.dangerSoft, action: it.body != null && !_busy ? ('もう一度送る', () => _retry(it)) : null));
    }
    if (it.id != null && !streaming) {
      children.add(
        it.reported
            ? const Text('報告しました。ありがとうございます。', style: TextStyle(fontSize: 13, color: Palette.success))
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _report(it),
                  style: TextButton.styleFrom(
                    foregroundColor: Palette.inkFaint,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(fontSize: 13, decoration: TextDecoration.underline),
                  ),
                  child: const Text('この返答を報告'),
                ),
              ),
      );
    }
    return GestureDetector(
      // 長押しでも報告できる（下の小さな文字を探さなくてよいように）
      onLongPress: it.id != null && !streaming && !it.reported ? () => _report(it) : null,
      behavior: HitTestBehavior.translucent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, w) in children.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: w,
            ),
        ],
      ),
    );
  }

  Future<void> _report(AssistantItem it) async {
    final ok = await showMessageReport(context, messageId: it.id!);
    if (ok && mounted) setState(() => it.reported = true);
  }

  Widget _compose(BuildContext context) {
    final state = AppScope.of(context);
    final quick = _limitMessage == null ? _quickReplies : const <_Quick>[];
    final hint = _pending != null
        ? '○×か、言葉で答える'
        : _openChoices != null
        ? '選ぶか、言葉で答える'
        : '聞きたいことをどうぞ';
    final left = state.capToday - state.usedToday;
    return Material(
      color: Palette.paper,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Palette.line)),
        ),
        child: SafeArea(
          top: false,
          child: Readable(
            maxWidth: 720,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (quick.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: quick.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ActionChip(
                          avatar: quick[i].kakomon != null ? const Icon(Icons.edit_note, size: 18, color: Palette.primary) : null,
                          label: Text(quick[i].label),
                          onPressed: _canSend ? () => _quick(quick[i]) : null,
                          backgroundColor: Palette.paper,
                          side: const BorderSide(color: Palette.lineStrong),
                          shape: const StadiumBorder(),
                          labelStyle: const TextStyle(fontSize: 14, color: Palette.ink),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          enabled: _limitMessage == null,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 2000,
                          textInputAction: TextInputAction.newline,
                          // 欄の外（会話・候補・送る）を押したらキーボードを閉じる
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: hint,
                            counterText: '',
                            isDense: true,
                            filled: true,
                            fillColor: Palette.fill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _canSend && _input.text.trim().isNotEmpty ? _submit : null,
                        style: FilledButton.styleFrom(minimumSize: const Size(64, 46), padding: const EdgeInsets.symmetric(horizontal: 16)),
                        child: const Text('送る'),
                      ),
                    ],
                  ),
                  if (!state.unlimited && state.home != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 6),
                      child: Text('今日の残り ${left < 0 ? 0 : left}/${state.capToday}回', style: const TextStyle(fontSize: 12, color: Palette.inkFaint)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 会話の上の現在地。押すと目次とテキストが開く
class _Where extends StatelessWidget {
  const _Where({required this.chapter, required this.topicKey, required this.point, required this.taught, required this.pointsTotal, required this.onTap});
  final LearnChapter chapter;
  final String? topicKey;
  final OutlinePoint? point;
  final int taught;
  final int pointsTotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ti = chapter.topics.indexWhere((t) => t.key == topicKey);
    final total = chapter.topics.length;
    const strong = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.primaryStrong);
    return Material(
      color: Palette.primarySoft,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Palette.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (ti >= 0) Text('${ti + 1}/$total  ', style: strong),
                        Expanded(
                          child: Text(ti >= 0 ? chapter.topics[ti].title : 'この章のテーマ（$total）', maxLines: 1, overflow: TextOverflow.ellipsis, style: strong),
                        ),
                      ],
                    ),
                    if (point != null)
                      Text(
                        'いま: ${point!.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Palette.primary),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (var i = 0; i < total; i++)
                          Expanded(
                            child: Container(
                              height: 4,
                              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 3),
                              decoration: BoxDecoration(color: i <= ti ? Palette.primary : Palette.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (pointsTotal > 0) Text('説明 $taught/$pointsTotal', style: strong),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, color: Palette.primaryStrong),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: FractionallySizedBox(
      widthFactor: 0.82,
      alignment: Alignment.centerRight,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: const BoxDecoration(
            color: Palette.primary,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4)),
          ),
          child: Text(text, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white)),
        ),
      ),
    ),
  );
}

/// 先生の確認の選択肢。最後の1つ（「わからない」など）は点線で控えめに
class _Choices extends StatelessWidget {
  const _Choices({required this.seg, required this.enabled, required this.onPick});
  final ChoicesSeg seg;
  final bool enabled;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: Palette.paper,
      border: Border.all(color: Palette.lineStrong),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(seg.question, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
        for (final (i, c) in seg.choices.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: enabled ? () => onPick(c) : null,
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                foregroundColor: i == seg.choices.length - 1 ? Palette.inkSoft : Palette.primaryStrong,
                side: BorderSide(color: i == seg.choices.length - 1 || !enabled ? Palette.lineStrong : Palette.primary, width: 1.5),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
              ),
              child: Text(c),
            ),
          ),
      ],
    ),
  );
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('先生が説明を準備しています…', style: TextStyle(fontSize: 14, color: Palette.inkSoft)),
      Text('（最初は10秒ほどかかることがあります）', style: TextStyle(fontSize: 13, color: Palette.inkFaint)),
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {required this.tone, required this.soft, this.action});
  final String text;
  final Color tone;
  final Color soft;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(6)),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, height: 1.6, color: tone)),
        ),
        if (action != null)
          TextButton(
            onPressed: action!.$2,
            style: TextButton.styleFrom(foregroundColor: tone, minimumSize: const Size(44, 44)),
            child: Text(action!.$1),
          ),
      ],
    ),
  );
}

/// 先生が別の章に切り替えたとき。読み終えてから自分で移る
class _MoveTo extends StatelessWidget {
  const _MoveTo({required this.to, required this.onOpen});
  final Neighbor to;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Palette.paper,
      border: Border.all(color: Palette.line),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('次は「${to.title}」です', style: const TextStyle(fontSize: 14, color: Palette.inkSoft)),
        const SizedBox(height: 8),
        FilledButton(onPressed: onOpen, child: const Text('この章へ進む')),
      ],
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 40, color: Palette.inkSoft),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    ),
  );
}
