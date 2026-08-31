import Accelerate
import Foundation

/// 衝撃音(ノック・手叩き)の解析ロジック。Flutter にも AVAudioEngine にも依存しない
/// 純粋な計算だけにしてあり、`tool/impulse_lab` の CLI から WAV ファイルで
/// 同じコードを検証できる(ここを変えたら CLI で再検証すること)。
enum ImpulseAnalyzer {
    /// 表示用のオフセット(LevelCalibration 共通値)。
    static var displayOffsetDb: Double { LevelCalibration.offsetDb }

    static let preRollSeconds = 0.05
    static let captureSeconds = 1.2
    static let envelopeFrameSeconds = 0.010

    /// 立ち上がり検出のチャンク長(サンプル)。5ms@48kHz。
    static let detectionChunk = 256

    struct Result {
        let peakDb: Double
        let floorDb: Double
        let t10: Double?
        let t20: Double?
        let rt60: Double?
        let spectralCentroidHz: Double
        let lowShare: Double
        let highShare: Double
        let peakHz: Double
        let envelope: [Double]

        var snrDb: Double { peakDb - floorDb }

        var payload: [String: Any] {
            [
                "peakDb": peakDb,
                "floorDb": floorDb,
                "snrDb": snrDb,
                "t10": t10 as Any,
                "t20": t20 as Any,
                "rt60": rt60 as Any,
                "spectralCentroidHz": spectralCentroidHz,
                "lowShare": lowShare,
                "highShare": highShare,
                "peakHz": peakHz,
                "envelope": envelope,
            ]
        }
    }

    static func db(fromPower power: Double) -> Double {
        10 * log10(max(power, 1e-12)) + displayOffsetDb
    }

    /// 切り出し済みのクリップを解析する。
    /// - clip: 立ち上がりの preRoll 前から captureSeconds 分のサンプル
    /// - onsetInClip: clip 内での立ち上がり位置
    /// - floorDb: 立ち上がり前に測った暗騒音(表示オフセット込み)
    static func analyze(clip: [Float], onsetInClip: Int, sampleRate: Double, floorDb: Double) -> Result? {
        guard !clip.isEmpty, onsetInClip >= 0, onsetInClip < clip.count else { return nil }

        let frame = max(1, Int(envelopeFrameSeconds * sampleRate))
        var envelope: [Double] = []
        var i = 0
        while i + frame <= clip.count {
            var rms: Float = 0
            clip.withUnsafeBufferPointer { p in
                vDSP_rmsqv(p.baseAddress! + i, 1, &rms, vDSP_Length(frame))
            }
            envelope.append(db(fromPower: Double(rms) * Double(rms)))
            i += frame
        }
        guard let peakIdx = envelope.indices.max(by: { envelope[$0] < envelope[$1] }) else { return nil }
        let peakDb = envelope[peakIdx]

        // ピークから -10dB / -20dB まで落ちるのにかかった時間。
        // 暗騒音の床に埋もれる手前(床+6dB)までしか信用しない。
        let usableFloor = floorDb + 6
        func decayTime(dropDb: Double) -> Double? {
            let target = peakDb - dropDb
            guard target > usableFloor else { return nil }
            for j in peakIdx..<envelope.count where envelope[j] <= target {
                return Double(j - peakIdx) * envelopeFrameSeconds
            }
            return nil
        }
        let t10 = decayTime(dropDb: 10)
        let t20 = decayTime(dropDb: 20)
        // T20 があれば ×3、無ければ T10 ×6 で RT60 を外挿する。
        let rt60: Double? = t20.map { $0 * 3 } ?? t10.map { $0 * 6 }

        // 立ち上がり直後 4096 サンプル(約85ms@48kHz)のスペクトル。
        let fftSize = 4096
        var spec = [Float](repeating: 0, count: fftSize)
        let available = min(fftSize, clip.count - onsetInClip)
        if available > 0 {
            for k in 0..<available { spec[k] = clip[onsetInClip + k] }
        }
        let (centroid, lowShare, highShare, peakHz) = spectrum(of: spec, sampleRate: sampleRate)

        return Result(
            peakDb: peakDb,
            floorDb: floorDb,
            t10: t10,
            t20: t20,
            rt60: rt60,
            spectralCentroidHz: centroid,
            lowShare: lowShare,
            highShare: highShare,
            peakHz: peakHz,
            envelope: envelope
        )
    }

    /// 立ち上がり検出。チャンク(detectionChunk = 256サンプル ≈ 5ms)ごとのパワーを流し込む。
    /// 軽いノックは数ms の短い衝撃なので、長いチャンクの RMS だと薄まって閾値に届かない。
    ///
    /// 床(暗騒音)は「最初のn秒の平均」ではなく、直近 historySeconds のチャンクの
    /// 下位 floorPercentile を使う。こうすると、待機直後に叩いてしまった場合や
    /// 床測定中に物音がした場合でも、静かな瞬間が少しでもあれば床が正しく出る。
    /// 立ち上がりの条件は「床+threshold を超える」かつ「直近数チャンクの最小値から
    /// riseDb 以上跳ね上がる」の両方(定常的にうるさいだけの環境で誤検出しないため)。
    struct OnsetDetector {
        let thresholdDb: Double
        let riseDb: Double
        let historySeconds: Double
        let floorPercentile: Double
        let minHistorySeconds: Double
        let chunkSeconds: Double

        private var history: [Double] = []
        /// 直近数チャンクの dB。立ち上がりがチャンク境界をまたいでも拾えるよう、
        /// 直前1つではなく直近 riseWindow 個の最小値からの上昇で判定する。
        private var recentDb: [Double] = []
        /// 上昇判定の参照窓(約60ms分のチャンク数)。
        private let riseWindow: Int

        init(
            sampleRate: Double,
            chunkSize: Int,
            thresholdDb: Double = 12,
            riseDb: Double = 6,
            historySeconds: Double = 1.0,
            floorPercentile: Double = 0.2,
            minHistorySeconds: Double = 0.15
        ) {
            self.thresholdDb = thresholdDb
            self.riseDb = riseDb
            self.historySeconds = historySeconds
            self.floorPercentile = floorPercentile
            self.minHistorySeconds = minHistorySeconds
            self.chunkSeconds = Double(chunkSize) / sampleRate
            self.riseWindow = max(3, Int(0.06 / self.chunkSeconds))
        }

        /// 直近履歴から求めた床のパワー(線形)。履歴が無ければ nil。
        var floorPower: Double? {
            guard !history.isEmpty else { return nil }
            let sorted = history.sorted()
            let idx = min(sorted.count - 1, Int(Double(sorted.count) * floorPercentile))
            return sorted[idx]
        }

        var floorDb: Double? { floorPower.map { ImpulseAnalyzer.db(fromPower: $0) } }

        /// チャンクのパワーを渡す。立ち上がりならtrue。
        /// 立ち上がりと判定したチャンクは履歴に入れない(床を汚さない)。
        mutating func push(power: Double) -> Bool {
            let frameDb = 10 * log10(max(power, 1e-12))
            let enough = Double(history.count) * chunkSeconds >= minHistorySeconds
            if enough, let floor = floorPower {
                let floorDb = 10 * log10(max(floor, 1e-12))
                let rose = recentDb.min().map { frameDb - $0 >= riseDb } ?? true
                if frameDb - floorDb >= thresholdDb && rose {
                    return true
                }
            }
            history.append(power)
            let maxCount = Int(historySeconds / chunkSeconds)
            if history.count > maxCount { history.removeFirst(history.count - maxCount) }
            recentDb.append(frameDb)
            if recentDb.count > riseWindow { recentDb.removeFirst() }
            return false
        }
    }

    /// 録音全体に対して、プラグインと同じ流れをオフラインで再現する。
    /// CLI・テスト用。戻り値は解析結果と立ち上がり位置(サンプル)。
    static func runOffline(
        samples: [Float],
        sampleRate: Double,
        onsetThresholdDb: Double = 12,
        chunk: Int = detectionChunk
    ) -> (Result, Int)? {
        var detector = OnsetDetector(sampleRate: sampleRate, chunkSize: chunk, thresholdDb: onsetThresholdDb)
        var onset: Int?
        var i = 0
        while i < samples.count {
            let n = min(chunk, samples.count - i)
            var rms: Float = 0
            samples.withUnsafeBufferPointer { p in
                vDSP_rmsqv(p.baseAddress! + i, 1, &rms, vDSP_Length(n))
            }
            if detector.push(power: Double(rms) * Double(rms)) {
                onset = i
                break
            }
            i += n
        }
        guard let onset, let floorDb = detector.floorDb else { return nil }
        let pre = Int(preRollSeconds * sampleRate)
        let from = max(0, onset - pre)
        let to = min(samples.count, onset + Int(captureSeconds * sampleRate))
        let clip = Array(samples[from..<to])
        guard let result = analyze(clip: clip, onsetInClip: onset - from, sampleRate: sampleRate, floorDb: floorDb) else {
            return nil
        }
        return (result, onset)
    }

    /// 戻り値: (スペクトル重心Hz, 500Hz未満のパワー比, 2kHz超のパワー比, 最大ピークHz)
    static func spectrum(of frame: [Float], sampleRate: Double) -> (Double, Double, Double, Double) {
        let n = frame.count
        let halfN = n / 2
        let log2n = vDSP_Length(log2(Double(n)))
        guard let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self) else {
            return (0, 0, 0, 0)
        }
        let window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: n, isHalfWindow: false)
        var windowed = [Float](repeating: 0, count: n)
        vDSP.multiply(frame, window, result: &windowed)
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        var power = [Float](repeating: 0, count: halfN)
        real.withUnsafeMutableBufferPointer { r in
            imag.withUnsafeMutableBufferPointer { im in
                var split = DSPSplitComplex(realp: r.baseAddress!, imagp: im.baseAddress!)
                windowed.withUnsafeBufferPointer { w in
                    w.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { c in
                        vDSP_ctoz(c, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
                fft.forward(input: split, output: &split)
                power.withUnsafeMutableBufferPointer { p in
                    vDSP_zvmags(&split, 1, p.baseAddress!, 1, vDSP_Length(halfN))
                }
            }
        }
        let binHz = sampleRate / Double(n)
        var total = 0.0, weighted = 0.0, low = 0.0, high = 0.0
        var peakBin = 1
        // 20Hz未満と8kHz超はノック/手叩きの評価に不要なので外す。
        let minBin = max(1, Int(20 / binHz))
        let maxBin = min(halfN - 1, Int(8000 / binHz))
        for bin in minBin...maxBin {
            let p = Double(power[bin])
            let f = Double(bin) * binHz
            total += p
            weighted += p * f
            if f < 500 { low += p }
            if f > 2000 { high += p }
            if power[bin] > power[peakBin] { peakBin = bin }
        }
        guard total > 0 else { return (0, 0, 0, 0) }
        return (weighted / total, low / total, high / total, Double(peakBin) * binHz)
    }
}
