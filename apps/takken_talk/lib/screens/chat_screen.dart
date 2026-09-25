import 'dart:async';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../api/client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../widgets/figure_card.dart';
import '../widgets/question_card.dart';
import 'figure_library_screen.dart';
import 'paywall_screen.dart';

/// 画面上の1メッセージ。assistant はストリーム中にテキストが伸び、カードが増える。
/// 画面上の1メッセージ。assistant はストリーム中に本文が伸び、
/// その途中でカード（問題・図解）が差し込まれる。AIは図を出してから
/// 「この表の急所は」と続けるので、出てきた順をそのまま保つ。
class _Item {
  _Item({required this.role, List<MessagePart>? parts}) : parts = parts ?? [];
  final String role;
  final List<MessagePart> parts;

  String get text => parts.whereType<TextPart>().map((p) => p.text).join('\n\n');

  Iterable<PublicQuestion> get questions =>
      parts.whereType<CardPart>().map((p) => p.card).whereType<PublicQuestion>();

  void appendText(String delta) {
    final last = parts.isEmpty ? null : parts.last;
    if (last is TextPart) {
      last.text += delta;
    } else {
      parts.add(TextPart(delta));
    }
  }

  void addCard(Object card) => parts.add(CardPart(card));

  /// ツール直前に出るゴミ断片を落とす
  void dropGarbage() => parts.removeWhere((p) => p is TextPart && isGarbageText(p.text));
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chapterId});
  final String chapterId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _items = <_Item>[];
  final _answers = <String, ({bool answer, bool correct})>{}; // questionId → 回答
  String? _currentTopicKey;
  bool _mapOpen = false;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _loading = true;
  bool _streaming = false;
  String? _loadError;
  StreamSubscription<TutorEvent>? _sub;

  Chapter get _chapter => AppScope.of(context).me!.chapter(widget.chapterId)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    try {
      final loaded = await api.messages(widget.chapterId);
      final history = loaded.messages;
      _currentTopicKey = loaded.currentTopic;
      _items.clear();
      for (final h in history) {
        if (h.role == 'user') {
          final a = h.answer;
          if (a != null) {
            _answers[a['questionId'] as String] = (answer: a['answer'] == true, correct: a['correct'] == true);
          }
          if (h.text.isNotEmpty) _items.add(_Item(role: 'user', parts: [TextPart(h.text)]));
        } else if (h.parts.isNotEmpty) {
          _items.add(_Item(role: 'assistant', parts: h.parts));
        }
      }
      setState(() {
        _loading = false;
        _loadError = null;
        _mapOpen = history.isEmpty;
      });
      _jumpToEnd();
      if (history.isEmpty) {
        await _send(start: true);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = '履歴を読み込めませんでした';
      });
    }
  }

  PublicQuestion? get _pendingQuestion {
    for (final it in _items.reversed) {
      for (final q in it.questions.toList().reversed) {
        if (!_answers.containsKey(q.id)) return q;
      }
    }
    return null;
  }

  Chapter get _chapterOrThrow => _chapter;

  int get _topicIndex =>
      _currentTopicKey == null ? -1 : _chapterOrThrow.topics.indexWhere((t) => t.key == _currentTopicKey);

  Future<void> _send({String? message, ({String questionId, bool answer})? answer, bool start = false}) async {
    if (_streaming) return;
    final state = AppScope.of(context);
    final api = state.api;
    setState(() {
      _streaming = true;
      if (message != null) _items.add(_Item(role: 'user', parts: [TextPart(message)]));
      if (answer != null && message == null) {
        _items.add(_Item(role: 'user', parts: [TextPart(answer.answer ? '○' : '×')]));
      }
      _items.add(_Item(role: 'assistant'));
    });
    _jumpToEnd();
    final target = _items.last;
    try {
      final stream = api.chat(chapterId: widget.chapterId, message: message, answer: answer, start: start);
      await for (final ev in stream) {
        if (!mounted) return;
        switch (ev) {
          case TextDelta(:final delta):
            setState(() => target.appendText(delta));
            _jumpToEnd(animated: false);
          case QuestionEvent(:final question):
            setState(() {
              target.dropGarbage();
              target.addCard(question);
            });
            _jumpToEnd();
          case FigureEvent(:final figure):
            setState(() {
              target.dropGarbage();
              target.addCard(figure);
            });
            _jumpToEnd();
          case TopicEvent():
            setState(() {
              _currentTopicKey = ev.topicKey;
              _mapOpen = false;
            });
            state.applyTopic(ev);
          case GradedEvent(:final questionId, :final answer, :final correct):
            setState(() => _answers[questionId] = (answer: answer, correct: correct));
          case ProgressEvent(:final progress):
            state.applyProgress(progress);
          case DoneEvent(:final turn):
            state.applyTurn(turn, widget.chapterId);
            if (turn.chargedTo == 'free' && turn.freeCap - turn.freeUsed == 10) {
              _toast('無料枠は残り10回です。Proにすると全章を話せます。');
            }
          case ErrorEvent(:final message):
            setState(() => target.appendText(target.parts.isEmpty ? message : '\n\n$message'));
        }
      }
      if (answer != null && !_answers.containsKey(answer.questionId)) {
        // graded イベントはサーバ側で採点済みなら来ない(カード回答)。ローカルにも印を付ける。
        // 正誤はサーバの解説がテキストに入っているので、ここでは「回答済み」だけ確定する。
        setState(() => _answers[answer.questionId] = (answer: answer.answer, correct: _lastCorrect(target.text)));
      }
      AppInsights.logEvent('chat_turn', parameters: {'chapter': widget.chapterId, 'kind': answer != null ? 'answer' : 'message'});
    } on ApiException catch (e) {
      setState(() {
        _items.remove(target);
        if (message != null && _items.isNotEmpty && _items.last.role == 'user') _items.removeLast();
        if (answer != null && message == null && _items.isNotEmpty && _items.last.role == 'user') _items.removeLast();
        if (message != null) _controller.text = message;
      });
      if (e.isPaymentRequired) {
        if (!mounted) return;
        await PaywallScreen.show(context, reason: e.code);
        if (mounted) await state.refresh();
      } else if (e.isOverCapacity) {
        _toast('いまアクセスが集中しています。しばらくしてからもう一度お試しください。');
      } else {
        _toast('送信できませんでした（${e.code}）');
      }
    } catch (e) {
      setState(() {
        if (target.parts.isEmpty) target.appendText('通信が途切れました。もう一度送ってください。');
      });
    } finally {
      if (mounted) setState(() => _streaming = false);
    }
  }

  /// カード回答の正誤は、サーバが採点してAIに渡している。返答テキストの冒頭で判定する保険。
  bool _lastCorrect(String text) {
    final head = text.length > 40 ? text.substring(0, 40) : text;
    if (head.contains('不正解') || head.contains('惜しい') || head.contains('残念') || head.contains('違います')) return false;
    return head.contains('正解') || head.contains('その通り') || head.contains('そのとおり') || head.contains('合って');
  }

  void _answerCard(PublicQuestion q, bool answer) {
    // 押した瞬間にカードを確定表示。正誤はサーバ応答で更新される。
    _send(answer: (questionId: q.id, answer: answer));
  }

  void _submitText() {
    final text = _controller.text.trim();
    if (text.isEmpty || _streaming) return;
    _controller.clear();
    _send(message: text);
  }

  void _jumpToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(max, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(max);
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapter = _chapter;
    final pending = _pendingQuestion;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('第${chapter.order}章', style: theme.textTheme.labelSmall),
            Text(chapter.short, style: theme.textTheme.titleMedium),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'この章の図解',
            icon: const Icon(Icons.image_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FigureLibraryScreen(chapter: chapter),
              settings: RouteSettings(name: 'figures_${chapter.id}'),
            )),
          ),
        ],
      ),
      body: Column(
        children: [
          _TopicStrip(
            chapter: chapter,
            currentIndex: _topicIndex,
            open: _mapOpen,
            onToggle: () => setState(() => _mapOpen = !_mapOpen),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!),
                            const SizedBox(height: 8),
                            TextButton(onPressed: _load, child: const Text('再読み込み')),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: _items.length,
                        itemBuilder: (context, i) => _Bubble(
                          item: _items[i],
                          answers: _answers,
                          streaming: _streaming && i == _items.length - 1,
                          canAnswer: !_streaming,
                          onAnswer: _answerCard,
                        ),
                      ),
          ),
          _InputBar(
            controller: _controller,
            focus: _focus,
            enabled: !_streaming && !_loading,
            hint: pending != null ? 'カードの○×で答えるか、言葉で答えてもOK' : '質問や、自分の言葉での説明をどうぞ',
            onSend: _submitText,
            quickReplies: _streaming || _loading
                ? const []
                : pending != null
                    ? const ['ヒントちょうだい', 'わからない']
                    : const ['次の問題', 'もう少し詳しく', '今どのくらい？'],
            onQuick: (s) => _send(message: s),
          ),
        ],
      ),
    );
  }

}

/// チャットの上に出す現在地。たたむと1行、開くとこの章のテーマ全部が見える。
/// 「いま何の話をしているか」と「この先に何があるか」を同じ場所で示す。
class _TopicStrip extends StatelessWidget {
  const _TopicStrip({
    required this.chapter,
    required this.currentIndex,
    required this.open,
    required this.onToggle,
  });
  final Chapter chapter;
  final int currentIndex;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = chapter.topics.length;
    final label = currentIndex >= 0
        ? '${currentIndex + 1}/$total  ${chapter.topics[currentIndex].title}'
        : 'この章のテーマ（$total）';
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.06),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
              child: Row(
                children: [
                  Icon(Icons.explore_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more, size: 20, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          if (!open && currentIndex >= 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: EdgeInsets.only(right: i == total - 1 ? 0 : 3),
                        decoration: BoxDecoration(
                          color: i <= currentIndex ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapter.goal, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                  const SizedBox(height: 10),
                  for (final (i, t) in chapter.topics.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: i == currentIndex
                                  ? theme.colorScheme.primary
                                  : i < currentIndex
                                      ? theme.colorScheme.primary.withValues(alpha: 0.45)
                                      : theme.colorScheme.outlineVariant,
                              shape: BoxShape.circle,
                            ),
                            child: Text('${i + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.title,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.4,
                                fontWeight: i == currentIndex ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text('${t.questionCount}問・図解${t.figureCount}',
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text('テーマは会話の流れで前後します。聞きたいところがあれば、そのまま言ってください。',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, height: 1.4)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.item,
    required this.answers,
    required this.streaming,
    required this.canAnswer,
    required this.onAnswer,
  });
  final _Item item;
  final Map<String, ({bool answer, bool correct})> answers;
  final bool streaming;
  final bool canAnswer;
  final void Function(PublicQuestion, bool) onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = item.role == 'user';
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(item.text, style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 15, height: 1.4)),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.parts.isEmpty && streaming)
            const Padding(padding: EdgeInsets.all(8), child: _TypingDots()),
          for (final part in item.parts)
            switch (part) {
              TextPart() => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: MarkdownBody(
                    data: part.text.trim(),
                    selectable: false,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                      listBullet: theme.textTheme.bodyLarge,
                      tableColumnWidth: const IntrinsicColumnWidth(),
                    ),
                  ),
                ),
              CardPart(card: final PublicQuestion q) => QuestionCard(
                  question: q,
                  answered: answers[q.id]?.answer,
                  correct: answers[q.id]?.correct,
                  enabled: canAnswer,
                  onAnswer: (a) => onAnswer(q, a),
                ),
              CardPart(card: final Figure f) => FigureCard(figure: f),
              CardPart() => const SizedBox.shrink(),
            },
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
          final o = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: CircleAvatar(radius: 4, backgroundColor: color.withValues(alpha: o)),
          );
        }),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.hint,
    required this.onSend,
    required this.quickReplies,
    required this.onQuick,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final String hint;
  final VoidCallback onSend;
  final List<String> quickReplies;
  final ValueChanged<String> onQuick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (quickReplies.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                  children: [
                    for (final q in quickReplies)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text(q), onPressed: () => onQuick(q), visualDensity: VisualDensity.compact),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: enabled ? onSend : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
