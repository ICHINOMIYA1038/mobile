// 衝撃音解析(ImpulseAnalyzer)を実機なしで検証する CLI。
//
//   cd tool/impulse_lab
//   swift run -c release impulse_lab synth            # 既知の減衰時間・重心を持つ合成音で推定誤差を見る
//   swift run -c release impulse_lab wav data/esc50   # WAV ファイル群を解析して一覧表示
//
// ImpulseAnalyzer.swift はアプリの ios/Runner/SoundMeter/ へのシンボリックリンク。
// 判定ルール(WallEstimate)は Dart 側 lib/logic/inspection_scorer.dart と同じ閾値を写している。
import AVFoundation
import Foundation

// MARK: - Dart 側 WallEstimate.fromKnock と同じ判定

func wallEstimate(_ r: ImpulseAnalyzer.Result) -> String {
    if r.snrDb < 10 { return "unknown" }
    let ring = r.t20 ?? r.t10.map { $0 * 2 }
    let resonant = r.lowShare >= 0.8
    if let ring, ring >= 0.12 { return "light" }
    if resonant, let ring, ring >= 0.06 { return "light" }
    if let ring, ring < 0.06, !resonant { return "heavy" }
    if ring == nil, !resonant { return "heavy" }
    return "medium"
}

func fmt(_ v: Double?, _ digits: Int = 2) -> String {
    guard let v else { return "  --  " }
    return String(format: "%\(digits + 4).\(digits)f", v)
}

// MARK: - WAV 読み込み(モノラル化・Float)

func loadWav(_ url: URL) throws -> ([Float], Double) {
    let file = try AVAudioFile(forReading: url)
    let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: file.fileFormat.sampleRate,
        channels: 1,
        interleaved: false
    )!
    let frames = AVAudioFrameCount(file.length)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
        throw NSError(domain: "lab", code: 1)
    }
    try file.read(into: buffer)
    let n = Int(buffer.frameLength)
    let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: n))
    return (samples, file.fileFormat.sampleRate)
}

// MARK: - 合成音

struct Rng {
    var state: UInt64
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000 * 2 - 1
    }
}

/// 暗騒音(白色雑音, floorDb) + 立ち上がりから RT60 で指数減衰する帯域雑音。
/// centerHz を中心に bandwidth の帯域(単純な2次共振器)を通して「ノックらしい」音色にする。
func synth(
    sampleRate: Double,
    floorAmp: Double,
    impulseAmp: Double,
    rt60: Double,
    centerHz: Double,
    q: Double,
    seconds: Double = 2.5,
    onsetAt: Double = 1.0
) -> [Float] {
    var rng = Rng(state: 0x9E3779B97F4A7C15)
    let n = Int(seconds * sampleRate)
    var out = [Float](repeating: 0, count: n)
    let onset = Int(onsetAt * sampleRate)
    // 減衰: 60dB 落ちるのに rt60 秒 → 振幅は 10^(-3 t / rt60)
    let decayPerSample = pow(10.0, -3.0 / (rt60 * sampleRate))
    // 2次共振フィルタ(双二次バンドパス)
    let w0 = 2 * Double.pi * centerHz / sampleRate
    let alpha = sin(w0) / (2 * q)
    let b0 = alpha, b1 = 0.0, b2 = -alpha
    let a0 = 1 + alpha, a1 = -2 * cos(w0), a2 = 1 - alpha
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
    var env = 1.0
    for i in 0..<n {
        var x = rng.next() * floorAmp
        if i >= onset {
            x += rng.next() * impulseAmp * env
            env *= decayPerSample
        }
        let y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2 = x1; x1 = x; y2 = y1; y1 = y
        // 床の雑音はフィルタを通さず足す(広帯域の暗騒音)
        out[i] = Float(y + rng.next() * floorAmp)
    }
    return out
}

func runSynth() {
    let sr = 48_000.0
    print("== 合成音: 既知の RT60 / 重心に対する推定 ==")
    print(String(format: "%-8@ %-8@ | %@ %@ %@ %@ %@  %@", "RT60", "中心Hz", "  推定RT60", "  T20  ", "  重心Hz ", "  SNR ", "壁判定", "備考"))
    let cases: [(Double, Double, Double)] = [
        // (rt60, centerHz, q)
        (0.30, 400, 2), (0.30, 900, 2), (0.30, 1800, 2),
        (0.60, 400, 2), (0.60, 900, 2), (0.60, 1800, 2),
        (1.00, 900, 2), (1.50, 900, 2),
        // 短い余韻(重い壁のノック)と長い余韻(軽い壁)
        (0.15, 350, 4), (0.50, 1600, 6),
    ]
    for (rt60, hz, q) in cases {
        let samples = synth(sampleRate: sr, floorAmp: 0.002, impulseAmp: 0.5, rt60: rt60, centerHz: hz, q: q)
        guard let (r, _) = ImpulseAnalyzer.runOffline(samples: samples, sampleRate: sr) else {
            print(String(format: "%6.2f %8.0f | 立ち上がり検出なし", rt60, hz))
            continue
        }
        let err = r.rt60.map { ($0 - rt60) / rt60 * 100 }
        print(String(
            format: "%6.2f %8.0f | %@ %@ %@ %@  %-7@ 誤差%@%%",
            rt60, hz, fmt(r.rt60), fmt(r.t20), fmt(r.spectralCentroidHz, 0), fmt(r.snrDb, 1),
            wallEstimate(r), fmt(err, 0)
        ))
    }
    // 床が高い(うるさい部屋)ケース: T20 が床に埋もれて T10 外挿になるはず
    print("\n== 暗騒音が高い場合(床に埋もれる) ==")
    for floorAmp in [0.02, 0.05, 0.1] {
        let samples = synth(sampleRate: sr, floorAmp: floorAmp, impulseAmp: 0.5, rt60: 0.6, centerHz: 900, q: 2)
        if let (r, _) = ImpulseAnalyzer.runOffline(samples: samples, sampleRate: sr) {
            print(String(format: "floor=%.2f | RT60推定 %@ T10 %@ T20 %@ SNR %@", floorAmp, fmt(r.rt60), fmt(r.t10), fmt(r.t20), fmt(r.snrDb, 1)))
        } else {
            print(String(format: "floor=%.2f | 立ち上がり検出なし", floorAmp))
        }
    }
}

func runWav(_ dir: String) throws {
    let fm = FileManager.default
    let urls = try fm.contentsOfDirectory(atPath: dir)
        .filter { $0.hasSuffix(".wav") }
        .sorted()
        .map { URL(fileURLWithPath: dir).appendingPathComponent($0) }
    print("== \(dir): \(urls.count) files ==")
    print("file                    class   | 検出 | 推定RT60  T10    T20   重心Hz   低域比  SNR   壁判定")
    var stats: [String: [String: Int]] = [:]
    var centroids: [String: [Double]] = [:]
    var rts: [String: [Double]] = [:]
    for url in urls {
        let name = url.lastPathComponent
        // ESC-50: 末尾の -NN がクラス id (30=door_wood_knock, 22=clapping)
        let cls = name.split(separator: "-").last.map { String($0.dropLast(4)) } ?? "?"
        let label = cls == "30" ? "knock" : cls == "22" ? "clap" : cls
        let (samples, sr) = try loadWav(url)
        guard let (r, onset) = ImpulseAnalyzer.runOffline(samples: samples, sampleRate: sr) else {
            print(String(format: "%-24@ %-7@ | なし |", name, label))
            stats[label, default: [:]]["none", default: 0] += 1
            continue
        }
        let wall = wallEstimate(r)
        stats[label, default: [:]][wall, default: 0] += 1
        centroids[label, default: []].append(r.spectralCentroidHz)
        if let rt = r.rt60 { rts[label, default: []].append(rt) }
        print(String(
            format: "%-24@ %-7@ | %4.2fs | %@ %@ %@ %@ %@ %@  %@",
            name, label, Double(onset) / sr,
            fmt(r.rt60), fmt(r.t10), fmt(r.t20), fmt(r.spectralCentroidHz, 0), fmt(r.lowShare), fmt(r.snrDb, 1), wall
        ))
    }
    print("\n== 集計 ==")
    for (label, counts) in stats.sorted(by: { $0.key < $1.key }) {
        let c = centroids[label] ?? []
        let rt = rts[label] ?? []
        func median(_ a: [Double]) -> Double? { a.isEmpty ? nil : a.sorted()[a.count / 2] }
        print("\(label): \(counts.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: " "))"
              + "  重心中央値=\(fmt(median(c), 0))Hz  RT60中央値=\(fmt(median(rt)))s")
    }
}

let args = CommandLine.arguments.dropFirst()
switch args.first {
case "synth":
    runSynth()
case "wav":
    try runWav(args.dropFirst().first ?? "data/esc50")
default:
    print("usage: impulse_lab synth | wav <dir>")
}

// MARK: - 診断: ファイル全体の 10ms エンベロープ統計
func runDiag(_ dir: String) throws {
    let fm = FileManager.default
    let urls = try fm.contentsOfDirectory(atPath: dir).filter { $0.hasSuffix(".wav") }.sorted()
        .map { URL(fileURLWithPath: dir).appendingPathComponent($0) }
    print("file                     | 最初0.6s床dB  全体最小dB  最大dB  最大時刻  最大-床0.6s  最大-全体最小")
    for url in urls {
        let (samples, sr) = try loadWav(url)
        let frame = Int(0.010 * sr)
        var env: [Double] = []
        var i = 0
        while i + frame <= samples.count {
            var acc = 0.0
            for k in i..<(i + frame) { acc += Double(samples[k]) * Double(samples[k]) }
            env.append(ImpulseAnalyzer.db(fromPower: acc / Double(frame)))
            i += frame
        }
        let floorFrames = Int(0.6 / 0.010)
        let first = env.prefix(floorFrames)
        let floorDb = ImpulseAnalyzer.db(fromPower: first.map { pow(10, ($0 - ImpulseAnalyzer.displayOffsetDb) / 10) }.reduce(0, +) / Double(first.count))
        let minDb = env.min() ?? 0
        let maxIdx = env.indices.max(by: { env[$0] < env[$1] }) ?? 0
        let maxDb = env[maxIdx]
        print(String(format: "%-24@ | %8.1f %10.1f %8.1f %8.2fs %9.1f %10.1f",
                     url.lastPathComponent, floorDb, minDb, maxDb, Double(maxIdx) * 0.010, maxDb - floorDb, maxDb - minDb))
    }
}
if args.first == "diag" { try runDiag(args.dropFirst().first ?? "data/esc50") }

if args.first == "debugsynth" {
    let sr = 48_000.0
    let samples = synth(sampleRate: sr, floorAmp: 0.002, impulseAmp: 0.5, rt60: 0.15, centerHz: 350, q: 4)
    var det = ImpulseAnalyzer.OnsetDetector(sampleRate: sr, chunkSize: 256)
    var i = 0
    while i < samples.count {
        let n = min(256, samples.count - i)
        var acc = 0.0
        for k in i..<(i+n) { acc += Double(samples[k]) * Double(samples[k]) }
        let p = acc / Double(n)
        let hit = det.push(power: p)
        let t = Double(i) / sr
        if t > 0.95 && t < 1.15 {
            print(String(format: "t=%.3f frame=%.1f floor=%@ hit=%@", t, 10*log10(p)+90, fmt(det.floorDb,1), hit ? "YES" : "no"))
        }
        if hit { break }
        i += n
    }
}
