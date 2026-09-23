import Foundation
import CoreML
import Vision
import Accelerate
import UIKit

/// 楽譜画像 → ドレミ認識のオンデバイス実装。
/// Python 側 (`staff/detect_dnn.py`, `omr/pipeline_dnn.py`) の移植:
///   1. 五線UNet でヒートマップ → 段(system)検出 → 列ごとに五線中心を追跡して湾曲補正(dewarp)
///   2. 各段を単旋律CRNN で認識(CTC greedy) → 音高・音価・段内x
///   3. 段ストリップPNGを一時保存し、結果を辞書で返す
///
/// 注: 本ファイルは実機(iOS16+)前提。数値処理は Python 実装と等価になるよう移植している。
final class DoremiEngine {

    enum EngineError: Error { case modelLoad(String), imageLoad, noStaves }

    private let staffModel: MLModel
    private let monoModel: MLModel
    private let vocab: [String]
    private let widthDiv = 8
    private let stripHeight = 96   // mono 入力高さ

    init() throws {
        guard let staffURL = Bundle.main.url(forResource: "staff", withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: "staff", withExtension: "mlpackage") else {
            throw EngineError.modelLoad("staff model not found")
        }
        guard let monoURL = Bundle.main.url(forResource: "mono", withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: "mono", withExtension: "mlpackage") else {
            throw EngineError.modelLoad("mono model not found")
        }
        let cfg = MLModelConfiguration()
        // 可変サイズ(RangeDim)モデルは Neural Engine が非対応で .all だと
        // "failed to prepare the model for predictions" になる。CPU+GPU にする。
        cfg.computeUnits = .cpuAndGPU
        self.staffModel = try MLModel(contentsOf: staffURL, configuration: cfg)
        self.monoModel = try MLModel(contentsOf: monoURL, configuration: cfg)
        guard let vurl = Bundle.main.url(forResource: "mono_vocab", withExtension: "json"),
              let data = try? Data(contentsOf: vurl),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            throw EngineError.modelLoad("mono_vocab.json not found")
        }
        self.vocab = arr
    }

    // MARK: - パイプライン

    func recognize(imagePath: String,
                   progress: ((String, Double) -> Void)? = nil) throws -> [String: Any] {
        let start = Date()
        progress?("preparing", 0.05)
        guard let ui = UIImage(contentsOfFile: imagePath), let cg = ui.cgImage else {
            throw EngineError.imageLoad
        }
        let origW = cg.width, origH = cg.height          // 元画像サイズ(ルビ配置の基準)
        var gray = GrayImage(cgImage: cg)               // 元解像度グレースケール
        // 大きすぎる写真は処理を軽くするため縮小（学習分布にも近づく）。五線間隔は後で正規化されるので問題ない。
        let maxSide = 1800
        if gray.width > maxSide {
            let s = Double(maxSide) / Double(gray.width)
            gray = gray.resized(width: maxSide, height: max(8, Int(Double(gray.height) * s)))
        }

        NSLog("[Doremi] input gray=\(gray.width)x\(gray.height)")
        progress?("detectingStaves", 0.2)
        let prob = try staffHeatmap(gray)               // 五線確率マップ(元解像度)
        var maxp = 0; for v in prob.pixels where Int(v) > maxp { maxp = Int(v) }
        let bands = groupSystems(prob)
        NSLog("[Doremi] staff heatmap max=\(maxp) systems=\(bands.count)")
        // 0段でもエラーにせず、debug付きで返して画面に状況を出す(原因切り分けのため)

        progress?("recognizing", 0.4)
        // 段はページ全幅で切り出しているので、段内x比率 = 元画像x比率。ルビは元画像座標で返す。
        var notes: [[String: Any]] = []
        for (k, band) in bands.enumerated() {
            guard let (strip, _) = dewarpStrip(gray, prob: prob, y0: band.0, y1: band.1)
            else { continue }
            let stripNotes = try recognizeStrip(strip)   // x は段内比率(0..1)
            let yTopFrac = Double(band.0) / Double(gray.height)   // 五線上端(元画像比率)
            for n in stripNotes {
                var nn = n
                nn["yFrac"] = yTopFrac
                notes.append(nn)
            }
            NSLog("[Doremi] system \(k): notes=\(stripNotes.count)")
            progress?("recognizing", 0.4 + 0.5 * Double(k + 1) / Double(bands.count))
        }
        progress?("rendering", 0.97)
        let dbg = "gray=\(gray.width)x\(gray.height) systems=\(bands.count) notes=\(notes.count)"
        return [
            "sourceImagePath": imagePath,
            "imageWidth": origW,
            "imageHeight": origH,
            "elapsedMs": Int(Date().timeIntervalSince(start) * 1000),
            "notes": notes,
            "debug": dbg
        ]
    }

    // MARK: - ライブ五線検出（カメラプレビュー用・軽量）

    /// グレースケール生バイト(width×height)から五線の領域を検出して返す。
    /// 返り値: [[y0Frac, y1Frac, x0Frac, x1Frac], ...]（画像サイズに対する比率）
    func detectStaves(grayBytes: [UInt8], width: Int, height: Int) throws -> [[Double]] {
        var gray = GrayImage(width: width, height: height)
        gray.pixels = grayBytes
        let prob = try staffHeatmap(gray, inferW: 400)   // プレビューは低解像度で高速に
        let bands = groupSystems(prob)
        let thr: UInt8 = 102
        return bands.map { band in
            // 帯内で五線画素があるx範囲を求める（ハイライトを実際の譜面幅に合わせる）
            var minX = width, maxX = 0
            var y = band.0
            while y < band.1 {
                var x = 0
                while x < width {
                    if prob[x, y] > thr {
                        if x < minX { minX = x }
                        if x > maxX { maxX = x }
                    }
                    x += 4   // 間引きで高速化
                }
                y += 2
            }
            if minX > maxX { minX = 0; maxX = width - 1 }
            return [Double(band.0) / Double(height), Double(band.1) / Double(height),
                    Double(minX) / Double(width), Double(maxX) / Double(width)]
        }
    }

    // MARK: - 五線UNet 推論

    private func staffHeatmap(_ gray: GrayImage, inferW: Int = 800) throws -> GrayImage {
        let s = Double(inferW) / Double(gray.width)
        let small = gray.resized(width: inferW, height: max(8, Int(Double(gray.height) * s)))
        // 32 の倍数にパディング
        let h32 = (small.height + 31) / 32 * 32
        let w32 = (small.width + 31) / 32 * 32
        let padded = small.padded(toWidth: w32, toHeight: h32, value: 255)
        let input = try padded.toMLMultiArrayInverted()  // (1,1,H,W) 黒インク=1
        let out = try staffModel.prediction(from: DoremiFeatureProvider(["image": input]))
        guard let logits = out.featureValue(for: "staff_logits")?.multiArrayValue else {
            throw EngineError.modelLoad("staff output missing")
        }
        let probSmall = GrayImage.fromLogits(logits, width: w32, height: h32)
            .cropped(width: small.width, height: small.height)
        return probSmall.resized(width: gray.width, height: gray.height)  // 0..255 の確率
    }

    /// 行方向プロファイルから五線帯を検出（五線間隔ベースで統合）。Python group_systems と等価。
    private func groupSystems(_ prob: GrayImage, thr: UInt8 = 102) -> [(Int, Int)] {
        var rowFrac = [Double](repeating: 0, count: prob.height)
        for y in 0..<prob.height {
            var cnt = 0
            for x in 0..<prob.width where prob[x, y] > thr { cnt += 1 }
            rowFrac[y] = Double(cnt) / Double(prob.width)
        }
        var raw: [(Int, Int)] = []
        var s: Int? = nil
        for y in 0..<prob.height {
            let on = rowFrac[y] > 0.1
            if on, s == nil { s = y }
            else if !on, let st = s { raw.append((st, y)); s = nil }
        }
        if let st = s { raw.append((st, prob.height)) }
        if raw.isEmpty { return [] }
        let centers = raw.map { Double($0.0 + $0.1) / 2 }
        var gaps: [Double] = []
        for i in 1..<max(centers.count, 1) { gaps.append(centers[i] - centers[i-1]) }
        gaps.sort()
        var sp = gaps.isEmpty ? 12 : gaps[max(0, gaps.count/4)]
        sp = min(max(sp, 6), 40)
        var merged: [[Int]] = [[raw[0].0, raw[0].1]]
        for b in raw.dropFirst() {
            if Double(b.0 - merged[merged.count-1][1]) < 3 * sp {
                merged[merged.count-1][1] = b.1
            } else { merged.append([b.0, b.1]) }
        }
        return merged.filter { Double($0[1] - $0[0]) >= sp }.map { ($0[0], $0[1]) }
    }

    /// 段を中心線に沿ってまっすぐ化。列は保存されるので x はそのまま。Python dewarp_strip と等価。
    private func dewarpStrip(_ gray: GrayImage, prob: GrayImage, y0: Int, y1: Int,
                             targetH: Int = 112) -> (GrayImage, Double)? {
        let W = gray.width
        let ncol = 40
        var cx: [Double] = [], cy: [Double] = []
        for i in 0..<ncol {
            let x0 = W * i / ncol, x1 = W * (i+1) / ncol
            var num = 0.0, den = 0.0, maxv = 0.0
            for y in y0..<y1 {
                var col = 0.0
                for x in x0..<x1 { col += Double(prob[x, y]) / 255.0 }
                col /= Double(max(1, x1 - x0))
                maxv = max(maxv, col)
                let w = max(0.0, col - 0.4)
                num += Double(y) * w; den += w
            }
            if maxv < 0.4 || den < 1e-3 { continue }
            cx.append(Double(x0 + x1) / 2); cy.append(num / den)
        }
        if cx.count < 3 { return nil }
        let half = Int(Double(y1 - y0) * 0.75)
        let outH = 2 * half + 1
        var strip = GrayImage(width: W, height: outH)
        for x in 0..<W {
            let yc = interp(Double(x), cx, cy)
            for (row, dy) in stride(from: -half, through: half, by: 1).enumerated() {
                strip[x, row] = gray.bilinear(Double(x), yc + Double(dy))
            }
        }
        let scaled = strip.resized(width: Int(Double(W) * Double(targetH) / Double(outH)),
                                   height: targetH)
        return (scaled, Double(scaled.width) / Double(scaled.height))
    }

    // MARK: - 単旋律CRNN 推論(CTC greedy + アライン)

    private func recognizeStrip(_ strip: GrayImage) throws -> [[String: Any]] {
        let nw = max(32, strip.width * stripHeight / strip.height)
        let resized = strip.resized(width: nw, height: stripHeight)
        let input = try resized.toMLMultiArrayInverted()
        let out = try monoModel.prediction(from: DoremiFeatureProvider(["image": input]))
        guard let logits = out.featureValue(for: "logits")?.multiArrayValue else { return [] }
        // logits: (1, T, V)。argmax → blank(0)除去・連続重複除去、発火フレームを保持
        let T = logits.shape[1].intValue, V = logits.shape[2].intValue
        let data = logits.toFloatArray()
        let sT = logits.strides[1].intValue, sV = logits.strides[2].intValue
        var notes: [[String: Any]] = []
        var prev = 0
        let framesUsed = min(T, nw / widthDiv)
        for f in 0..<framesUsed {
            var best = 0; var bestv = -Float.greatestFiniteMagnitude
            for v in 0..<V {
                let val = data[f * sT + v * sV]
                if val > bestv { bestv = val; best = v }
            }
            if best != 0 && best != prev, best < vocab.count {
                if let ruby = Self.tokenToRuby(vocab[best]) {
                    let xStrip = Double(f * widthDiv) * Double(strip.height) / Double(stripHeight)
                    notes.append([
                        "ruby": ruby,
                        "pitch": Self.tokenPitch(vocab[best]) ?? "",
                        "duration": Self.tokenDuration(vocab[best]) ?? "",
                        "x": xStrip / Double(strip.width)   // 0..1
                    ])
                }
            }
            prev = best
        }
        return notes
    }

    // MARK: - トークン→ドレミ

    private static let pcJP = ["C": "ド", "D": "レ", "E": "ミ", "F": "ファ", "G": "ソ", "A": "ラ", "B": "シ"]

    static func tokenToRuby(_ t: String) -> String? {
        guard let m = matchNote(t) else { return nil }
        let acc = m.1 == "#" ? "♯" : (m.1 == "b" ? "♭" : "")
        return (pcJP[m.0] ?? "") + acc
    }
    static func tokenPitch(_ t: String) -> String? {
        guard let m = matchNote(t) else { return nil }
        return "\(m.0)\(m.1)\(m.2)"
    }
    static func tokenDuration(_ t: String) -> String? {
        guard let r = t.range(of: "_") else { return nil }
        return String(t[r.upperBound...])
    }
    /// "note-F#5_eighth" → (letter, accidental, octave)
    private static func matchNote(_ t: String) -> (String, String, String)? {
        guard t.hasPrefix("note-") else { return nil }
        let body = t.dropFirst(5)
        guard let letter = body.first, "ABCDEFG".contains(letter) else { return nil }
        var rest = body.dropFirst()
        var acc = ""
        if let c = rest.first, c == "#" || c == "b" { acc = String(c); rest = rest.dropFirst() }
        var oct = ""
        for c in rest { if c.isNumber { oct.append(c) } else { break } }
        if oct.isEmpty { return nil }
        return (String(letter), acc, oct)
    }
}

/// CoreML 入力用の簡易 FeatureProvider。
final class DoremiFeatureProvider: MLFeatureProvider {
    let features: [String: MLFeatureValue]
    init(_ arrays: [String: MLMultiArray]) {
        features = arrays.mapValues { MLFeatureValue(multiArray: $0) }
    }
    var featureNames: Set<String> { Set(features.keys) }
    func featureValue(for featureName: String) -> MLFeatureValue? { features[featureName] }
}

private func interp(_ x: Double, _ xs: [Double], _ ys: [Double]) -> Double {
    if x <= xs.first! { return ys.first! }
    if x >= xs.last! { return ys.last! }
    for i in 1..<xs.count where x <= xs[i] {
        let t = (x - xs[i-1]) / (xs[i] - xs[i-1])
        return ys[i-1] + t * (ys[i] - ys[i-1])
    }
    return ys.last!
}
