import 'dart:math' as math;

/// 騒音レベルの物差しの版。
///
/// 1.1.1 までの `AudioSpectrumAnalyzer`(結果の Leq・帯域・時系列)は FFT のパワーを
/// 0.75·N²(N=16384, hann 窓と vDSP の倍率)で割っておらず、RMS 経路より約83dB大きかった。
/// 1.1.2 で割るようにしたので、それより前に保存した絶対値の dB は読み込むときに
/// [legacyFftOffsetDb] だけ下げる(係数は Swift の `AudioSpectrumAnalyzer.fftPowerScale` と同じ)。
class LevelScale {
  const LevelScale._();

  static const _fftWindowSize = 16384;

  /// 10·log10(0.75·16384²) ≈ 83.04dB。古い物差しの値から引く量。
  static final double legacyFftOffsetDb =
      10 * math.log(0.75 * _fftWindowSize * _fftWindowSize) / math.ln10;
}
