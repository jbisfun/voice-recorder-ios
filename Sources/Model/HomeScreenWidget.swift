import FossifyCommons
import Foundation

/// The iOS home-screen record widget (fossify-ios/widgets-ios): publishes whether a recording is
/// running and registers the actions its button runs in the app process
/// (BackgroundRecordActivity: start, or stop and save).
public enum VoiceRecorderWidgetData {
    static let snapshotName = "voicerecorder"

    /// Call once at launch (LauncherApp.init), also when iOS starts the app for the widget button.
    @MainActor
    public static func install() {
        WidgetBridge.register("voicerecorder.start") {
            if !RecorderService.shared.isRunning { RecorderService.shared.start() }
        }
        WidgetBridge.register("voicerecorder.stop") {
            if RecorderService.shared.isRunning { RecorderService.shared.save() }
        }
        WidgetBridge.track { publish() }
    }

    /// `fossify://open/voicerecorder`: the app opens on the recorder.
    @MainActor
    public static func handle(_ url: URL) {}

    @MainActor
    static func publish() {
        let recorder = RecorderService.shared
        let snapshot = RecorderWidgetSnapshot(isRecording: recorder.isRunning, isPaused: recorder.status == .paused)
        WidgetBridge.save(snapshot, snapshotName, reload: [WidgetKinds.voiceRecorder])
    }
}
