import 'package:flutter/material.dart';

import '../funnel.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common/parts.dart';
import 'pro/plan_preview_screen.dart';

class StudyNextStepCard extends StatefulWidget {
  const StudyNextStepCard({super.key, required this.userId, this.chapterId});
  final String userId;
  final String? chapterId;

  @override
  State<StudyNextStepCard> createState() => _StudyNextStepCardState();
}

class _StudyNextStepCardState extends State<StudyNextStepCard> {
  // 体験 API は異なる10問への解答を条件とし、タップ時にもサーバーで確認する。
  static const _minimumAnswers = 10;
  Map<String, dynamic>? _home;
  bool _loading = true;
  bool _failed = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StudyNextStepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    final api = AppScope.read(context).api;
    final userId = widget.userId;
    if (api.userId != userId) return;
    setState(() {
      _home = null;
      _loading = true;
      _failed = false;
    });
    try {
      final home = await api.home();
      if (mounted && widget.userId == userId && api.userId == userId) {
        setState(() => _home = home);
      }
    } catch (_) {
      if (mounted && widget.userId == userId && api.userId == userId) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && widget.userId == userId) setState(() => _loading = false);
    }
  }

  String _nextSet() {
    final progress = _home?['progress'] as Map?;
    final chapters = ((progress?['chapters'] as List?) ?? const [])
        .whereType<Map>();
    final remaining = chapters.where(
      (c) => (c['total'] as num? ?? 0) > (c['seen'] as num? ?? 0),
    );
    final preferred = remaining
        .where((c) => c['chapterId'] == widget.chapterId)
        .firstOrNull;
    final next = preferred ?? remaining.firstOrNull;
    return next?['chapterId'] as String? ?? 'all';
  }

  Future<void> _open({required bool preview, int? answered}) async {
    if (_opening || AppScope.read(context).api.userId != widget.userId) return;
    setState(() => _opening = true);
    Funnel.event(
      'study_next_step_open',
      parameters: {
        'action': preview ? 'preview' : 'unanswered',
        'answered': ?answered,
      },
    );
    try {
      if (preview) {
        await PlanPreviewScreen.show(context);
      } else {
        await openKakomon(
          context,
          set: _nextSet(),
          label: '続きの問題',
          mode: 'new',
        );
      }
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.api.userId != widget.userId ||
        state.me?['pro'] == true ||
        _home?['pro'] == true) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('プラン体験までの記録を確認しています。'),
      );
    }
    if (!_failed && _home?['study'] is! Map) {
      return TextButton(
        onPressed: _opening ? null : () => _open(preview: false),
        child: const Text('まだ解いていない問題を解く'),
      );
    }
    final seen = (_home?['progress'] as Map?)?['seen'];
    final answered = seen is num && seen.isFinite && seen >= 0
        ? seen.toInt()
        : null;
    final eligible = answered != null && answered >= _minimumAnswers;
    return Card(
      color: Palette.primarySoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              eligible ? 'あなたの学習プランを体験できます' : '次の学習を、あなたの記録から',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (answered != null) ...[
              Text(
                eligible
                    ? '異なる$answered問に答えました。あなたの記録を使った1日分のプランを見られます。'
                    : '異なる$answered問に答えました。あと${_minimumAnswers - answered}問で、1日分の学習プランを体験できます。',
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (answered / _minimumAnswers).clamp(0, 1),
                semanticsLabel: eligible
                    ? '学習プラン体験の条件に達しました'
                    : '学習プラン体験までの記録、$answered問 / $_minimumAnswers問',
              ),
            ] else ...[
              const Text('記録を確認できませんでした。問題を続けるか、もう一度読み込んでください。'),
              TextButton(
                onPressed: _opening ? null : _load,
                child: const Text('記録を再取得'),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _opening
                  ? null
                  : () => _open(preview: eligible, answered: answered),
              child: Text(eligible ? '1日分の学習プランを体験' : 'まだ解いていない問題を解く'),
            ),
            if (eligible)
              TextButton(
                onPressed: _opening
                    ? null
                    : () => _open(preview: false, answered: answered),
                child: const Text('続けて問題を解く'),
              ),
            const SizedBox(height: 8),
            const Text(
              'プラン体験だけで支払いは発生しません。',
              style: TextStyle(fontSize: 13, color: Palette.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
