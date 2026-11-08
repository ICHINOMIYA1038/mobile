import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theater_log/account/auth_service.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/main.dart';

import 'fake_photo.dart';

/// 半券帳の写真表示を通す（中身は動作確認用の仮のデータ）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('写真のある 1 本、写真のない 1 本、一覧', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const hold = Duration(seconds: 5);
    final photo = await fakeStagePhoto();
    final repository = CatalogRepository();
    final log = TheaterLog();
    await log.upsert(TheaterLogEntry(id: 'b', title: '動作確認の長い題名の舞台', watchedOn: DateTime(2026, 10, 12), venue: '仮の劇場', rating: 3));
    await log.upsert(TheaterLogEntry(id: 'a', title: '動作確認の舞台', watchedOn: DateTime(2026, 11, 3), showTime: 'soiree', venue: '仮の劇場', seat: '2階B列3番', rating: 4, note: '動作確認用の仮の感想です。最後の場面まで表示を確かめます。', photos: [photo]));
    await tester.pumpWidget(App(repository: repository, catalog: await repository.load(), log: log, auth: AuthService()));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);

    await tester.tapAt(const Offset(350, 400));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);

    await tester.tap(find.byKey(const Key('log-view-toggle')));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);
  });
}
