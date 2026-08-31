import Accelerate
import AVFoundation
import Flutter

/// 壁のノック音・手叩きのような「衝撃音」を1発だけ捕まえて解析する。
///
/// 内見モードで使う:
/// - ノック: スペクトル重心と余韻の長さから壁の重さ(RC寄りか軽量寄りか)を推定
/// - 手叩き: 減衰時間(T20→RT60換算)から部屋の響きやすさを推定
///
/// 流れ: ImpulseAnalyzer.OnsetDetector で立ち上がりを検出し(直近1秒の静かな
/// 瞬間を床として、床+しきい値かつ急な立ち上がり)、その 50ms 前から 1.2 秒分を
/// 切り出して解析する。
/// MethodChannel: capture(kind, timeoutSeconds) / cancel
public final class ImpulseProbePlugin: NSObject, FlutterPlugin {
    private static let channelName = "jp.pairof.sound_shield/impulse_probe"

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "jp.pairof.sound_shield.impulse")
    private var pendingResult: FlutterResult?
    private var timeoutTimer: DispatchSourceTimer?
    private var capturing = false

    private var sampleRate: Double = 48_000
    private var samples: [Float] = []
    private var onsetIndex: Int?
    private var detector: ImpulseAnalyzer.OnsetDetector?
    private var floorDbAtOnset: Double = 0


    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ImpulseProbePlugin()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "capture":
            let args = call.arguments as? [String: Any] ?? [:]
            let timeout = (args["timeoutSeconds"] as? Double) ?? 15
            let threshold = (args["onsetThresholdDb"] as? Double) ?? 12
            start(timeout: timeout, threshold: threshold, result: result)
        case "cancel":
            queue.async { [weak self] in self?.finish(with: nil, error: FlutterError(code: "cancelled", message: "cancelled", details: nil)) }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func start(timeout: TimeInterval, threshold: Double, result: @escaping FlutterResult) {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.capturing else {
                DispatchQueue.main.async { result(FlutterError(code: "busy", message: "already capturing", details: nil)) }
                return
            }
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.record, mode: .measurement, options: [])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "session_error", message: error.localizedDescription, details: nil)) }
                return
            }
            let input = self.engine.inputNode
            let format = input.outputFormat(forBus: 0)
            self.sampleRate = format.sampleRate
            self.samples.removeAll(keepingCapacity: true)
            self.samples.reserveCapacity(Int(self.sampleRate * (timeout + 2)))
            self.onsetIndex = nil
            self.detector = ImpulseAnalyzer.OnsetDetector(
                sampleRate: self.sampleRate, chunkSize: ImpulseAnalyzer.detectionChunk, thresholdDb: threshold
            )
            self.pendingResult = result
            self.capturing = true

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.queue.async { self?.consume(buffer) }
            }
            do {
                try self.engine.start()
            } catch {
                input.removeTap(onBus: 0)
                self.capturing = false
                self.pendingResult = nil
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                DispatchQueue.main.async { result(FlutterError(code: "engine_start_failed", message: error.localizedDescription, details: nil)) }
                return
            }
            NotificationCenter.default.addObserver(
                self, selector: #selector(self.handleInterruption(_:)),
                name: AVAudioSession.interruptionNotification, object: nil
            )
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler { [weak self] in
                self?.finish(with: nil, error: FlutterError(code: "no_impulse", message: "no impulse detected", details: nil))
            }
            timer.resume()
            self.timeoutTimer = timer
        }
    }

    /// queue上で呼ぶ。
    private func consume(_ buffer: AVAudioPCMBuffer) {
        guard capturing, let data = buffer.floatChannelData else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        let ptr = UnsafeBufferPointer(start: data[0], count: n)
        let startIndex = samples.count
        samples.append(contentsOf: ptr)

        if onsetIndex == nil {
            // tap バッファ(1024)を検出チャンク(256)に分けて流す。
            let chunk = ImpulseAnalyzer.detectionChunk
            var offset = 0
            while offset < n {
                let len = min(chunk, n - offset)
                var rms: Float = 0
                vDSP_rmsqv(ptr.baseAddress! + offset, 1, &rms, vDSP_Length(len))
                let power = Double(rms) * Double(rms)
                if detector?.push(power: power) == true {
                    onsetIndex = startIndex + offset
                    floorDbAtOnset = detector?.floorDb ?? ImpulseAnalyzer.db(fromPower: power) - 30
                    break
                }
                offset += len
            }
            if onsetIndex == nil { return }
        }
        let needed = onsetIndex! + Int(ImpulseAnalyzer.captureSeconds * sampleRate)
        if samples.count >= needed {
            if let payload = analyze() {
                finish(with: payload, error: nil)
            } else {
                finish(with: nil, error: FlutterError(code: "analysis_failed", message: "could not analyze impulse", details: nil))
            }
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            AVAudioSession.InterruptionType(rawValue: typeValue) == .began
        else { return }
        queue.async { [weak self] in
            self?.finish(with: nil, error: FlutterError(code: "interrupted", message: "audio session interrupted", details: nil))
        }
    }

    private func finish(with payload: [String: Any]?, error: FlutterError?) {
        guard capturing else { return }
        capturing = false
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        timeoutTimer?.cancel()
        timeoutTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let result = pendingResult
        pendingResult = nil
        DispatchQueue.main.async {
            if let payload { result?(payload) } else { result?(error) }
        }
    }

    // MARK: - 解析(本体は ImpulseAnalyzer。CLI から同じコードで検証できる)

    private func analyze() -> [String: Any]? {
        guard let onset = onsetIndex else { return nil }
        let pre = Int(ImpulseAnalyzer.preRollSeconds * sampleRate)
        let from = max(0, onset - pre)
        let to = min(samples.count, onset + Int(ImpulseAnalyzer.captureSeconds * sampleRate))
        let clip = Array(samples[from..<to])
        return ImpulseAnalyzer.analyze(
            clip: clip, onsetInClip: onset - from, sampleRate: sampleRate, floorDb: floorDbAtOnset
        )?.payload
    }
}
