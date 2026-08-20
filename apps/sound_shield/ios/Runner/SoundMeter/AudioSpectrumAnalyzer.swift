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

    // キャリブレーションをしていないため絶対SPLではなく相対値(dBFS)になる。
    // 見慣れたレンジ(概ね30〜90)に寄せるための固定オフセット。
    private static let displayOffsetDb: Double = 90.0
    private static let windowSize = 16384
    private static let hopSize = windowSize / 2

    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]
    private let bandBinRanges: [ClosedRange<Int>]
    private let aWeightGain: [Float]
    private let halfN: Int

    private let sampleRate: Double
    private let lock = NSLock()
    private var pendingSamples: [Float] = []
    private var latestRms: Float = 0

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

        var rms: Float = 0
        vDSP_rmsqv(samples.baseAddress!, 1, &rms, vDSP_Length(frameLength))

        lock.lock()
        pendingSamples.append(contentsOf: samples)
        latestRms = rms
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

    /// 直近バッファのRMSから求めた簡易dB値(ライブメーター用、A特性補正なし)。
    var latestOverallDb: Double {
        lock.lock()
        let rms = latestRms
        lock.unlock()
        return dbFromPower(Double(rms) * Double(rms))
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

    private func dbFromPower(_ power: Double) -> Double {
        10 * log10(max(power, 1e-12)) + Self.displayOffsetDb
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
        samplesConsumed += Self.hopSize
        frameCount += 1
        lock.unlock()
    }
}
