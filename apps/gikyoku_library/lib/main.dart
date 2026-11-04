import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'account/auth_service.dart';
import 'account/log_sync.dart';
import 'app_scope.dart';
import 'catalog/catalog_repository.dart';
import 'catalog/models.dart';
import 'catalog/shortlist.dart';
import 'catalog/theater_log.dart';
import 'firebase_options.dart';
import 'screens/feed_screen.dart';
import 'screens/log_screen.dart';
import 'screens/search_screen.dart';
import 'screens/stamp_book_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);
  final repository = CatalogRepository();
  final catalog = await repository.load();
  final shortlist = Shortlist();
  await shortlist.load();
  final log = TheaterLog();
  await log.load();
  final auth = AuthService();
  await auth.restore();
  runApp(App(repository: repository, catalog: catalog, shortlist: shortlist, log: log, auth: auth));
}

class App extends StatefulWidget {
  const App({super.key, required this.repository, required this.catalog, required this.shortlist, required this.log, required this.auth});
  final CatalogRepository repository;
  final Catalog catalog;
  final Shortlist shortlist;
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
    widget.log.onDirty = _sync.run;
    _lifecycle = AppLifecycleListener(onResume: _sync.run);
    _sync.run();
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
    shortlist: widget.shortlist,
    log: widget.log,
    auth: widget.auth,
    sync: _sync,
    child: MaterialApp(
      title: '戯曲図書館',
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
  static const _names = ['log', 'feed', 'search', 'stamps'];
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    AppInsights.logScreen(_names[0]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [LogScreen(), FeedScreen(), SearchScreen(), StampBookScreen()]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            setState(() => _tab = i);
            AppInsights.logScreen(_names[i]);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.local_activity_outlined), selectedIcon: Icon(Icons.local_activity), label: '半券帳'),
            NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'みんな'),
            NavigationDestination(icon: Icon(Icons.search), label: '台本'),
            NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified), label: 'スタンプ'),
          ],
      ),
    );
  }
}
