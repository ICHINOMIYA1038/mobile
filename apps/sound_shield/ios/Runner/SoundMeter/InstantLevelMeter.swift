import Accelerate
import AVFoundation

/// 表示レベルの校正。dBFS(相対値)を騒音計らしい数字に寄せる共通オフセット。
///
/// 既定の 100 dB は市販の騒音計との比較(2026-08-29, iPhone 実機)による目安。
/// ユーザーが設定画面で手持ちの騒音計に合わせると `userAdjustmentDb` が変わる
/// (SoundMeterPlugin の setCalibration で反映。保存は Flutter 側が持つ)。
/// iOS はマイク感度が機種間でほぼ揃っている(NIOSH の実測で機種間平均差 ≈2dB)ため、
/// 機種別テーブルは持たず「既定+ユーザー校正」の1本で扱う。
enum LevelCalibration {
    static let defaultOffsetDb: Double = 100.0

    /// ユーザー校正(基準騒音計との差)。計測開始前に設定される前提。
    static var userAdjustmentDb: Double = 0

    static var offsetDb: Double { defaultOffsetDb + userAdjustmentDb }
}

/// マイク入力の「今この瞬間」のレベルを返す軽量メーター。
/// ARマップのように位置と同期して短い間隔でサンプリングする用途向けで、
/// 累積Leqを持つ AudioSpectrumAnalyzer とは別物。
///
/// tapコールバック内で 4096 サンプル(48kHzで約85ms)ごとに RMS と
/// 3帯域(低: <500Hz / 中 / 高: >2kHz)のパワーを計算して保持する。
final class InstantLevelMeter {
    struct Level {
        let overallDb: Double
        let lowDb: Double
        let midDb: Double
        let highDb: Double
    }

    static var displayOffsetDb: Double { LevelCalibration.offsetDb }
    private static let fftSize = 4096

    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]
    private let halfN: Int
    private let binHz: Double
    private let lock = NSLock()
    private var latest = Level(overallDb: 0, lowDb: 0, midDb: 0, highDb: 0)
    private var scratch: [Float] = []

    init?(sampleRate: Double) {
        let log2n = vDSP_Length(log2(Double(Self.fftSize)))
        guard let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self) else {
            return nil
        }
        self.fft = fft
        self.window = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningDenormalized,
            count: Self.fftSize,
            isHalfWindow: false
        )
        self.halfN = Self.fftSize / 2
        self.binHz = sampleRate / Double(Self.fftSize)
    }

    var latestLevel: Level {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }

    /// tapコールバックから呼ぶ。
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        let samples = UnsafeBufferPointer(start: channelData[0], count: frameLength)

        scratch.append(contentsOf: samples)
        guard scratch.count >= Self.fftSize else { return }
        let frame = Array(scratch.suffix(Self.fftSize))
        scratch.removeAll(keepingCapacity: true)

        var rms: Float = 0
        frame.withUnsafeBufferPointer { ptr in
            vDSP_rmsqv(ptr.baseAddress!, 1, &rms, vDSP_Length(Self.fftSize))
        }

        var windowed = [Float](repeating: 0, count: Self.fftSize)
        vDSP.multiply(frame, window, result: &windowed)
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        var power = [Float](repeating: 0, count: halfN)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { wPtr in
                    wPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cPtr in
                        vDSP_ctoz(cPtr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
                fft.forward(input: split, output: &split)
                power.withUnsafeMutableBufferPointer { pPtr in
                    vDSP_zvmags(&split, 1, pPtr.baseAddress!, 1, vDSP_Length(halfN))
                }
            }
        }

        let lowMax = Int(500.0 / binHz)
        let highMin = Int(2000.0 / binHz)
        var low: Float = 0
        var mid: Float = 0
        var high: Float = 0
        for bin in 1..<halfN {
            if bin <= lowMax {
                low += power[bin]
            } else if bin >= highMin {
                high += power[bin]
            } else {
                mid += power[bin]
            }
        }
        // FFTのパワーはサンプル数でスケールされるので、RMSベースの全体値と
        // 同じ土俵に乗るよう正規化する(厳密な一致は不要、帯域間の相対比較が目的)。
        let norm = Double(Self.fftSize) * Double(Self.fftSize) / 4.0
        let level = Level(
            overallDb: Self.db(fromPower: Double(rms) * Double(rms)),
            lowDb: Self.db(fromPower: Double(low) / norm),
            midDb: Self.db(fromPower: Double(mid) / norm),
            highDb: Self.db(fromPower: Double(high) / norm)
        )
        lock.lock()
        latest = level
        lock.unlock()
    }

    static func db(fromPower power: Double) -> Double {
        10 * log10(max(power, 1e-12)) + displayOffsetDb
    }
}
