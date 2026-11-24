import Foundation

/// The recorder as seen from outside the app (the launcher's quick settings record tile).
@MainActor
public enum VoiceRecorderControls {
    /// Recording or paused.
    public static var isRecording: Bool { RecorderService.shared.isRunning }
    public static var isPaused: Bool { RecorderService.shared.status == .paused }
    /// Seconds recorded so far.
    public static var duration: Int { RecorderService.shared.duration }

    /// The app's record button: start, or pause/resume a running recording.
    public static func toggle() { RecorderService.shared.toggle() }
}
