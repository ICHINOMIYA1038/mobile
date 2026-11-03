import Accelerate
import AVFoundation

/// マイク入力をオクターブバンド別のレベル(A特性補正・Leq/ピーク)に変換する。
/// tapコールバックからは `append` のみ呼び、重いFFT処理は専用キューから
/// `processIfReady` で行う想定。
final class AudioSpectrumAnalyzer {
    struct BandResult {
        let centerHz: Double
        let leqDb: Double
        let peakDb: Double
        let minDb: Double
    }

    struct TimeSeriesPoint {
        let t: Double
        let db: Double
    }

    struct Result {
        let overallLeqDb: Double
        let overallPeakDb: Double
        let overallMinDb: Double
        let bands: [BandResult]
        let timeSeries: [TimeSeriesPoint]
    }

    static let bandCenters: [Double] = [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    /// 表示用のオフセット(LevelCalibration 共通値)。
    private static var displayOffsetDb: Double { LevelCalibration.offsetDb }
    private static let windowSize = 16384
    private static let hopSize = windowSize / 2

    /// FFT のパワー(片側ビンの |X|² の和)を、時間領域の平均パワー(RMS²)に戻す係数。
    /// vDSP の実数 FFT は真の DFT の2倍の値を返す(|X|² は4倍)。片側の和は Parseval で
    /// N/2·Σ(x·w)² = N²/2·mean(w²)·RMS²、hann(.hanningDenormalized)の mean(w²) は 3/8。
    /// 4 × N²/2 × 3/8 = 0.75·N²(N=16384 で 83.0dB)。1.1.1 まではこれで割っておらず、
    /// 結果が RMS 経路(InstantLevelMeter・ImpulseAnalyzer)より約83dB大きかった。
    /// Dart 側の保存済みの記録の換算(LevelScale)も同じ係数を使う。
    static let fftPowerScale = 0.75 * Double(windowSize) * Double(windowSize)

    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]
    private let bandBinRanges: [ClosedRange<Int>]
    private let aWeightGain: [Float]
    private let halfN: Int

    private let sampleRate: Double
    private let lock = NSLock()
    private var pendingSamples: [Float] = []
    /// 直近のFFT窓のA特性レベル(結果の時系列と同じ値)。最初の窓が揃うまでは nil。
    private var latestFrameDb: Double?

    private var bandPowerSum: [Double]
    private var bandPeakDb: [Double]
    private var bandMinDb: [Double]
    private var overallPowerSum: Double = 0
    private var overallPeakDb: Double = -.infinity
    private var overallMinDb: Double = .infinity
    private var frameCount: Int = 0
    private var samplesConsumed: Int = 0
    private var timeSeries: [TimeSeriesPoint] = []

    init?(sampleRate: Double) {
        self.sampleRate = sampleRate
        let log2n = vDSP_Length(log2(Double(Self.windowSize)))
        guard let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self) else {
            return nil
        }
        self.fft = fft
        self.window = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningDenormalized,
            count: Self.windowSize,
            isHalfWindow: false
        )

        let halfN = Self.windowSize / 2
        self.halfN = halfN
        let binHz = sampleRate / Double(Self.windowSize)

        var ranges: [ClosedRange<Int>] = []
        for center in Self.bandCenters {
            let lower = center / 2.0.squareRoot()
            let upper = center * 2.0.squareRoot()
            let lowIdx = max(1, Int((lower / binHz).rounded(.down)))
            let highIdx = min(halfN - 1, Int((upper / binHz).rounded(.up)))
            ranges.append(lowIdx...max(lowIdx, highIdx))
        }
        self.bandBinRanges = ranges

        // IEC 61672-1 A特性カーブ(振幅ゲイン)を各ビンについて事前計算しておく。
        var gains = [Float](repeating: 1, count: halfN)
        for bin in 1..<halfN {
            let f = Double(bin) * binHz
            let f2 = f * f
            let numerator = pow(12194.0, 2) * pow(f, 4)
            let denom = (f2 + pow(20.6, 2))
                * ((f2 + pow(107.7, 2)) * (f2 + pow(737.9, 2))).squareRoot()
                * (f2 + pow(12194.0, 2))
            let ra = numerator / denom
            let aDb = 20 * log10(ra) + 2.00
            gains[bin] = Float(pow(10.0, aDb / 20.0))
        }
        self.aWeightGain = gains

        self.bandPowerSum = [Double](repeating: 0, count: Self.bandCenters.count)
        self.bandPeakDb = [Double](repeating: -.infinity, count: Self.bandCenters.count)
        self.bandMinDb = [Double](repeating: .infinity, count: Self.bandCenters.count)
    }

    /// tapコールバックから呼ぶ。ロックを取ってメモリコピーするだけの軽量処理。
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        let samples = UnsafeBufferPointer(start: channelData[0], count: frameLength)

        lock.lock()
        pendingSamples.append(contentsOf: samples)
        lock.unlock()
    }

    /// 解析専用キューから定期的に呼ぶ。溜まったサンプルをFFT窓ごとに処理する。
    func processIfReady() {
        while true {
            lock.lock()
            guard pendingSamples.count >= Self.windowSize else {
                lock.unlock()
                return
            }
            let windowSamples = Array(pendingSamples[0..<Self.windowSize])
            pendingSamples.removeFirst(Self.hopSize)
            lock.unlock()

            processFrame(windowSamples)
        }
    }

    /// ライブメーター用の値。結果(Leq・時系列)と同じ物差しにするため、直近のFFT窓の
    /// A特性レベルをそのまま返す(以前は A特性なしの RMS で、結果と物差しが違っていた)。
    var latestOverallDb: Double? {
        lock.lock()
        defer { lock.unlock() }
        return latestFrameDb
    }

    func finalizeResult() -> Result {
        lock.lock()
        defer { lock.unlock() }
        guard frameCount > 0 else {
            let empty = Self.bandCenters.map { BandResult(centerHz: $0, leqDb: 0, peakDb: 0, minDb: 0) }
            return Result(overallLeqDb: 0, overallPeakDb: 0, overallMinDb: 0, bands: empty, timeSeries: [])
        }
        let overallLeq = dbFromPower(overallPowerSum / Double(frameCount))
        var bands: [BandResult] = []
        for (i, center) in Self.bandCenters.enumerated() {
            let leq = dbFromPower(bandPowerSum[i] / Double(frameCount))
            let peak = bandPeakDb[i].isFinite ? bandPeakDb[i] : leq
            let min = bandMinDb[i].isFinite ? bandMinDb[i] : leq
            bands.append(BandResult(centerHz: center, leqDb: leq, peakDb: peak, minDb: min))
        }
        let overallPeak = overallPeakDb.isFinite ? overallPeakDb : overallLeq
        let overallMin = overallMinDb.isFinite ? overallMinDb : overallLeq
        return Result(
            overallLeqDb: overallLeq,
            overallPeakDb: overallPeak,
            overallMinDb: overallMin,
            bands: bands,
            timeSeries: timeSeries
        )
    }

    /// 帯域パワー(FFT のビンの和)→ dB。fftPowerScale で割って RMS 経路と同じ物差しにする。
    private func dbFromPower(_ power: Double) -> Double {
        10 * log10(max(power / Self.fftPowerScale, 1e-12)) + Self.displayOffsetDb
    }

    private func processFrame(_ rawSamples: [Float]) {
        var windowed = [Float](repeating: 0, count: Self.windowSize)
        vDSP.multiply(rawSamples, window, result: &windowed)

        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        var magnitudes = [Float](repeating: 0, count: halfN)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { windowedPtr in
                    windowedPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
                    }
                }
                fft.forward(input: splitComplex, output: &splitComplex)
                magnitudes.withUnsafeMutableBufferPointer { magPtr in
                    vDSP_zvabs(&splitComplex, 1, magPtr.baseAddress!, 1, vDSP_Length(halfN))
                }
            }
        }

        // A特性は振幅の段階で先に掛け、パワー(振幅の2乗)に変換してからバンドへ合算する。
        var weighted = [Float](repeating: 0, count: halfN)
        vDSP.multiply(magnitudes, aWeightGain, result: &weighted)
        var power = [Float](repeating: 0, count: halfN)
        vDSP.multiply(weighted, weighted, result: &power)

        lock.lock()
        var frameOverallPower: Double = 0
        for (i, range) in bandBinRanges.enumerated() {
            var bandPower: Float = 0
            for bin in range where bin < halfN {
                bandPower += power[bin]
            }
            let bandPowerD = Double(bandPower)
            bandPowerSum[i] += bandPowerD
            let bandDb = dbFromPower(bandPowerD)
            if bandDb > bandPeakDb[i] { bandPeakDb[i] = bandDb }
            if bandDb < bandMinDb[i] { bandMinDb[i] = bandDb }
            frameOverallPower += bandPowerD
        }
        overallPowerSum += frameOverallPower
        let overallDb = dbFromPower(frameOverallPower)
        if overallDb > overallPeakDb { overallPeakDb = overallDb }
        if overallDb < overallMinDb { overallMinDb = overallDb }
        let t = Double(samplesConsumed) / sampleRate
        timeSeries.append(TimeSeriesPoint(t: t, db: overallDb))
        latestFrameDb = overallDb
        samplesConsumed += Self.hopSize
        frameCount += 1
        lock.unlock()
    }
}
