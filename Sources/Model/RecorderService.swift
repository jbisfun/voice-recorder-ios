import AVFoundation
import FossifyCommons
import Foundation
import Observation
import UIKit

/// services/RecorderService.kt: one app-wide recorder that keeps running while the
/// app is in the background (UIBackgroundModes audio) or the launcher shows another app.
@MainActor
@Observable
final class RecorderService: NSObject, AVAudioRecorderDelegate {
    static let shared = RecorderService()

    private(set) var status: RecordingStatus = .stopped
    /// Seconds recorded so far.
    private(set) var duration = 0
    /// Amplitudes (0...1) for the visualizer, newest last.
    private(set) var amplitudes: [CGFloat] = []

    var isRunning: Bool { status != .stopped }

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var recordingURL: URL?

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            MainActor.assumeIsolated {
                // The system pauses the recorder during calls etc.; reflect it.
                if type == .began, self?.status == .running {
                    self?.status = .paused
                    self?.updateIdleTimer()
                }
            }
        }
    }

    /// The toggle button: start, or pause/resume a running recording.
    func toggle() {
        switch status {
        case .stopped: start()
        case .running, .paused: togglePause()
        }
    }

    // mp4 container with AAC (or CAF with Opus), mono, at the configured bitrate and sample rate.
    func start() {
        guard status == .stopped else { return }
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                if granted {
                    self.startRecording()
                } else {
                    RecordingsStore.shared.toast = "Audio permission is required"
                }
            }
        }
    }

    private func startRecording() {
        guard status == .stopped else { return }
        let config = Config.shared
        let store = RecordingsStore.shared
        let folder = store.folder
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("\(formattedFilename(config.filenamePattern)).\(config.extension_.fileExtension)")
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: config.microphoneMode.sessionMode, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: config.extension_.formatID,
                AVSampleRateKey: Double(config.samplingRate),
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: config.bitrate,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.record() else { throw RecorderError.couldNotStart }
            self.recorder = recorder
            recordingURL = url
            duration = 0
            amplitudes = []
            status = .running
            startTimer()
            updateIdleTimer()
        } catch {
            store.toast = "An error occurred: \(error.localizedDescription)"
            stopRecording(save: false)
        }
    }

    private func togglePause() {
        guard let recorder else { return }
        if status == .running {
            recorder.pause()
            status = .paused
        } else if status == .paused {
            try? AVAudioSession.sharedInstance().setActive(true)
            recorder.record()
            status = .running
        }
        updateIdleTimer()
    }

    /// saveRecording(): stopService -> stopRecording().
    func save() {
        stopRecording(save: true)
    }

    /// cancelRecording(): stop and delete the file.
    func cancel() {
        stopRecording(save: false)
    }

    private func stopRecording(save: Bool) {
        timer?.invalidate()
        timer = nil
        let recorded = recorder?.currentTime ?? 0
        recorder?.stop()
        let hadRecorder = recorder != nil
        recorder = nil
        status = .stopped
        duration = 0
        amplitudes = []
        updateIdleTimer()
        if !PlayerModel.shared.isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        let store = RecordingsStore.shared
        if let url = recordingURL, hadRecorder {
            if !save {
                try? FileManager.default.removeItem(at: url)
            } else if recorded < 0.5 {
                // MediaRecorder.stop() throws on (nearly) empty recordings.
                try? FileManager.default.removeItem(at: url)
                store.toast = "Recording was too short to record!"
            } else {
                store.toast = "Recording saved successfully"
            }
        }
        recordingURL = nil
        store.refresh()
    }

    /// Duration once a second and amplitude every 75 ms (AMPLITUDE_UPDATE_MS).
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.075, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard let recorder, status == .running else { return }
        recorder.updateMeters()
        let seconds = Int(recorder.currentTime)
        if seconds != duration { duration = seconds }
        // MediaRecorder.getMaxAmplitude() scaled like AudioRecordView (max reportable 22760 of 32767).
        let linear = pow(10, CGFloat(recorder.peakPower(forChannel: 0)) / 20)
        amplitudes.append(min(1, linear * 32767 / 22760))
        if amplitudes.count > 2000 { amplitudes.removeFirst(amplitudes.count - 2000) }
    }

    /// setKeepScreenAwake() while recording.
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = status == .running && Config.shared.keepScreenOn
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            RecordingsStore.shared.toast = "An error occurred: \(error?.localizedDescription ?? "")"
            self.stopRecording(save: true)
        }
    }

    enum RecorderError: LocalizedError {
        case couldNotStart
        var errorDescription: String? { "The recorder could not be started" }
    }
}
