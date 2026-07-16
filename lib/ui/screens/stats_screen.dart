import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/purchase_repository.dart';
import '../../logic/study_controller.dart';
import '../../main.dart';
import '../../models/question.dart';

/// プライバシーポリシーの公開URL。
/// **公開前に実際のURLへ差し替えること。** App Store / Play の双方で提出必須で、
/// アプリ内からも到達できる必要がある。原文は docs/privacy-policy.md。
const privacyPolicyUrl = 'https://pairof.jp/takken/privacy';

/// 問い合わせ先。誤った法令解説の報告を受けるための窓口でもある。
/// **公開前に実際のURLかmailtoへ差し替えること。**
const supportUrl = 'https://pairof.jp/takken/support';

/// 成績画面。数字は「本試験で今何点取れそうか」に寄せる。学習量そのものは目的ではない。
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StudyScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('成績')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _ScoreCard(controller: controller),
            const SizedBox(height: 24),
            Text(
              '科目別の到達度',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'バーの長さは本試験の配点比率です。長い科目ほど多く出題します。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ...controller.categoryStats.map((s) => _CategoryRow(stats: s)),
            const SizedBox(height: 28),
            const _RemoveAdsSection(),
            const SizedBox(height: 28),
            _DataSection(controller: controller),
            const SizedBox(height: 28),
            const _AboutSection(),
          ],
        ),
      ),
    );
  }
}

/// 法的な導線とバージョン表示。
/// プライバシーポリシーへアプリ内から到達できることは App Store の審査要件。
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'このアプリについて',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '問題と解説は正確を期していますが、法令改正等により最新でない場合があります。'
          '実際の判断は必ず法令の原文をご確認ください。誤りを見つけたらお知らせください。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            children: [
              TextButton(
                onPressed: () => _open(context, privacyPolicyUrl),
                child: const Text('プライバシーポリシー'),
              ),
              TextButton(
                onPressed: () => _open(context, supportUrl),
                child: const Text('問い合わせ・誤りの報告'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const _VersionLabel(),
      ],
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);

    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('ページを開けませんでした')));
    }
  }
}

/// バージョンとビルド番号。不具合報告のときに要る情報。
class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 問題数は実データから取る。書き換え忘れで嘘の数字を出さないため。
    final total = StudyScope.of(context).totalQuestions;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Text(
          info == null
              ? '収録 $total問'
              : '収録 $total問 ・ バージョン ${info.version} (${info.buildNumber})',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

/// 予想得点。他アプリが出す「正答率○%」より、合格まであと何点かの方が行動につながる。
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.controller});

  final StudyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = controller.predictedScore;
    final answered = controller.answeredCount;

    // 合格ラインは年により概ね33〜38点で変動するため、余裕を見て36点を目安にする。
    const target = 36;
    final reached = score >= target;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        child: Column(
          children: [
            Text(
              '本試験の配点で換算した予想得点',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: score.toStringAsFixed(1),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  TextSpan(
                    text: ' / 50点',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              answered == 0
                  ? 'まだ回答がありません'
                  : reached
                      ? '合格ラインの目安（36点）に届いています'
                      : '合格ラインの目安まであと ${(target - score).toStringAsFixed(1)}点',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$answered問 回答済み ・ ${controller.masteredCount}問 定着',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            // 数字の意味を明示する。解いていない範囲を「取れる」と誤解させない。
            Text(
              'まだ解いていない問題は0点として計算しています。解くほど実力に近づきます。',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 科目バー。幅を配点比率に比例させ、「宅建業法が一番大事」を見た目で分からせる。
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.stats});

  final CategoryStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(stats.category.label, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(
                '本試験${stats.category.weight}問',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                stats.answered == 0
                    ? '—'
                    : '正答率 ${(stats.accuracy * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 外側の幅＝配点比率、内側の塗り＝その科目の定着率。
          FractionallySizedBox(
            widthFactor: stats.category.ratio / Category.gyoho.ratio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: stats.masteryRatio,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(scheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${stats.total}問中 ${stats.mastered}問 定着',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 広告削除の購入と復元。
///
/// 広告はもともと結果画面にしか出さないため、これは「広告を消す」というより
/// 開発を支える任意の支援に近い。煽らず、買わなくても全問解けることを明記する。
/// なお「購入の復元」は App Store の審査で必須要件。
class _RemoveAdsSection extends StatelessWidget {
  const _RemoveAdsSection();

  @override
  Widget build(BuildContext context) {
    final purchases = PurchaseScope.of(context);
    final theme = Theme.of(context);

    if (purchases.adsRemoved) {
      return Row(
        children: [
          Icon(Icons.verified_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '広告削除を購入済みです。ありがとうございます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final price = purchases.priceLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '広告について',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '広告は結果画面にのみ表示され、出題中と解説中には表示しません。'
          '購入しなくても全ての問題を制限なく解けます。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: purchases.purchasePending ? null : () => _buy(context),
          child: Text(
            purchases.purchasePending
                ? '処理中…'
                : price == null
                    ? '広告を削除する'
                    : '広告を削除する（$price）',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: purchases.purchasePending ? null : () => _restore(context),
          child: const Text('購入を復元する'),
        ),
      ],
    );
  }

  Future<void> _buy(BuildContext context) async {
    final purchases = PurchaseScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await purchases.buyRemoveAds();

    final message = switch (outcome) {
      PurchaseOutcome.purchased => '広告を削除しました',
      PurchaseOutcome.unavailable => 'この端末では購入できません',
      PurchaseOutcome.error => '購入を開始できませんでした',
      _ => null,
    };
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(BuildContext context) async {
    final purchases = PurchaseScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await purchases.restore();

    final message = switch (outcome) {
      PurchaseOutcome.unavailable => 'この端末では復元できません',
      PurchaseOutcome.error => '復元できませんでした',
      _ => '購入情報を確認しています',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// データの持ち出しと初期化。ユーザーが自分のデータを取り戻せる状態にしておく。
class _DataSection extends StatelessWidget {
  const _DataSection({required this.controller});

  final StudyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '学習データ',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'データは端末内にのみ保存され、外部には送信されません。機種変更に備えて書き出せます。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('学習データを書き出す'),
          onPressed: () => _export(context),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('学習データを読み込む'),
          onPressed: () => _import(context),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _reset(context),
          child: Text(
            '学習履歴をすべて消す',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    final json = await controller.progressRepository.exportJson();
    if (!context.mounted) return;

    await Share.share(json, subject: 'シンプルに学ぶ宅建アプリ 学習データ');
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (raw == null || raw.isEmpty) return;

    final ok = await controller.importProgress(raw);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '学習データを読み込みました' : '読み込めませんでした。書き出したデータか確認してください'),
      ),
    );
  }

  Future<void> _reset(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('学習履歴をすべて消しますか？'),
        content: const Text('正誤の記録と復習の予定がすべて消えます。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '消す',
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await controller.resetProgress();
    messenger.showSnackBar(const SnackBar(content: Text('学習履歴を消しました')));
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('学習データを読み込む'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('書き出したデータを貼り付けてください。現在の履歴は上書きされます。'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 5,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '{ "app": ... }',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.paste_rounded, size: 16),
              label: const Text('クリップボードから貼り付け'),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text;
                if (text != null) _controller.text = text;
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('読み込む'),
        ),
      ],
    );
  }
}
