import AVFoundation
import Flutter
import UIKit

/// マイクからの騒音計測をFlutterへ橋渡しするプラグイン。
/// - MethodChannel: 権限確認・計測の開始/キャンセル
/// - EventChannel: 計測中のライブdBメーター更新
public class SoundMeterPlugin: NSObject, FlutterPlugin {
    private enum StopReason {
        case completed
        case finishedByUser
        case userCancelled
        case interrupted
        case backgrounded
        case routeChanged
    }

    private static let methodChannelName = "jp.pairof.sound_shield/sound_meter"
    private static let eventChannelName = "jp.pairof.sound_shield/sound_meter/live"

    private let engine = AVAudioEngine()
    private let sessionQueue = DispatchQueue(label: "jp.pairof.sound_shield.session")

    private var analysisTimer: DispatchSourceTimer?
    private var liveTimer: DispatchSourceTimer?
    private var completionTimer: DispatchSourceTimer?

    private var spectrumAnalyzer: AudioSpectrumAnalyzer?
    private var soundClassifier: SoundClassifier?

    private var eventSink: FlutterEventSink?
    private var pendingResult: FlutterResult?
    private var isMeasuring = false
    /// nilなら「止めるまで測定」する時間無指定モード。完了タイマーは張らない。
    private var measurementDuration: TimeInterval?
    private var measurementStart: CFAbsoluteTime = 0
    private var startFramePosition: AVAudioFramePosition?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SoundMeterPlugin()
        let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkAndRequestPermission":
            requestPermission(result: result)
        case "startMeasurement":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
                return
            }
            // durationSeconds未指定(nil)は「止めるまで測定」する時間無指定モード。
            let durationSeconds = args["durationSeconds"] as? Int
            if let durationSeconds, durationSeconds <= 0 {
                result(FlutterError(code: "invalid_args", message: "durationSeconds must be positive", details: nil))
                return
            }
            startMeasurement(durationSeconds: durationSeconds, result: result)
        case "finishMeasurement":
            sessionQueue.async { [weak self] in
                self?.stopMeasurement(reason: .finishedByUser)
            }
            result(nil)
        case "cancelMeasurement":
            sessionQueue.async { [weak self] in
                self?.stopMeasurement(reason: .userCancelled)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { result(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { result(granted) }
            }
        }
    }

    private func hasRecordPermission() -> Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    private func startMeasurement(durationSeconds: Int?, result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isMeasuring else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "already_measuring", message: "Measurement already in progress", details: nil))
                }
                return
            }
            guard self.hasRecordPermission() else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "permission_denied", message: "Microphone permission not granted", details: nil))
                }
                return
            }

            do {
                try self.configureAudioSession()
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "session_error", message: error.localizedDescription, details: nil))
                }
                return
            }

            guard self.isUsingBuiltInMic() else {
                self.deactivateSession()
                DispatchQueue.main.async {
                    result(FlutterError(code: "non_built_in_mic", message: "Built-in microphone is required for measurement", details: nil))
                }
                return
            }

            let inputNode = self.engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard let spectrumAnalyzer = AudioSpectrumAnalyzer(sampleRate: format.sampleRate) else {
                self.deactivateSession()
                DispatchQueue.main.async {
                    result(FlutterError(code: "fft_setup_failed", message: "Failed to set up FFT", details: nil))
                }
                return
            }
            self.spectrumAnalyzer = spectrumAnalyzer
            // 分類器の初期化に失敗しても周波数分析は続行する(nilのまま扱う)。
            self.soundClassifier = try? SoundClassifier(format: format)

            self.startFramePosition = nil
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
                guard let self = self else { return }
                if self.startFramePosition == nil {
                    self.startFramePosition = time.sampleTime
                    self.soundClassifier?.referenceFramePosition = time.sampleTime
                }
                self.spectrumAnalyzer?.append(buffer)
                self.soundClassifier?.analyze(buffer, at: time.sampleTime)
            }

            do {
                try self.engine.start()
            } catch {
                inputNode.removeTap(onBus: 0)
                self.deactivateSession()
                self.spectrumAnalyzer = nil
                self.soundClassifier = nil
                DispatchQueue.main.async {
                    result(FlutterError(code: "engine_start_failed", message: error.localizedDescription, details: nil))
                }
                return
            }

            self.isMeasuring = true
            self.measurementDuration = durationSeconds.map { TimeInterval($0) }
            self.measurementStart = CFAbsoluteTimeGetCurrent()
            self.pendingResult = result
            self.registerNotifications()
            self.startAnalysisTimer()
            self.startLiveTimer()
            // 時間指定モードだけ完了タイマーを張る。無指定なら「止めるまで測定」で
            // finishMeasurement/cancelMeasurementが呼ばれるまで動き続ける。
            if let measurementDuration = self.measurementDuration {
                self.startCompletionTimer(after: measurementDuration)
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .measurementモードでAGC/ノイズ抑制/ビームフォーミングを最小化する。
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func isUsingBuiltInMic() -> Bool {
        guard let input = AVAudioSession.sharedInstance().currentRoute.inputs.first else { return false }
        return input.portType == .builtInMic
    }

    private func startAnalysisTimer() {
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + .milliseconds(300), repeating: .milliseconds(300))
        timer.setEventHandler { [weak self] in
            self?.spectrumAnalyzer?.processIfReady()
        }
        timer.resume()
        analysisTimer = timer
    }

    private func startLiveTimer() {
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + .milliseconds(200), repeating: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            guard let self = self, let db = self.spectrumAnalyzer?.latestOverallDb else { return }
            DispatchQueue.main.async {
                self.eventSink?(["overallDb": db])
            }
        }
        timer.resume()
        liveTimer = timer
    }

    private func startCompletionTimer(after duration: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + duration)
        timer.setEventHandler { [weak self] in
            self?.stopMeasurement(reason: .completed)
        }
        timer.resume()
        completionTimer = timer
    }

    /// sessionQueue上で呼ぶこと。
    private func stopMeasurement(reason: StopReason) {
        guard isMeasuring else { return }
        isMeasuring = false

        analysisTimer?.cancel()
        liveTimer?.cancel()
        completionTimer?.cancel()
        analysisTimer = nil
        liveTimer = nil
        completionTimer = nil

        removeNotifications()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        // タップを外した後で呼ぶことでanalyze呼び出しとの競合を避ける。
        spectrumAnalyzer?.processIfReady()
        soundClassifier?.stop()
        deactivateSession()

        let elapsed = CFAbsoluteTimeGetCurrent() - measurementStart
        let result = pendingResult
        pendingResult = nil

        switch reason {
        case .completed, .finishedByUser:
            let spectrum = spectrumAnalyzer?.finalizeResult()
            let labels = soundClassifier?.finalizeResult(measurementDuration: elapsed) ?? []
            let timeline = soundClassifier?.finalizeTimeline() ?? []
            let payload = Self.buildPayload(
                // 実際に計測できた時間を報告する(時間指定モードでも要求値との
                // わずかなズレを避けるため、要求値ではなく実測値を使う)。
                durationSeconds: Int(elapsed.rounded()),
                spectrum: spectrum,
                labels: labels,
                timeline: timeline
            )
            DispatchQueue.main.async { result?(payload) }
        case .userCancelled, .interrupted, .backgrounded, .routeChanged:
            DispatchQueue.main.async { result?(["cancelled": true]) }
        }

        spectrumAnalyzer = nil
        soundClassifier = nil
    }

    private static func buildPayload(
        durationSeconds: Int,
        spectrum: AudioSpectrumAnalyzer.Result?,
        labels: [SoundClassifier.LabelResult],
        timeline: [SoundClassifier.TimelineSegment]
    ) -> [String: Any] {
        let bands = (spectrum?.bands ?? []).map { band -> [String: Any] in
            [
                "centerHz": band.centerHz,
                "leqDb": band.leqDb,
                "peakDb": band.peakDb,
                "minDb": band.minDb,
            ]
        }
        let soundLabels = labels.map { label -> [String: Any] in
            [
                "identifier": label.identifier,
                "activeShare": label.activeShare,
                "avgConfidence": label.avgConfidence,
            ]
        }
        let timeSeries = (spectrum?.timeSeries ?? []).map { point -> [String: Any] in
            ["t": point.t, "db": point.db]
        }
        let soundTimeline = timeline.map { segment -> [String: Any] in
            [
                "startSeconds": segment.start,
                "endSeconds": segment.end,
                "identifier": segment.identifier,
                "confidence": segment.confidence,
            ]
        }
        return [
            "durationSeconds": durationSeconds,
            "overallLeqDb": spectrum?.overallLeqDb ?? 0,
            "overallPeakDb": spectrum?.overallPeakDb ?? 0,
            "overallMinDb": spectrum?.overallMinDb ?? 0,
            "bands": bands,
            "soundLabels": soundLabels,
            "timeSeries": timeSeries,
            "soundTimeline": soundTimeline,
        ]
    }

    // MARK: - 割り込み・状態変化(フォアグラウンド限定、最小限の対応)

    private func registerNotifications() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(handleResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    private func removeNotifications() {
        let center = NotificationCenter.default
        center.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        center.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        center.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue),
            type == .began
        else { return }
        sessionQueue.async { [weak self] in self?.stopMeasurement(reason: .interrupted) }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isMeasuring else { return }
            if !self.isUsingBuiltInMic() {
                self.stopMeasurement(reason: .routeChanged)
            }
        }
    }

    @objc private func handleResignActive() {
        sessionQueue.async { [weak self] in self?.stopMeasurement(reason: .backgrounded) }
    }
}

extension SoundMeterPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
