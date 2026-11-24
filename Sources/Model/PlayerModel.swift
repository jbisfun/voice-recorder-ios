import AVFoundation
import FossifyCommons
import Foundation
import Observation

/// The MediaPlayer half of PlayerFragment.
@MainActor
@Observable
final class PlayerModel: NSObject, AVAudioPlayerDelegate {
    static let shared = PlayerModel()

    private(set) var current: Recording?
    private(set) var isPlaying = false
    /// Seconds.
    private(set) var progress = 0
    var max: Int { current?.duration ?? 0 }
    /// playedRecordingIDs.
    @ObservationIgnored var playedIDs: [String] = []

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?

    private override init() {
        super.init()
        // BecomingNoisyReceiver: pause when headphones are unplugged.
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init)
            MainActor.assumeIsolated {
                if reason == .oldDeviceUnavailable, self?.isPlaying == true { self?.pause() }
            }
        }
    }

    func play(_ recording: Recording, playOnPrepared: Bool) {
        current = recording
        progress = 0
        timer?.invalidate()
        player?.stop()
        player = nil
        isPlaying = false
        do {
            if !RecorderService.shared.isRunning {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            }
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: recording.url)
            p.delegate = self
            p.prepareToPlay()
            player = p
        } catch {
            RecordingsStore.shared.toast = "An error occurred: \(error.localizedDescription)"
            return
        }
        if playOnPrepared { resume() }
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func resume() {
        guard let player else { return }
        player.play()
        isPlaying = true
        startTimer()
    }

    /// Clears the player when the list becomes empty (resetProgress(null)).
    func reset() {
        pause()
        player?.stop()
        player = nil
        current = nil
        progress = 0
    }

    /// Seek bar drag.
    func seek(to seconds: Int) {
        guard let player else { return }
        player.currentTime = TimeInterval(seconds)
        progress = seconds
        resume()
    }

    /// Tapping the current/max time skips 10 seconds back/forward.
    func skip(forward: Bool) {
        guard !playedIDs.isEmpty, let player else { return }
        player.currentTime = min(player.duration, Swift.max(0, player.currentTime + (forward ? fastForwardSkip : -fastForwardSkip)))
        progress = Int(player.currentTime.rounded())
        resume()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let player = self.player else { return }
                self.progress = Int(player.currentTime.rounded())
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.timer?.invalidate()
            self.isPlaying = false
            self.progress = self.max
        }
    }
}
