/// 開発・テスト用のモックエンジン。ネイティブが無い環境(Simulatorや解析)で UI を動かす。
library;

import 'dart:async';

import '../models/score.dart';
import 'doremi_engine.dart';

class MockDoremiEngine implements DoremiEngine {
  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<RecognizedScore> recognize(
    String imagePath, {
    void Function(RecognizeProgress)? onProgress,
  }) async {
    for (final p in [
      const RecognizeProgress(RecognizePhase.preparing, 0.1),
      const RecognizeProgress(RecognizePhase.detectingStaves, 0.4),
      const RecognizeProgress(RecognizePhase.recognizing, 0.8),
      const RecognizeProgress(RecognizePhase.rendering, 0.95),
    ]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      onProgress?.call(p);
    }
    const names = ['ド', 'レ', 'ミ', 'ファ', 'ミ', 'レ', 'ド'];
    final notes = <DoremiNote>[];
    for (var row = 0; row < 2; row++) {
      for (var i = 0; i < names.length; i++) {
        notes.add(DoremiNote(
          ruby: names[i],
          pitch: 'C4',
          xFrac: (i + 0.5) / names.length,
          yFrac: 0.2 + row * 0.3,
          duration: 'quarter',
        ));
      }
    }
    return RecognizedScore(
      sourceImagePath: imagePath,
      imageWidth: 1000,
      imageHeight: 1400,
      elapsedMs: 1200,
      notes: notes,
    );
  }
}
