import ARKit
import AVFoundation
import Flutter
import SceneKit
import UIKit

/// 音の侵入マップ。ARKit のワールドトラッキングで端末位置を追いながら
/// 一定間隔でその場所のレベル(全体/低域/高域)を記録し、空間上に色付きの
/// 球として置いていく。壁や窓に沿って端末を動かすと「どこが大きいか」が
/// ヒートマップとして見える。
///
/// Flutter 側とは
/// - PlatformView `jp.pairof.sound_shield/ar_noise_map_view`
/// - MethodChannel `jp.pairof.sound_shield/ar_noise_map` (start/stop/setTag/isSupported)
/// - EventChannel `jp.pairof.sound_shield/ar_noise_map/live` (現在値と統計)
/// でやり取りする。
public final class ArNoiseMapPlugin: NSObject, FlutterPlugin {
    static let viewType = "jp.pairof.sound_shield/ar_noise_map_view"
    private static let methodChannelName = "jp.pairof.sound_shield/ar_noise_map"
    private static let eventChannelName = "jp.pairof.sound_shield/ar_noise_map/live"

    fileprivate weak var currentView: ArNoiseMapView?
    fileprivate var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ArNoiseMapPlugin()
        let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        registrar.register(ArNoiseMapViewFactory(plugin: instance), withId: viewType)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(ARWorldTrackingConfiguration.isSupported)
        case "start":
            guard let view = currentView else {
                result(FlutterError(code: "no_view", message: "AR view is not mounted", details: nil))
                return
            }
            guard ARWorldTrackingConfiguration.isSupported else {
                result(FlutterError(code: "unsupported", message: "ARKit world tracking is not supported", details: nil))
                return
            }
            do {
                try view.start()
                result(nil)
            } catch {
                result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
            }
        case "setTag":
            let args = call.arguments as? [String: Any]
            currentView?.currentTag = args?["tag"] as? String ?? "untagged"
            result(nil)
        case "stop":
            let samples = currentView?.stop() ?? []
            result(["samples": samples])
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension ArNoiseMapPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

final class ArNoiseMapViewFactory: NSObject, FlutterPlatformViewFactory {
    private unowned let plugin: ArNoiseMapPlugin

    init(plugin: ArNoiseMapPlugin) {
        self.plugin = plugin
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let view = ArNoiseMapView(frame: frame, plugin: plugin)
        plugin.currentView = view
        return view
    }
}

final class ArNoiseMapView: NSObject, FlutterPlatformView {
    private let sceneView: ARSCNView
    private unowned let plugin: ArNoiseMapPlugin
    private let engine = AVAudioEngine()
    private var meter: InstantLevelMeter?
    private var timer: DispatchSourceTimer?
    private var samples: [[String: Any]] = []
    private var nodes: [SCNNode] = []
    private var nodeDb: [Double] = []
    private var running = false
    var currentTag = "untagged"

    private static let sampleInterval: Double = 0.25
    /// 直前のサンプルからこの距離(m)動いていなければ新しい球は置かない
    /// (同じ場所で球が重なるのを避ける。値は上書きする)。
    private static let minSpacing: Float = 0.08

    init(frame: CGRect, plugin: ArNoiseMapPlugin) {
        self.plugin = plugin
        sceneView = ARSCNView(frame: frame)
        sceneView.automaticallyUpdatesLighting = true
        sceneView.scene = SCNScene()
        super.init()
    }

    func view() -> UIView { sceneView }

    func start() throws {
        guard !running else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard let meter = InstantLevelMeter(sampleRate: format.sampleRate) else {
            throw NSError(domain: "ArNoiseMap", code: 1, userInfo: [NSLocalizedDescriptionKey: "FFT setup failed"])
        }
        self.meter = meter
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.meter?.append(buffer)
        }
        try engine.start()

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        samples.removeAll()
        nodes.forEach { $0.removeFromParentNode() }
        nodes.removeAll()
        nodeDb.removeAll()
        running = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil
        )
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.sampleInterval, repeating: Self.sampleInterval)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            AVAudioSession.InterruptionType(rawValue: typeValue) == .began
        else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.running else { return }
            self.plugin.eventSink?(["tracking": "interrupted", "db": 0.0, "count": self.samples.count])
        }
    }

    func stop() -> [[String: Any]] {
        guard running else { return samples }
        running = false
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        timer?.cancel()
        timer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        sceneView.session.pause()
        return samples
    }

    private func tick() {
        guard running, let frame = sceneView.session.currentFrame, let level = meter?.latestLevel else { return }
        guard frame.camera.trackingState == .normal else {
            plugin.eventSink?(["tracking": "limited", "db": level.overallDb, "count": samples.count])
            return
        }
        let t = frame.camera.transform
        // マイクは端末下端にあるので、カメラ位置から端末の「下」方向に少し寄せる。
        let pos = simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        let down = -simd_float3(t.columns.1.x, t.columns.1.y, t.columns.1.z)
        let micPos = pos + down * 0.07

        samples.append([
            "x": Double(micPos.x), "y": Double(micPos.y), "z": Double(micPos.z),
            "db": level.overallDb, "lowDb": level.lowDb, "midDb": level.midDb, "highDb": level.highDb,
            "tag": currentTag, "t": frame.timestamp,
        ])

        if let last = nodes.last, simd_distance(last.simdPosition, micPos) < Self.minSpacing {
            nodeDb[nodeDb.count - 1] = max(nodeDb[nodeDb.count - 1], level.overallDb)
        } else {
            let sphere = SCNSphere(radius: 0.025)
            sphere.firstMaterial?.lightingModel = .constant
            let node = SCNNode(geometry: sphere)
            node.simdPosition = micPos
            sceneView.scene.rootNode.addChildNode(node)
            nodes.append(node)
            nodeDb.append(level.overallDb)
        }
        recolor()

        let dbs = nodeDb
        plugin.eventSink?([
            "tracking": "normal",
            "db": level.overallDb,
            "lowDb": level.lowDb,
            "highDb": level.highDb,
            "count": samples.count,
            "minDb": dbs.min() ?? level.overallDb,
            "maxDb": dbs.max() ?? level.overallDb,
        ])
    }

    /// 全球を現在の最小〜最大レンジで塗り直す(レンジが動いても色の意味が揃うように)。
    private func recolor() {
        guard let lo = nodeDb.min(), let hi = nodeDb.max() else { return }
        let span = max(hi - lo, 6)
        for (node, db) in zip(nodes, nodeDb) {
            let ratio = CGFloat(min(max((db - lo) / span, 0), 1))
            // 青(静か) → 黄 → 赤(大きい)
            let hue = 0.66 * (1 - ratio)
            node.geometry?.firstMaterial?.diffuse.contents =
                UIColor(hue: hue, saturation: 0.9, brightness: 0.95, alpha: 0.85)
        }
    }
}
