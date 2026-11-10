import 'package:flutter/material.dart';

import '../../funnel.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/readable.dart';
import '../common/parts.dart';
import '../pro_screen.dart';
import 'analysis_logic.dart';
import 'plan_tasks.dart';

class PlanPreviewScreen extends StatefulWidget {
  const PlanPreviewScreen({super.key});

  static Future<void> show(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'pro_plan_preview'),
          builder: (_) => const PlanPreviewScreen(),
        ),
      );

  @override
  State<PlanPreviewScreen> createState() => _PlanPreviewScreenState();
}

class _PlanPreviewScreenState extends State<PlanPreviewScreen> {
  Map<String, dynamic>? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await AppScope.read(context).api.proPreview();
      if (!mounted) return;
      setState(() => _data = data);
      Funnel.event(
        'pro_preview_viewed',
        parameters: {
          'ai': (data['plan'] as Map?)?['ai'] == true ? 1 : 0,
          'version': 1,
        },
      );
    } catch (e) {
      Funnel.event('pro_preview_failed');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('学習プランを体験')),
      body: data == null
          ? Center(
              child: _error != null
                  ? LoadError(error: _error!, onRetry: _load)
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('解いた記録から、学習プランを作っています。'),
                      ],
                    ),
            )
          : Readable(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: _body(data),
              ),
            ),
    );
  }

  List<Widget> _body(Map<String, dynamic> data) {
    final report = (data['report'] as Map).cast<String, dynamic>();
    final plan = (data['plan'] as Map).cast<String, dynamic>();
    final week = ((plan['week'] as List?) ?? const []).cast<Map>();
    final tasks = week.isEmpty
        ? <Map<String, dynamic>>[]
        : taskList(week.first.cast<String, dynamic>());
    final created = DateTime.fromMillisecondsSinceEpoch(
      (data['createdAt'] as num).toInt(),
    );
    final createdDay = jstDay(created);
    final isPro = AppScope.of(context).me?['pro'] == true;
    return [
      const Text(
        'あなたの記録で作った、1日分の学習プラン',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text('作成日：$createdDay。この体験結果はあとからも読み返せます。'),
      const SizedBox(height: 20),
      Text('${report['answered']}問に取り組み、正答率は${pct(report['accuracy'])}でした。'),
      const SizedBox(height: 8),
      const Text(
        '解いた範囲の振り返りです。合格可能性の判定ではありません。',
        style: TextStyle(fontSize: 13, color: Palette.inkSoft),
      ),
      for (final s in ((report['subjects'] as List?) ?? const []).cast<Map>())
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s['label'] as String),
          trailing: Text('${s['answered']}問・${pct(s['accuracy'])}'),
        ),
      const SizedBox(height: 12),
      const Text(
        '次に取り組むこと',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      if (plan['ai'] != true) ...[
        const SizedBox(height: 8),
        const Text(
          'AI のプランを用意できなかったため、解答記録から作った簡易プランを表示しています。',
          style: TextStyle(fontSize: 13, color: Palette.inkSoft),
        ),
      ],
      for (final task in tasks)
        Card(
          child: ListTile(
            leading: Icon(taskIcon(task['type'] as String?)),
            title: Text(task['text'] as String),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Funnel.event('pro_preview_task_open');
              startTask(context, task);
            },
          ),
        ),
      const SizedBox(height: 20),
      const Text('Pro では、解答記録の変化に合わせてプランを作り直せます。7日分の予定、詳しい苦手分析、模擬試験も使えます。'),
      const SizedBox(height: 12),
      if (!isPro)
        FilledButton(
          onPressed: () => ProScreen.show(context, reason: 'preview'),
          child: const Text('Pro の内容と月額料金を見る'),
        ),
      const SizedBox(height: 8),
      const Text(
        'この体験だけで支払いは発生しません。Pro の購入は別途 App Store で確認します。',
        style: TextStyle(fontSize: 13, color: Palette.inkSoft),
      ),
    ];
  }
}
