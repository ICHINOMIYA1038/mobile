import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/data/sound_meter_service.dart';
import 'package:sound_shield/ui/screens/home_screen.dart';

void main() {
  testWidgets('既定では時間指定モードで計測時間の選択肢が見える', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(soundMeterService: SoundMeterService())),
    );

    expect(find.text('計測時間'), findsOneWidget);
    expect(find.text('15秒'), findsOneWidget);
    expect(find.text('止めるまで測定'), findsOneWidget);
  });

  testWidgets('「止めるまで測定」を選ぶと計測時間の選択肢が消える', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(soundMeterService: SoundMeterService())),
    );

    await tester.tap(find.text('止めるまで測定'));
    await tester.pump();

    expect(find.text('計測時間'), findsNothing);
    expect(find.text('15秒'), findsNothing);
    expect(find.textContaining('「計測終了」を押すまで'), findsOneWidget);
  });
}
