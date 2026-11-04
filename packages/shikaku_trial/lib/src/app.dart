import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : <Map<String, dynamic>>[];
String _string(Object? value) => value?.toString() ?? '';

class QualificationApp extends StatefulWidget {
  const QualificationApp({
    super.key,
    required this.title,
    required this.exam,
    required this.color,
    this.apiBase = const String.fromEnvironment(
      'API_BASE',
      defaultValue: 'https://shikaku.pairof.jp',
    ),
  });

  final String title;
  final String exam;
  final Color color;
  final String apiBase;

  @override
  State<QualificationApp> createState() => _QualificationAppState();
}

class _QualificationAppState extends State<QualificationApp> {
  late final TrialApi api = TrialApi(
    exam: widget.exam,
    baseUrl: widget.apiBase,
  );
  late Future<Map<String, dynamic>> home = api.home();
  int tab = 0;
  int itemsVersion = 0;
  int reviewVersion = 0;

  Future<void> refreshHome() async {
    setState(() => home = api.home());
    try {
      await home;
    } catch (_) {}
  }

  Future<void> deleteLearningData() async {
    await api.deleteLearningData();
    setState(() {
      home = api.home();
      itemsVersion++;
      reviewVersion++;
      tab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.title,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: widget.color),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: IndexedStack(
          index: tab,
          children: [
            _Home(api: api, home: home, refresh: refreshHome),
            _Items(key: ValueKey(itemsVersion), api: api),
            _Review(key: ValueKey(reviewVersion), api: api),
            _Settings(onDelete: deleteLearningData),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (index) {
            setState(() {
              tab = index;
              if (index == 1) itemsVersion++;
              if (index == 2) reviewVersion++;
            });
            if (index == 0) refreshHome();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              label: '学ぶ',
            ),
            NavigationDestination(
              icon: Icon(Icons.quiz_outlined),
              label: '練習問題',
            ),
            NavigationDestination(
              icon: Icon(Icons.replay_outlined),
              label: '復習',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: '設定',
            ),
          ],
        ),
      ),
    );
  }
}

class _Load extends StatelessWidget {
  const _Load({required this.future, required this.builder, this.retry});
  final Future<Map<String, dynamic>> future;
  final Widget Function(Map<String, dynamic>) builder;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('読み込めませんでした'),
                const SizedBox(height: 8),
                if (retry != null)
                  TextButton(onPressed: retry, child: const Text('再試行')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return builder(snapshot.data!);
      },
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.api, required this.home, required this.refresh});
  final TrialApi api;
  final Future<Map<String, dynamic>> home;
  final Future<void> Function() refresh;

  @override
  Widget build(BuildContext context) {
    return _Load(
      future: home,
      retry: refresh,
      builder: (data) {
        final chapters = _list(data['chapters']);
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _string(_map(data['exam'])['name']).isNotEmpty
                    ? _string(_map(data['exam'])['name'])
                    : '学習する章を選ぶ',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('試作版です。教材と学習機能を確認しています。'),
                ),
              ),
              Text('${chapters.length}章から選んで学習できます。'),
              const SizedBox(height: 12),
              for (final chapter in chapters)
                Card(
                  child: ListTile(
                    title: Text(_string(chapter['title'])),
                    subtitle: Text(_string(chapter['goal'])),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _Lesson(
                            api: api,
                            id: _string(chapter['id']),
                            title: _string(chapter['title']),
                          ),
                        ),
                      );
                      await refresh();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Lesson extends StatefulWidget {
  const _Lesson({required this.api, required this.id, required this.title});
  final TrialApi api;
  final String id;
  final String title;

  @override
  State<_Lesson> createState() => _LessonState();
}

class _LessonState extends State<_Lesson> {
  late Future<Map<String, dynamic>> data = widget.api.learn(widget.id);
  final input = TextEditingController();
  final messages = <String>[];
  bool busy = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> ask() async {
    final message = input.text.trim();
    if (message.isEmpty || busy) return;
    input.clear();
    setState(() {
      busy = true;
      messages.add('自分: $message');
      messages.add('先生: ');
    });
    final replyIndex = messages.length - 1;
    try {
      await for (final event in widget.api.chat(widget.id, message)) {
        if (!mounted) return;
        if (event['type'] == 'text') {
          setState(() => messages[replyIndex] += _string(event['delta']));
        } else if (event['type'] == 'error') {
          setState(() => messages[replyIndex] += _string(event['message']));
        }
      }
    } catch (_) {
      if (mounted) setState(() => messages[replyIndex] += '返答を受け取れませんでした。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: _Load(
              future: data,
              retry: () => setState(() => data = widget.api.learn(widget.id)),
              builder: (loaded) {
                final chapter = _map(loaded['chapter']);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_string(chapter['goal']).isNotEmpty)
                      Text(_string(chapter['goal'])),
                    const SizedBox(height: 12),
                    for (final topic in _list(chapter['topics'])) ...[
                      Text(
                        _string(topic['title']),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final point in _list(topic['points']))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _string(point['title']),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(_string(point['summary'])),
                              ],
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _Questions(
                            api: widget.api,
                            set: widget.id,
                            title: '${widget.title}の○×',
                          ),
                        ),
                      ),
                      child: const Text('この章の○×を解く'),
                    ),
                    for (final message in messages)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(message),
                      ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      decoration: const InputDecoration(hintText: '先生に質問する'),
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : ask,
                    icon: const Icon(Icons.send),
                    tooltip: '送信',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Questions extends StatefulWidget {
  const _Questions({required this.api, required this.set, required this.title});
  final TrialApi api;
  final String set;
  final String title;

  @override
  State<_Questions> createState() => _QuestionsState();
}

class _QuestionsState extends State<_Questions> {
  late Future<Map<String, dynamic>> data = widget.api.questions(widget.set);
  final results = <String, Map<String, dynamic>>{};
  bool sending = false;

  Future<void> answer(String id, bool value) async {
    if (sending) return;
    setState(() => sending = true);
    try {
      final result = await widget.api.answer(id, value);
      if (mounted) setState(() => results[id] = result);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('採点できませんでした')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: _Load(
      future: data,
      retry: () => setState(() => data = widget.api.questions(widget.set)),
      builder: (loaded) {
        final entries = _list(loaded['items']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (entries.isEmpty) const Text('この章の問題は準備中です。'),
            for (final entry in entries)
              Builder(
                builder: (context) {
                  final question = _map(entry['question']).isEmpty
                      ? entry
                      : _map(entry['question']);
                  final id = _string(question['id']);
                  final result = results[id];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_string(question['statement'])),
                          const SizedBox(height: 8),
                          if (result == null)
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: sending
                                      ? null
                                      : () => answer(id, true),
                                  child: const Text('○ 正しい'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: sending
                                      ? null
                                      : () => answer(id, false),
                                  child: const Text('× 誤り'),
                                ),
                              ],
                            )
                          else ...[
                            Text(
                              result['correct'] == true ? '正解' : '不正解',
                              style: TextStyle(
                                color: result['correct'] == true
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            Text(_string(result['explanation'])),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    ),
  );
}

class _Items extends StatefulWidget {
  const _Items({super.key, required this.api});
  final TrialApi api;
  @override
  State<_Items> createState() => _ItemsState();
}

class _ItemsState extends State<_Items> {
  late Future<Map<String, dynamic>> data = widget.api.items();

  @override
  Widget build(BuildContext context) => _Load(
    future: data,
    retry: () => setState(() => data = widget.api.items()),
    builder: (loaded) {
      final chapters = _list(loaded['chapters']);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('章別の練習問題'),
          if (chapters.isEmpty) const Text('練習問題は準備中です。'),
          for (final chapter in chapters)
            Card(
              child: ListTile(
                title: Text(_string(chapter['label'])),
                subtitle: Text('${chapter['total'] ?? 0}問'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ItemSet(
                        api: widget.api,
                        keyName: _string(chapter['key']),
                        title: _string(chapter['label']),
                      ),
                    ),
                  );
                  if (mounted) setState(() => data = widget.api.items());
                },
              ),
            ),
        ],
      );
    },
  );
}

class _ItemSet extends StatefulWidget {
  const _ItemSet({
    required this.api,
    required this.keyName,
    required this.title,
  });
  final TrialApi api;
  final String keyName;
  final String title;
  @override
  State<_ItemSet> createState() => _ItemSetState();
}

class _ItemSetState extends State<_ItemSet> {
  late Future<Map<String, dynamic>> data = widget.api.itemSet(widget.keyName);
  final results = <String, Map<String, dynamic>>{};
  bool sending = false;

  Future<void> answer(String id, int choice) async {
    if (sending) return;
    setState(() => sending = true);
    try {
      final result = await widget.api.itemAnswer(id, choice);
      if (mounted) setState(() => results[id] = result);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('採点できませんでした')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: _Load(
      future: data,
      retry: () => setState(() => data = widget.api.itemSet(widget.keyName)),
      builder: (loaded) {
        final items = _list(loaded['items']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (items.isEmpty) const Text('この章の練習問題は準備中です。'),
            for (final item in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _string(item['stem']),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_string(item['material']).isNotEmpty)
                        Text(_string(item['material'])),
                      for (final (index, option)
                          in (item['options'] is List
                                  ? item['options'] as List
                                  : const [])
                              .indexed)
                        ListTile(
                          title: Text('${index + 1}. $option'),
                          onTap:
                              results.containsKey(_string(item['id'])) ||
                                  sending
                              ? null
                              : () => answer(_string(item['id']), index + 1),
                        ),
                      if (results[_string(item['id'])] case final result?) ...[
                        Text(result['correct'] == true ? '正解' : '不正解'),
                        Text('正解: ${result['answer'] ?? ''}'),
                        Text(_string(result['explanation'])),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _Review extends StatefulWidget {
  const _Review({super.key, required this.api});
  final TrialApi api;
  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  late Future<Map<String, dynamic>> data = widget.api.review();
  final results = <String, Map<String, dynamic>>{};

  Future<void> answer(String id, bool value) async {
    try {
      final result = await widget.api.answer(id, value, via: 'review');
      if (mounted) setState(() => results[id] = result);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('採点できませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) => _Load(
    future: data,
    retry: () => setState(() => data = widget.api.review()),
    builder: (loaded) {
      final groups = [
        ('bookmarks', 'あとで復習'),
        ('wrong', 'まちがえた問題'),
        ('due', '復習の時期'),
      ];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (key, title) in groups) ...[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (_list(loaded[key]).isEmpty) const Text('問題はありません。'),
            for (final entry in _list(loaded[key]))
              Builder(
                builder: (context) {
                  final question = _map(entry['question']);
                  final id = _string(question['id']);
                  final result = results[id];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_string(question['statement'])),
                          if (result == null)
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => answer(id, true),
                                  child: const Text('○ 正しい'),
                                ),
                                TextButton(
                                  onPressed: () => answer(id, false),
                                  child: const Text('× 誤り'),
                                ),
                              ],
                            )
                          else ...[
                            Text(result['correct'] == true ? '正解' : '不正解'),
                            Text(_string(result['explanation'])),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      );
    },
  );
}

class _Settings extends StatefulWidget {
  const _Settings({required this.onDelete});

  final Future<void> Function() onDelete;

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  bool deleting = false;

  Future<void> openLink(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ページを開けませんでした')));
    }
  }

  Future<void> deleteData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('学習データを削除'),
        content: const Text('このアプリの学習記録をすべて削除します。元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    try {
      await widget.onDelete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('学習データを削除しました')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除できませんでした。通信環境を確認してください')),
        );
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('このアプリについて', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('資格学習アプリの試作版です。'),
      const SizedBox(height: 16),
      ListTile(
        title: const Text('プライバシーポリシー'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => openLink('https://shikaku.pairof.jp/privacy'),
      ),
      ListTile(
        title: const Text('利用規約'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => openLink('https://shikaku.pairof.jp/terms'),
      ),
      const Divider(),
      ListTile(
        title: const Text('学習データを削除'),
        subtitle: const Text('このアプリの学習記録を消します'),
        trailing: deleting ? const CircularProgressIndicator() : null,
        onTap: deleting ? null : deleteData,
      ),
    ],
  );
}
