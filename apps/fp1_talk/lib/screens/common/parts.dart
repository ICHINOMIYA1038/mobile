import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../theme.dart';
import '../items/item_set_screen.dart';
import '../kakomon/set_screen.dart';
import '../learn_screen.dart';

/// 章の会話を開く（ホーム・地図・復習・過去問から）。screen_view に残すためルート名を付ける。戻ると完了する。
/// pointId を渡すと、開いたらその論点の説明を頼む（過去問の「この論点を先生と学ぶ」）
Future<void> openChapter(BuildContext context, String chapterId, {String? pointId}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => LearnScreen(chapterId: chapterId, startPointId: pointId),
    settings: RouteSettings(name: 'learn_$chapterId'),
  ),
);

/// 過去問を解く画面を開く。set は回（2024）・科目（gyo）・章（ch01）・all。
/// fromChapter: 章の会話から開いたときのその章（その章の問題には「先生と学ぶ」を出さない）
Future<void> openKakomon(BuildContext context, {required String set, required String label, String mode = 'all', String? point, String? pointTitle, String? fromChapter}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    settings: RouteSettings(name: 'kakomon_$set'),
    builder: (_) => KakomonSetScreen(set: set, label: label, mode: mode, point: point, pointTitle: pointTitle, fromChapter: fromChapter),
  ),
);

/// 本試験形式の問題を解く画面を開く。set は回×編（2026-09-kiso）・章（ch04）・自分がまちがえた問（wrong）。startAt: 最初に出す問の位置
Future<void> openItems(BuildContext context, {required String set, required String label, int startAt = 0}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    settings: RouteSettings(name: 'items_$set'),
    builder: (_) => ItemSetScreen(set: set, label: label, startAt: startAt),
  ),
);

/// 通信の失敗を学習者向けの1文にする。サーバーの message があればそれを出す
String errorText(Object e) {
  if (e is ApiException && (e.message ?? '').isNotEmpty) return e.message!;
  return 'サーバーに接続できませんでした。通信環境を確認してもう一度お試しください。';
}

/// 細い進み具合の棒（サイトの .bar と同じ見た目）
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color = Palette.primary, this.height = 6});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          const Positioned.fill(child: ColoredBox(color: Palette.fillStrong)),
          // heightFactor が無いと Stack の中で高さ 0 になり、塗りが見えない
          FractionallySizedBox(
            widthFactor: value.isNaN ? 0 : value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ],
      ),
    ),
  );
}

/// 科目の見出し（「ライフプランニングと資金計画  基礎編 8問」）
class SubjectHeading extends StatelessWidget {
  const SubjectHeading({super.key, required this.name, required this.examQuestions});
  final String name;
  final int examQuestions;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Flexible(
        child: Text(
          name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink),
        ),
      ),
      const SizedBox(width: 8),
      Text('基礎編 $examQuestions問', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
    ],
  );
}

/// 読み込みに失敗したときの「もう一度」
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 40, color: Palette.inkFaint),
        const SizedBox(height: 12),
        Text(errorText(error), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('再試行')),
      ],
    ),
  );
}

/// Pro でない人に見せる「Pro」の印（鍵つき）
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: Palette.highlightSoft, border: Border.all(color: Palette.highlight), borderRadius: BorderRadius.circular(999)),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock, size: 12, color: Palette.warning),
        SizedBox(width: 3),
        Text('Pro', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.warning)),
      ],
    ),
  );
}
