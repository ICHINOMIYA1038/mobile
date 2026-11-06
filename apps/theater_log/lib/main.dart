import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'account/auth_service.dart';
import 'account/log_sync.dart';
import 'app_scope.dart';

import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'catalog/theater_log.dart';
import 'firebase_options.dart';
import 'catalog/productions.dart';
import 'pon_sound.dart';
import 'screens/feed_screen.dart';
import 'screens/log_screen.dart';
import 'screens/stamp_book_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);
  final repository = CatalogRepository();
  final catalog = await repository.load();
  final log = TheaterLog();
  await log.load();
  final auth = AuthService();
  await auth.restore();
  runApp(App(repository: repository, catalog: catalog, log: log, auth: auth));
}

class App extends StatefulWidget {
  const App({super.key, required this.repository, required this.catalog, required this.log, required this.auth});
  final CatalogRepository repository;
  final Catalog catalog;
  final TheaterLog log;
  final AuthService auth;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late Catalog _catalog = widget.catalog;
  late final LogSync _sync = LogSync(auth: widget.auth, log: widget.log);
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    PonSound.prepare();
    ProductionStore.instance.load();
    widget.log.onDirty = _sync.run;
    _lifecycle = AppLifecycleListener(onResume: _sync.run);
    _sync.run();
    widget.auth.refreshProfile();
    widget.repository.refresh().then((fresh) {
      if (fresh != null && mounted) setState(() => _catalog = fresh);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    catalog: _catalog,
    log: widget.log,
    auth: widget.auth,
    sync: _sync,
    child: MaterialApp(
      title: 'ゲキポン',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // 画面遷移を screen_view として記録する。RouteSettings.name を付けたルートだけが記録される
      navigatorObservers: AppInsights.navigatorObservers,
      home: const Shell(),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  static const _names = ['log', 'feed', 'stamps'];
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    AppInsights.logScreen(_names[0]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [LogScreen(), FeedScreen(), StampBookScreen()]),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: LogScreen.immersive,
        builder: (context, immersive, _) => _CurtainNavigation(
          dark: immersive && _tab == 0,
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            setState(() => _tab = i);
            AppInsights.logScreen(_names[i]);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.local_activity_outlined), selectedIcon: Icon(Icons.local_activity), label: '半券帳'),
            NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'みんな'),
            NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified), label: 'スタンプ'),
          ],
        ),
      ),
    );
  }
}

/// 下のタブ。選んでいるタブの上に、定式幕の縞を引く
class _CurtainNavigation extends StatelessWidget {
  const _CurtainNavigation({required this.dark, required this.selectedIndex, required this.onDestinationSelected, required this.destinations});
  /// 半券帳の写真表示の下では、黒い帯にして写真から続けて見せる
  final bool dark;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final bar = NavigationBar(selectedIndex: selectedIndex, onDestinationSelected: onDestinationSelected, destinations: destinations);
    if (dark) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(
          navigationBarTheme: theme.navigationBarTheme.copyWith(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : Colors.white54)),
            labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? Colors.white : Colors.white54)),
          ),
        ),
        child: bar,
      );
    }
    return _light(bar);
  }

  Widget _light(Widget bar) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Divider(height: 1, thickness: 1),
      LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth / destinations.length;
          return SizedBox(
            height: 4,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: w * selectedIndex + w * 0.28,
                  width: w * 0.44,
                  top: 0,
                  bottom: 0,
                  child: const JoshikiStripe(),
                ),
              ],
            ),
          );
        },
      ),
      bar,
    ],
  );
}
