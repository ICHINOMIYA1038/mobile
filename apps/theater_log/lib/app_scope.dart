import 'package:flutter/material.dart';

import 'account/auth_service.dart';
import 'account/log_sync.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'catalog/theater_log.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.catalog, required this.log, required this.auth, required this.sync, required super.child});
  final Catalog catalog;
  final TheaterLog log;
  final AuthService auth;
  final LogSync sync;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => catalog != oldWidget.catalog;
}
