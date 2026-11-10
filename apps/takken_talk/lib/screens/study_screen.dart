import 'package:flutter/material.dart';

import '../funnel.dart';
import '../models/core.dart';
import '../state/app_state.dart';
import '../study_draft.dart';
import '../theme.dart';
import '../widgets/question_card.dart';
import '../widgets/readable.dart';
import '../widgets/rich_text.dart';
import 'common/parts.dart';
import 'kakomon/explain_sheet.dart';
import 'pro/analysis_screen.dart';

class StudyEntryCard extends StatefulWidget {
  const StudyEntryCard({super.key, required this.session});
  final Map<String, dynamic> session;

  @override
  State<StudyEntryCard> createState() => _StudyEntryCardState();
}

class _StudyEntryCardState extends State<StudyEntryCard> {
  StudyDraft? _draft;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StudyEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _load();
  }

  Future<void> _load() async {
    final id = AppScope.read(context).api.userId;
    if (id == null) return;
    final d = await StudyDraft.load(id, widget.session);
    if (mounted && AppScope.read(context).api.userId == id) {
      setState(() => _draft = d);
    }
  }

  Future<void> _open() async {
    final d = _draft;
    if (d == null || _opening) return;
    setState(() => _opening = true);
    try {
      await d.save();
      await Funnel.studyStarted(d.userId, d.kind, d.day);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'study_session'),
          builder: (_) => StudyScreen(draft: d),
        ),
      );
      if (mounted) {
        await AppScope.read(context).refreshQuietly();
        await _load();
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    final starter = (d?.kind ?? widget.session['kind']) == 'starter';
    return Card(
      color: Palette.primarySoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              d?.complete == true
                  ? '今日の3問を終えました'
                  : starter
                  ? 'まずは説明を読んで3問'
                  : '今日の復習3問',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              starter
                  ? '短い説明のあと、○×で確かめます。わからないところは AI に聞けます。'
                  : 'まちがえた問題や、復習の時期が来た問題から確かめましょう。',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: d == null || _opening ? null : _open,
              child: Text(
                d?.complete == true
                    ? '今日の結果を見る'
                    : (d?.answers.isNotEmpty ?? false)
                    ? '残りの問題を解く'
                    : starter
                    ? 'まず3問やってみる'
                    : '今日の3問を始める',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, required this.draft});
  final StudyDraft draft;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late int _index = _initialIndex();
  bool _sending = false;
  final _scroll = ScrollController();
  StudyDraft get _draft => widget.draft;
  List<Map<String, dynamic>> get _questions => _draft.questions;

  int _initialIndex() {
    if (_draft.complete) return _questions.length;
    return _questions.indexWhere((q) => !_draft.answers.containsKey(q['id']));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _answer(bool answer) async {
    final q = _questions[_index];
    if (_sending || _draft.answers.containsKey(q['id'])) return;
    setState(() => _sending = true);
    try {
      final result = await AppScope.read(context).api.answer(
        q['id'] as String,
        answer,
        via: _draft.kind == 'starter' ? 'kakomon' : 'review',
      );
      _draft.answers[q['id'] as String] = {...result, 'answer': answer};
      await _draft.save();
      Funnel.event(
        'study_question_answered',
        parameters: {
          'kind': _draft.kind,
          'correct': result['correct'] == true ? 1 : 0,
          'version': 1,
        },
      );
      if (_draft.complete) {
        await Funnel.studyCompleted(
          _draft.userId,
          _draft.kind,
          _draft.day,
          _draft.correct,
          _questions.length,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('答えを保存できませんでした。もう一度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _next() {
    setState(() => _index++);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_draft.kind == 'starter' ? 'はじめの3問' : '今日の復習')),
    body: Readable(
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: _index >= _questions.length
            ? _summary(context)
            : _question(context),
      ),
    ),
  );

  List<Widget> _question(BuildContext context) {
    final raw = _questions[_index];
    final q = PublicQuestion.fromJson(raw);
    final result = _draft.answers[q.id];
    final graded = result == null ? null : Graded.fromJson(result);
    final lesson = raw['lesson'] as Map?;
    final repeatedLesson =
        _index > 0 &&
        (_questions[_index - 1]['lesson'] as Map?)?['title'] ==
            lesson?['title'];
    return [
      Text(
        '${_index + 1} / ${_questions.length}問',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      ProgressBar(value: _index / _questions.length),
      if (lesson != null && repeatedLesson)
        ExpansionTile(
          key: ValueKey(q.id),
          title: const Text('説明を読み返す'),
          children: [RichBody(lesson['text'] as String)],
        )
      else if (lesson != null) ...[
        const SizedBox(height: 20),
        Text(
          lesson['title'] as String,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        RichBody(lesson['text'] as String),
      ],
      const SizedBox(height: 20),
      QuestionCard(
        question: q,
        graded: graded,
        disabled: _sending,
        onAnswer: _answer,
        shownOn: 'study',
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _sending
            ? null
            : () => showExplainSheet(
                context,
                questionId: q.id,
                statement: q.statement,
                where: q.topic,
                graded: graded,
              ),
        icon: const Icon(Icons.forum_outlined),
        label: const Text('わからないところを AI に聞く'),
      ),
      if (graded != null) ...[
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _sending ? null : _next,
          child: Text(_index + 1 == _questions.length ? '今回の結果を見る' : '次の問題'),
        ),
      ],
    ];
  }

  List<Widget> _summary(BuildContext context) => [
    const Icon(Icons.check_circle_outline, size: 48, color: Palette.success),
    const SizedBox(height: 12),
    Text(
      '${_questions.length}問、おつかれさまでした',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Text('今回の正解は ${_draft.correct} / ${_questions.length}問です。'),
    const SizedBox(height: 20),
    const Text(
      '今回確認したこと',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
    for (final title
        in _questions
            .map((q) => (q['lesson'] as Map?)?['title'] ?? q['topic'])
            .toSet())
      Padding(padding: const EdgeInsets.only(top: 8), child: Text('・$title')),
    const SizedBox(height: 12),
    for (final q in _questions)
      ExpansionTile(
        leading: Icon(
          _draft.answers[q['id']]?['correct'] == true
              ? Icons.check_circle_outline
              : Icons.replay,
          color: Palette.primary,
        ),
        title: Text(q['statement'] as String),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: RichBody(
              _draft.answers[q['id']]?['explanation'] as String? ?? '',
            ),
          ),
        ],
      ),
    const SizedBox(height: 20),
    Text(
      _draft.correct < _questions.length
          ? '明日は、今回まちがえた問題から復習しましょう。ホームの「今日の復習3問」から続けられます。'
          : '明日もホームの「今日の復習3問」で確かめましょう。',
    ),
    const SizedBox(height: 20),
    if (AppScope.of(context).me?['pro'] != true) ...[
      const Text('10問の記録がたまると、自分の記録を使った学習プランを1回体験できます。'),
      const SizedBox(height: 8),
    ],
    OutlinedButton(
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'pro_analysis'),
          builder: (_) => const AnalysisScreen(),
        ),
      ),
      child: const Text('解いた記録と学習プランを見る'),
    ),
    TextButton(
      onPressed: () => openKakomon(context, set: _questions.first['chapterId'] as String, label: '問題を続ける'),
      child: const Text('もう少し問題を解く'),
    ),
    const SizedBox(height: 8),
    FilledButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('ホームに戻る'),
    ),
  ];
}
