import Foundation
import CoreML
import UIKit

extension MLMultiArray {
    /// dataType(float32/float16/double)に関わらず連続配列を [Float] にして返す。
    /// Core ML mlprogram は float16 で返すことがあり、Float ポインタで直接読むとゴミになるため。
    func toFloatArray() -> [Float] {
        let n = self.count
        var out = [Float](repeating: 0, count: n)
        switch self.dataType {
        case .float32:
            let p = UnsafeMutablePointer<Float>(OpaquePointer(self.dataPointer))
            for i in 0..<n { out[i] = p[i] }
        case .float16:
            let p = UnsafeMutablePointer<UInt16>(OpaquePointer(self.dataPointer))
            for i in 0..<n { out[i] = Float(float16Bits: p[i]) }
        case .double:
            let p = UnsafeMutablePointer<Double>(OpaquePointer(self.dataPointer))
            for i in 0..<n { out[i] = Float(p[i]) }
        @unknown default:
            for i in 0..<n { out[i] = self[i].floatValue }
        }
        return out
    }
}

extension Float {
    /// IEEE half(float16 bits) → Float
    init(float16Bits h: UInt16) {
        let sign = UInt32(h & 0x8000) << 16
        let exp = UInt32(h & 0x7C00) >> 10
        let mant = UInt32(h & 0x03FF)
        var bits: UInt32
        if exp == 0 {
            if mant == 0 { bits = sign }
            else {
                // subnormal
                var e: UInt32 = 127 - 15 + 1
                var m = mant
                while (m & 0x0400) == 0 { m <<= 1; e -= 1 }
                m &= 0x03FF
                bits = sign | (e << 23) | (m << 13)
            }
        } else if exp == 0x1F {
            bits = sign | 0x7F800000 | (mant << 13)
        } else {
            bits = sign | ((exp + (127 - 15)) << 23) | (mant << 13)
        }
        self = Float(bitPattern: bits)
    }
}

/// 8bit グレースケール画像バッファ。OMR の数値処理(リサイズ/パディング/バイリニア/PNG/MLMultiArray)を提供。
/// 画素値 0..255（255=白）。
struct GrayImage {
    var width: Int
    var height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, fill: UInt8 = 255) {
        self.width = width; self.height = height
        self.pixels = [UInt8](repeating: fill, count: width * height)
    }

    init(cgImage cg: CGImage) {
        width = cg.width; height = cg.height
        pixels = [UInt8](repeating: 255, count: width * height)
        let cs = CGColorSpaceCreateDeviceGray()
        pixels.withUnsafeMutableBytes { buf in
            if let ctx = CGContext(data: buf.baseAddress, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: width, space: cs,
                                   bitmapInfo: CGImageAlphaInfo.none.rawValue) {
                // CoreGraphics は左下原点。そのまま描くとバッファが上下反転して
                // 音符の高さ(=音程)が逆さになる。context を上下反転してから描き、
                // バッファ row0 = 画像の一番上 になるようにする。
                ctx.translateBy(x: 0, y: CGFloat(height))
                ctx.scaleBy(x: 1, y: -1)
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
    }

    subscript(_ x: Int, _ y: Int) -> UInt8 {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }

    func bilinear(_ fx: Double, _ fy: Double) -> UInt8 {
        if fx < 0 || fy < 0 || fx >= Double(width - 1) || fy >= Double(height - 1) {
            let xi = min(max(Int(fx.rounded()), 0), width - 1)
            let yi = min(max(Int(fy.rounded()), 0), height - 1)
            return self[xi, yi]
        }
        let x0 = Int(fx), y0 = Int(fy)
        let dx = fx - Double(x0), dy = fy - Double(y0)
        let a = Double(self[x0, y0]), b = Double(self[x0+1, y0])
        let c = Double(self[x0, y0+1]), d = Double(self[x0+1, y0+1])
        let top = a + (b - a) * dx, bot = c + (d - c) * dx
        return UInt8(min(255, max(0, (top + (bot - top) * dy).rounded())))
    }

    func resized(width nw: Int, height nh: Int) -> GrayImage {
        var out = GrayImage(width: max(1, nw), height: max(1, nh))
        let sx = Double(width) / Double(out.width)
        let sy = Double(height) / Double(out.height)
        for y in 0..<out.height {
            for x in 0..<out.width {
                out[x, y] = bilinear((Double(x) + 0.5) * sx - 0.5, (Double(y) + 0.5) * sy - 0.5)
            }
        }
        return out
    }

    func padded(toWidth w: Int, toHeight h: Int, value: UInt8) -> GrayImage {
        var out = GrayImage(width: w, height: h, fill: value)
        for y in 0..<min(h, height) {
            for x in 0..<min(w, width) { out[x, y] = self[x, y] }
        }
        return out
    }

    func cropped(width w: Int, height h: Int) -> GrayImage {
        var out = GrayImage(width: w, height: h)
        for y in 0..<min(h, height) {
            for x in 0..<min(w, width) { out[x, y] = self[x, y] }
        }
        return out
    }

    /// UNet 出力(ロジット)を sigmoid して 0..255 の確率画像に。
    static func fromLogits(_ arr: MLMultiArray, width: Int, height: Int) -> GrayImage {
        var out = GrayImage(width: width, height: height)
        // 出力形状は (1,1,H,W) 想定
        let sh = arr.shape.map { $0.intValue }
        let H = sh[sh.count - 2], W = sh[sh.count - 1]
        let data = arr.toFloatArray()
        let strides = arr.strides.map { $0.intValue }
        let sH = strides[strides.count - 2], sW = strides[strides.count - 1]
        for y in 0..<min(H, height) {
            for x in 0..<min(W, width) {
                let v = data[y * sH + x * sW]
                let p = 1.0 / (1.0 + exp(-Double(v)))
                out[x, y] = UInt8(min(255, max(0, (p * 255).rounded())))
            }
        }
        return out
    }

    /// (1,1,H,W) の MLMultiArray に変換。黒インク=1(=(255-画素)/255)。
    func toMLMultiArrayInverted() throws -> MLMultiArray {
        let arr = try MLMultiArray(shape: [1, 1, NSNumber(value: height), NSNumber(value: width)],
                                   dataType: .float32)
        let ptr = UnsafeMutablePointer<Float>(OpaquePointer(arr.dataPointer))
        for i in 0..<(width * height) {
            ptr[i] = Float(255 - Int(pixels[i])) / 255.0
        }
        return arr
    }

    @discardableResult
    func writePNG(to path: String) -> Bool {
        let cs = CGColorSpaceCreateDeviceGray()
        var data = pixels
        guard let ctx = CGContext(data: &data, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let cg = ctx.makeImage() else { return false }
        let ui = UIImage(cgImage: cg)
        guard let png = ui.pngData() else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }
}
