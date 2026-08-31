import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/data/app_scope.dart';
import 'package:sound_shield/data/ar_noise_map_service.dart';
import 'package:sound_shield/data/impulse_probe_service.dart';
import 'package:sound_shield/data/calibration_repository.dart';
import 'package:sound_shield/data/inspection_repository.dart';
import 'package:sound_shield/data/sound_meter_service.dart';
import 'package:sound_shield/ui/screens/meter_screen.dart';

Widget _wrap(Widget child) {
  return AppScope(
    services: AppServices(
      soundMeter: SoundMeterService(),
      impulseProbe: ImpulseProbeService(),
      arNoiseMap: ArNoiseMapService(),
      inspections: InspectionRepository(),
      calibration: CalibrationRepository(soundMeter: SoundMeterService()),
    ),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('既定では時間指定モードで計測時間の選択肢が見える', (tester) async {
    await tester.pumpWidget(_wrap(const MeterScreen()));

    expect(find.text('計測時間'), findsOneWidget);
    expect(find.text('15秒'), findsOneWidget);
    expect(find.text('止めるまで測定'), findsOneWidget);
  });

  testWidgets('「止めるまで測定」を選ぶと計測時間の選択肢が消える', (tester) async {
    await tester.pumpWidget(_wrap(const MeterScreen()));

    await tester.tap(find.text('止めるまで測定'));
    await tester.pump();

    expect(find.text('計測時間'), findsNothing);
    expect(find.text('15秒'), findsNothing);
    expect(find.textContaining('「計測終了」を押すまで'), findsOneWidget);
  });
}
