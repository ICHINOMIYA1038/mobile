import AVFoundation
import SoundAnalysis

/// マイク入力から音源の種類(交通音・話し声・犬の鳴き声 等)を推定する。
/// `analyze` はtapコールバックのスレッドから直接同期的に呼び出す想定
/// (Apple公式サンプルと同じ呼び方。軽量なため非同期化は不要)。
final class SoundClassifier: NSObject {
    struct LabelResult {
        let identifier: String
        let activeShare: Double
        let avgConfidence: Double
    }

    struct TimelineSegment {
        let start: TimeInterval
        let end: TimeInterval
        let identifier: String
        let confidence: Double
    }

    private static let confidenceThreshold: Double = 0.5
    private static let maxResults = 5

    private let analyzer: SNAudioStreamAnalyzer
    private let sampleRate: Double
    private let lock = NSLock()
    private var activeDuration: [String: TimeInterval] = [:]
    private var confidenceSum: [String: Double] = [:]
    private var confidenceCount: [String: Int] = [:]
    private var timeline: [TimelineSegment] = []

    /// 計測開始時に最初のtapバッファのsampleTimeを渡す。SNAudioStreamAnalyzerの
    /// timeRangeはエンジン起動からの絶対時刻なので、これを引いて計測開始を0秒に揃える。
    var referenceFramePosition: AVAudioFramePosition?

    init(format: AVAudioFormat) throws {
        analyzer = SNAudioStreamAnalyzer(format: format)
        sampleRate = format.sampleRate
        super.init()
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        try analyzer.add(request, withObserver: self)
    }

    /// tapコールバックのスレッドから直接呼ぶ。
    func analyze(_ buffer: AVAudioPCMBuffer, at framePosition: AVAudioFramePosition) {
        analyzer.analyze(buffer, atAudioFramePosition: framePosition)
    }

    /// tapを外した後、engine停止と同じタイミングで呼ぶ(analyzeとの同時実行を避ける)。
    func stop() {
        analyzer.removeAllRequests()
    }

    func finalizeResult(measurementDuration: TimeInterval) -> [LabelResult] {
        lock.lock()
        defer { lock.unlock() }
        guard measurementDuration > 0 else { return [] }
        let results = activeDuration.map { identifier, duration -> LabelResult in
            let count = max(confidenceCount[identifier] ?? 1, 1)
            let avgConfidence = (confidenceSum[identifier] ?? 0) / Double(count)
            return LabelResult(
                identifier: identifier,
                activeShare: min(duration / measurementDuration, 1.0),
                avgConfidence: avgConfidence
            )
        }
        return Array(results.sorted { $0.activeShare > $1.activeShare }.prefix(Self.maxResults))
    }

    /// 生の時系列セグメント(重ね合わせグラフ用)。時間順。
    func finalizeTimeline() -> [TimelineSegment] {
        lock.lock()
        defer { lock.unlock() }
        return timeline.sorted { $0.start < $1.start }
    }
}

extension SoundClassifier: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let duration = result.timeRange.duration.seconds
        guard duration.isFinite, duration > 0 else { return }

        let refSeconds = Double(referenceFramePosition ?? 0) / sampleRate
        let startSeconds = max(0, result.timeRange.start.seconds - refSeconds)
        let endSeconds = startSeconds + duration

        lock.lock()
        for classification in result.classifications where classification.confidence >= Self.confidenceThreshold {
            activeDuration[classification.identifier, default: 0] += duration
            confidenceSum[classification.identifier, default: 0] += classification.confidence
            confidenceCount[classification.identifier, default: 0] += 1
            timeline.append(TimelineSegment(
                start: startSeconds,
                end: endSeconds,
                identifier: classification.identifier,
                confidence: classification.confidence
            ))
        }
        lock.unlock()
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        // 分類の失敗は致命的ではない(周波数分析側の結果は独立して有効なため)ので無視する。
    }

    func requestDidComplete(_ request: SNRequest) {}
}
