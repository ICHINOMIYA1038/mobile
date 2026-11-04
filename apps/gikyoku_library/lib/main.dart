import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';

import 'app_scope.dart';
import 'catalog/shortlist.dart';
import 'firebase_options.dart';
import 'screens/search_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);
  final repository = CatalogRepository();
  final catalog = await repository.load();
  final shortlist = Shortlist();
  await shortlist.load();
  runApp(App(repository: repository, catalog: catalog, shortlist: shortlist));
}

class App extends StatefulWidget {
  const App({super.key, required this.repository, required this.catalog, required this.shortlist});
  final CatalogRepository repository;
  final Catalog catalog;
  final Shortlist shortlist;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late Catalog _catalog = widget.catalog;

  @override
  void initState() {
    super.initState();
    AppInsights.logScreen('search');
    widget.repository.refresh().then((fresh) {
      if (fresh != null && mounted) setState(() => _catalog = fresh);
    });
  }

  @override
  Widget build(BuildContext context) => AppScope(
    catalog: _catalog,
    shortlist: widget.shortlist,
    child: MaterialApp(
      title: '戯曲図書館',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // 画面遷移を screen_view として記録する。RouteSettings.name を付けたルートだけが記録される
      navigatorObservers: AppInsights.navigatorObservers,
      home: const Scaffold(body: SearchScreen()),
    ),
  );
}
