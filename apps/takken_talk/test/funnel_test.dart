import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/funnel.dart';
import 'package:takken_talk/state/app_state.dart';
import 'package:takken_talk/widgets/cap_notice.dart';

void main() {
  group('Funnel', () {
    late List<(String, Map<String, Object>?)> logged;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      logged = [];
      Funnel.log = (name, {parameters}) async => logged.add((name, parameters));
    });

    test('最初の1往復は端末ごとに1回だけ記録する', () async {
      await Funnel.chatCompleted('learn');
      await Funnel.chatCompleted('explain');
      expect(logged, hasLength(1));
      expect(logged.single.$1, 'first_chat_sent');
      expect(logged.single.$2, {'surface': 'learn'});
    });

    test('上限に当たるたびに記録する', () {
      Funnel.capReached('learn', 'user_cap');
      Funnel.capReached('explain', 'global_cap');
      expect(logged.map((e) => e.$2?['code']), ['user_cap', 'global_cap']);
    });
  });

  group('上限から Pro を開いて戻ったとき', () {
    Future<void> tapOpen(WidgetTester tester, AppState state, Future<void> Function() onOpen, VoidCallback onPro) async {
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => openProFromCap(context, onPro: onPro, open: (_, _) => onOpen()),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pump();
    }

    testWidgets('Pro になっていれば止まっていた送信を戻す', (tester) async {
      final state = AppState(ApiClient())..me = {'pro': false};
      var resumed = 0;
      await tapOpen(tester, state, () async => state.me = {'pro': true}, () => resumed++);
      expect(resumed, 1);
    });

    testWidgets('買わずに戻ったら止めたまま', (tester) async {
      final state = AppState(ApiClient())..me = {'pro': false};
      var resumed = 0;
      await tapOpen(tester, state, () async {}, () => resumed++);
      expect(resumed, 0);
    });
  });
}
