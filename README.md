# voice-recorder-ios

[Fossify Voice Recorder](https://github.com/FossifyOrg/Voice-Recorder) re-created for iOS in SwiftUI, on top of `AVFoundation` (`AVAudioRecorder` / `AVAudioPlayer`).

    idl build -c release     # -> build/release/FossifyVoiceRecorder.ipa (ad-hoc signed; re-sign to install)
    idl install "<device>" FossifyVoiceRecorder

Ported: recorder with live amplitude visualizer, pause/resume (blinking while paused), save and discard; recording keeps running in the background; player with play/pause, previous/next, seek bar, ±10 s skips on the time labels, long-press title to copy, pause when headphones are unplugged; search; multi-select rename, share, open with, delete (to the recycle bin or skipping it), select all; recycle bin tab with restore/delete and 30-day expiry; colors, date and time format, start recording after launch, keep screen on, save folder (any Files folder, offering to move existing recordings), filename pattern, extension, bitrate, sample rate, microphone mode and recycle bin settings; the 1x1 record widget (white microphone, tinted while recording, tap to start or stop and save in the background; background color and transparency) inside launcher-ios. Recordings default to Files › On My iPhone › Voice Recorder › Recordings.

Differences forced by iOS: no mp3 (iOS has no encoder) and Opus is written as .caf instead of .ogg; microphone modes are the AVAudioSession modes iOS has (no voice performance/recognition); home-screen widgets are available inside launcher-ios only (iOS home-screen widgets would need a WidgetKit extension); no recording notification (iOS shows its own microphone indicator), "record sound" intent for other apps or in-app language switch.

GPL-3.0, like the original.
