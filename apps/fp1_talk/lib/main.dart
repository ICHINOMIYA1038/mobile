import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import 'ads/ad_service.dart';
import 'api/client.dart';
import 'firebase_options.dart';
import 'screens/figure_library_screen.dart';
import 'screens/home_screen.dart';
import 'screens/items_screen.dart';
import 'screens/review_screen.dart';
import 'screens/settings_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  // Firebase に未登録のあいだ（firebase_options.dart が null）は計測を始めない
  final firebase = DefaultFirebaseOptions.currentPlatform;
  if (firebase != null) await AppInsights.initialize(options: firebase);
  // 起動してすぐは全画面広告を出さないため、時刻だけ覚える（広告の SDK は最初の広告まで起動しない）
  AdService.instance.markLaunched();
  final state = AppState(ApiClient());
  runApp(AppScope(state: state, child: const App()));
  state.init();
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pAIrOf FP1級',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // 画面遷移を screen_view として記録する。RouteSettings.name を付けたルートだけが
      // 記録されるので、画面を追加したら名前も必ず付けること。
      navigatorObservers: AppInsights.navigatorObservers,
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  /// 一度ホームを読めたら、学習データの削除などで取り直しているあいだもタブを出したままにする（知らせが消えないように）
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.home != null) _ready = true;
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: state.error != null && !state.loading
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 40),
                      const SizedBox(height: 12),
                      const Text('サーバーに接続できませんでした。\n通信環境を確認してもう一度お試しください。', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: state.init, child: const Text('再試行')),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    return const Shell();
  }
}

/// 下のタブ: 学ぶ / 本試験形式 / 復習 / 図解 / 設定（学習の地図は「学ぶ」から開く）。
/// FP1 の過去問は本試験と同じ答え方（四答択一・空欄・計算）で解く「本試験形式」タブ。宅建アプリの○×の過去問タブは置かない
/// （FP1 には○×の過去問が無い。○×は会話の中の確認と復習で使う）
class Shell extends StatefulWidget {
  const Shell({super.key});

  /// ほかの画面からタブを切り替える（例: 復習の「過去問を解く」）
  static void select(BuildContext context, int index) => context.findAncestorStateOfType<_ShellState>()?.select(index);

  /// 上に重ねた画面（苦手分析など、タブの外）からタブを切り替える。重ねた画面は閉じる（例: 予定の「復習」）
  static void show(BuildContext context, int index) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    _live?.select(index);
  }

  static _ShellState? _live;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  static const _names = ['home', 'items', 'review', 'figures', 'settings'];

  @override
  void initState() {
    super.initState();
    Shell._live = this;
  }

  @override
  void dispose() {
    if (Shell._live == this) Shell._live = null;
    super.dispose();
  }

  void select(int i) {
    setState(() => _tab = i);
    AppInsights.logEvent('tab', parameters: {'name': _names[i]});
    // 復習・ホームは開くたびに新しい記録で描く
    if (i == 0 || i == 2) AppScope.read(context).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [HomeScreen(), ItemsScreen(), ReviewScreen(), FigureLibraryScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: '学ぶ'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: '本試験形式'),
          NavigationDestination(icon: Icon(Icons.replay_outlined), selectedIcon: Icon(Icons.replay), label: '復習'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '図解'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}
