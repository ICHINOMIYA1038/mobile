import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fp1_talk/api/client.dart';
import 'package:fp1_talk/main.dart';
import 'package:fp1_talk/screens/items/item_set_screen.dart';
import 'package:fp1_talk/screens/pro/mock_result_screen.dart';
import 'package:fp1_talk/state/app_state.dart';

// 模擬試験の時間切れ: 「答えを出しますか？」や問の一覧が開いたまま時間が切れても、結果の画面へ進み、戻れば元の画面に戻れる。
// 手元のサイト（AI はモック）と Pro の学習者で（作り方は fp1_pro_test.dart の頭）:
//   flutter test integration_test/mock_timeup_test.dart -d <UDID> --dart-define=API_BASE=http://localhost:3130 --dart-define=PRO_TOKEN=<token> --dart-define=PRO_USER=<userId>
const _proToken = String.fromEnvironment('PRO_TOKEN');
const _proUser = String.fromEnvironment('PRO_USER');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final opener in ['mock-submit', 'mock-list']) {
    testWidgets('時間切れのとき $opener が開いていても、結果へ進んで戻れる', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ps_token', _proToken);
      await prefs.setString('ps_user_id', _proUser);
      final state = AppState(ApiClient());
      await tester.pumpWidget(AppScope(state: state, child: const App()));
      await state.init();
      await settle(tester, 4);
      expect(state.me?['pro'], isTrue);

      // 本物の模擬試験を始め、締め切りだけ 8 秒後に縮める（採点はサーバーで本物）
      final exam = await state.api.startMock('kiso');
      final now = DateTime.now().millisecondsSinceEpoch;
      final short = {...exam, 'now': now, 'deadline': now + 8000};
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute<void>(builder: (_) => ItemSetScreen.mock(mock: short, label: '基礎編')));
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('option-1')).first);
      await settle(tester, 1);
      await tester.tap(find.byKey(Key(opener)));
      await settle(tester, 1);
      // 開いたまま時間切れを待つ
      await settle(tester, 12);
      expect(find.byType(MockResultScreen), findsOneWidget, reason: '結果の画面へ進む');
      expect(find.byType(AlertDialog), findsNothing);
      nav.pop();
      await settle(tester, 2);
      expect(find.byType(ItemSetScreen), findsNothing, reason: '戻ると模擬試験の画面は残っていない');
      expect(find.text('カリキュラム'), findsOneWidget, reason: 'ホームに戻る');
      expect(tester.takeException(), isNull);
    });
  }
}
