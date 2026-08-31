import 'package:flutter/widgets.dart';

import 'ar_noise_map_service.dart';
import 'calibration_repository.dart';
import 'impulse_probe_service.dart';
import 'inspection_repository.dart';
import 'sound_meter_service.dart';

/// アプリ全体で共有するサービス群。画面からは `AppScope.of(context)` で取る。
class AppServices {
  AppServices({
    required this.soundMeter,
    required this.impulseProbe,
    required this.arNoiseMap,
    required this.inspections,
    required this.calibration,
  });

  final SoundMeterService soundMeter;
  final ImpulseProbeService impulseProbe;
  final ArNoiseMapService arNoiseMap;
  final InspectionRepository inspections;
  final CalibrationRepository calibration;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope が見つかりません');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
