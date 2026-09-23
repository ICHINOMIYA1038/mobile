import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private var engine: DoremiEngine?
  private var progressSink: FlutterEventSink?
  private var channelsReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Flutter 3.44 の暗黙エンジン初期化フック。ここで registrar の messenger を使って
  // チャンネルを張るのが確実（didFinishLaunching では rootViewController がまだ nil のことがある）。
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DoremiEngine") {
      setupChannels(registrar.messenger())
    }
  }

  private func setupChannels(_ messenger: FlutterBinaryMessenger) {
    if channelsReady { return }
    channelsReady = true
    let method = FlutterMethodChannel(
      name: "jp.pairof.doremi_scan/engine", binaryMessenger: messenger)
    let event = FlutterEventChannel(
      name: "jp.pairof.doremi_scan/progress", binaryMessenger: messenger)
    event.setStreamHandler(self)

    method.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "isAvailable":
        result(self.ensureEngine() != nil)
      case "recognize":
        guard let args = call.arguments as? [String: Any],
              let path = args["imagePath"] as? String else {
          result(FlutterError(code: "bad_args", message: "imagePath がありません", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            guard let eng = self.ensureEngine() else {
              throw DoremiEngine.EngineError.modelLoad("engine unavailable")
            }
            let out = try eng.recognize(imagePath: path) { phase, frac in
              DispatchQueue.main.async {
                self.progressSink?(["phase": phase, "fraction": frac])
              }
            }
            DispatchQueue.main.async { result(out) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "recognize_failed",
                                  message: "\(error)", details: nil))
            }
          }
        }
      case "detectStaves":
        guard let args = call.arguments as? [String: Any],
              let data = args["gray"] as? FlutterStandardTypedData,
              let w = args["width"] as? Int, let h = args["height"] as? Int,
              data.data.count >= w * h else {
          result(FlutterError(code: "bad_args", message: "gray/width/height が不正です", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInteractive).async {
          do {
            guard let eng = self.ensureEngine() else { throw DoremiEngine.EngineError.modelLoad("engine unavailable") }
            let bands = try eng.detectStaves(grayBytes: [UInt8](data.data), width: w, height: h)
            DispatchQueue.main.async { result(bands) }
          } catch {
            DispatchQueue.main.async { result([[Double]]()) }  // 検出失敗は「0段」として返す(ガイド用途)
          }
        }
      case "openSettings":
        // カメラ権限が拒否されたときに、設定アプリの本アプリ画面を開く
        DispatchQueue.main.async {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func ensureEngine() -> DoremiEngine? {
    if let e = engine { return e }
    do {
      engine = try DoremiEngine()
    } catch {
      NSLog("[Doremi] engine init failed: \(error)")
      lastEngineError = "\(error)"
      engine = nil
    }
    return engine
  }

  var lastEngineError: String?
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    progressSink = events
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    progressSink = nil
    return nil
  }
}
