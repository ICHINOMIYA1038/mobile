import 'package:flutter/material.dart';

import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'catalog/shortlist.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.catalog, required this.shortlist, required super.child});
  final Catalog catalog;
  final Shortlist shortlist;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => catalog != oldWidget.catalog;
}
