import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/notification_service.dart';
import 'data/progress_repository.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // リマインダーは毎日繰り返す1件の予約だが、OSの都合で消えることがあるため
  // 起動のたびに予約し直す。
  unawaited(_rescheduleReminderIfEnabled());
  runApp(const NekoChemistryApp());
}

Future<void> _rescheduleReminderIfEnabled() async {
  try {
    final repo = ProgressRepository();
    if (!await repo.loadNotificationsEnabled()) return;
    final minutes = await repo.loadReminderMinutes();
    await NotificationService().scheduleDailyReminder(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );
  } catch (_) {
    // 起動を止めない。
  }
}

class NekoChemistryApp extends StatelessWidget {
  const NekoChemistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '猫と学ぶ高校化学',
      debugShowCheckedModeBanner: false,
      // 時刻ピッカー等の標準ウィジェットを日本語にする。
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja')],
      locale: const Locale('ja'),
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const _AppRoot(),
      builder: (context, child) {
        // 端末の文字サイズ設定を尊重しつつ、レイアウトが壊れる倍率までは許さない。
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );
      },
    );
  }
}

/// 初回起動かどうかでオンボーディングかメイン画面のどちらを見せるか決める。
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ProgressRepository().hasSeenOnboarding(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const AppShell() : const OnboardingScreen();
      },
    );
  }
}
