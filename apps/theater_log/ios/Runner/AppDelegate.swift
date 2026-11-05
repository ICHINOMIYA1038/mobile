import AVFoundation
import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var ponPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // チケットの文字を端末の中で読む。写真はどこにも送らない
    let ocr = FlutterMethodChannel(name: "gekipon/ocr", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    ocr.setMethodCallHandler { call, result in
      guard call.method == "recognize", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard #available(iOS 16.0, *) else {
        result(FlutterError(code: "unsupported", message: "iOS 16 以降で使えます", details: nil))
        return
      }
      guard let image = UIImage(contentsOfFile: path), let cg = image.cgImage else {
        result(FlutterError(code: "image", message: nil, details: nil))
        return
      }
      let request = VNRecognizeTextRequest { req, error in
        if let error = error {
          DispatchQueue.main.async { result(FlutterError(code: "ocr", message: error.localizedDescription, details: nil)) }
          return
        }
        // 上から下、左から右の順に並べる
        let observations = (req.results as? [VNRecognizedTextObservation] ?? []).sorted {
          abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01 ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        DispatchQueue.main.async { result(lines) }
      }
      request.revision = VNRecognizeTextRequestRevision3
      request.recognitionLevel = .accurate
      request.recognitionLanguages = ["ja-JP", "en-US"]
      request.usesLanguageCorrection = true
      let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.exifValue)) ?? .up
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([request])
        } catch {
          DispatchQueue.main.async { result(FlutterError(code: "ocr", message: error.localizedDescription, details: nil)) }
        }
      }
    }
    let channel = FlutterMethodChannel(name: "gekipon/sound", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "prepare":
        guard let data = call.arguments as? FlutterStandardTypedData else {
          result(FlutterError(code: "bad_args", message: nil, details: nil))
          return
        }
        do {
          // ambient は消音スイッチに従い、再生中の音楽を止めない
          try AVAudioSession.sharedInstance().setCategory(.ambient)
          self?.ponPlayer = try AVAudioPlayer(data: data.data)
          self?.ponPlayer?.prepareToPlay()
          result(nil)
        } catch {
          result(FlutterError(code: "audio", message: error.localizedDescription, details: nil))
        }
      case "play":
        self?.ponPlayer?.currentTime = 0
        self?.ponPlayer?.play()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private extension UIImage.Orientation {
  /// Vision に渡す向き（EXIF の番号）
  var exifValue: Int {
    switch self {
    case .up: return 1
    case .down: return 3
    case .left: return 8
    case .right: return 6
    case .upMirrored: return 2
    case .downMirrored: return 4
    case .leftMirrored: return 5
    case .rightMirrored: return 7
    @unknown default: return 1
    }
  }
}
