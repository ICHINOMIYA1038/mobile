import 'package:flutter/material.dart';

import 'catalog/models.dart';
import 'catalog/shortlist.dart';
import 'catalog/theater_log.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.catalog, required this.shortlist, required this.log, required super.child});
  final Catalog catalog;
  final Shortlist shortlist;
  final TheaterLog log;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => catalog != oldWidget.catalog;
}
