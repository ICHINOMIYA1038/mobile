import 'dart:io';

import 'package:etude_generator/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ストア掲載用のスクリーンショットを撮る。
///
///   ./tool/screenshots.sh
///
/// 実行すると screenshots/ に書き出される。撮り直しが要るたびに手作業で撮ると、
/// 端末サイズごとに揃えるのが苦痛になり、更新もされなくなるため自動化している。
///
/// 撮影方法について: `binding.takeScreenshot()` は使わない。
/// iOS + Impeller ではこの API が実際の描画内容を無視して単色の背景しか返さない
/// 不具合があるうえ、`flutter drive` の拡張ドライバは screenshot をテスト完了後に
/// まとめて回収する仕組みのため、各ショットのタイミングと画面遷移が一致しない
/// （全ショットが最後の画面になる）。そこで、シミュレータの tmp
/// ディレクトリ（ホストからも同じパスで見える）にマーカーファイルを置き、
/// `tool/screenshots.sh` 側の常駐プロセスが `xcrun simctl io screenshot` で
/// 実画面をそのタイミングで撮る方式にしている。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// `tool/screenshots.sh` の常駐プロセスへ、今の画面を撮るよう頼む。
  ///
  /// システムの tmp ディレクトリはシミュレータでもホスト側から同じパスで
  /// 見えるため、マーカーファイルの置き場所として使える。相手が
  /// `<name>.request` を見つけて `xcrun simctl io screenshot` を実行し、
  /// `<name>.done` を置いたら完了とみなす。応答がなければ最大5秒で諦める
  /// （手元で `flutter test` 単体を動かす場合など、常駐プロセスがいなくても
  /// テスト自体は失敗させない）。
  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();

    final dir = Directory.systemTemp;
    final request = File('${dir.path}/shot_$name.request');
    final done = File('${dir.path}/shot_$name.done');
    if (done.existsSync()) done.deleteSync();
    request.writeAsStringSync('go');

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done.existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  testWidgets('ストア用スクリーンショット', (tester) async {
    // 1枚目: タイトル画面。キャッチコピーが主役。
    await tester.pumpWidget(const EtudeApp());
    await tester.pumpAndSettle();
    await shoot(tester, '01_home');

    // 2枚目: 生成画面。人数・ジャンル・時間の選択UIが並ぶ状態。
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3人'));
    await tester.tap(find.text('ミステリー'));
    await tester.tap(find.text('10分'));
    await tester.pumpAndSettle();
    await shoot(tester, '02_settings');

    // 3枚目: お題の結果画面。場所・状況・秘密・制約が出そろった状態。
    // カード見出しが画面上端付近に来る程度だけ手動でスクロールする
    // （ensureVisibleでボタンまで送るとカード上部の見出しが欠けてしまうため）。
    await tester.tap(find.text('お題をつくる'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await shoot(tester, '03_result');

    // 4枚目: 役を引く画面。自分だけに見せる役の内容（目的・秘密）。
    await tester.ensureVisible(find.text('このエチュードを実行する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('このエチュードを実行する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('一人目の役を引く'));
    await tester.pumpAndSettle();
    await shoot(tester, '04_role_draw');

    // 残りの役を引き終えて配役を完了させる。
    await tester.ensureVisible(find.text('次の人へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次の人へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('二人目の役を引く'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('次の人へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次の人へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('三人目の役を引く'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('配役完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('配役完了'));
    await tester.pumpAndSettle();

    // 5枚目: 実演画面。タイマーと、全員に見せてよい条件。
    await tester.ensureVisible(find.text('エチュードを始める'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('エチュードを始める'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await shoot(tester, '05_performance');

    // 6枚目: 振り返り画面。演じた後の問い。
    await tester.tap(find.text('終了する'));
    await tester.pumpAndSettle();
    await shoot(tester, '06_reflection');
  });
}
