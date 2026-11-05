import AVFoundation
import Flutter
import UIKit

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
