import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../widgets/readable.dart';
import '../widgets/exam_date.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  DateTime _examDate = nextExamDate();
  bool _saving = false;

  Future<void> _start() async {
    final state = AppScope.of(context);
    setState(() => _saving = true);
    try {
      await state.api.patchMe(examDate: formatDate(_examDate));
      await state.refresh();
    } catch (_) {
      // 試験日は後から設定でも変えられるので、失敗しても先に進む
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen(), settings: const RouteSettings(name: 'home')),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Readable(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('話して受かる宅建', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('AIの先生と会話しながら、宅建の全範囲を少しずつ身につけます。\n読むだけの勉強より、「自分の言葉で説明する」勉強のほうが残ります。',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 28),
              const _Bullet(icon: Icons.chat_bubble_outline, text: '先生が短く説明 → あなたが説明し返す → ○×で確認'),
              const _Bullet(icon: Icons.image_outlined, text: '比較表や流れ図を、その場で図解カードで見せます'),
              const _Bullet(icon: Icons.replay, text: '間違えた問題は忘れた頃にもう一度出ます'),
              const _Bullet(icon: Icons.trending_up, text: '合格見込みスコアが会話するたびに動きます'),
              const SizedBox(height: 22),
              const _Curriculum(),
              const Spacer(),
              Text('試験日', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _examDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (d != null) setState(() => _examDate = d);
                },
                icon: const Icon(Icons.event),
                label: Text('${formatDateJa(_examDate)}（あと${daysUntil(_examDate)}日）'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _start,
                child: Text(_saving ? '準備中…' : '第1章を無料で始める'),
              ),
              const SizedBox(height: 8),
              Text('第1章（免許・宅建士・保証制度）は無料。第2章以降はProまたは会話パックで続けられます。',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), textAlign: TextAlign.center),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// 何を学ぶのかを最初に1枚で示す。配点の大きい順に並べていることが伝わればよい。
class _Curriculum extends StatelessWidget {
  const _Curriculum();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = AppScope.of(context).me;
    final subjects = me?.subjects ?? const <Subject>[];
    if (subjects.isEmpty) return const SizedBox.shrink();
    final chapters = me!.chapters.length;
    final topics = me.chapters.fold<int>(0, (a, c) => a + c.topics.length);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('学ぶ範囲（本試験50問）', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final s in subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text('${s.examQuestions}問',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  ),
                  Expanded(child: Text(s.name, style: theme.textTheme.bodySmall)),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: s.examQuestions / 20,
                        minHeight: 5,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text('全$chapters章・$topicsテーマ。配点の大きい宅建業法から始めます。',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
