import AVFoundation
import Foundation

/// helpers/Constants.kt.
enum Ext: Int, CaseIterable {
    /// EXTENSION_M4A / EXTENSION_OGG keep their upstream values; there is no mp3 encoder on iOS.
    case m4a = 0, opus = 2

    /// getExtensionText().
    var title: String {
        switch self {
        case .m4a: return "m4a"
        case .opus: return "caf (Opus)"
        }
    }

    /// getExtension(): the file extension written.
    var fileExtension: String {
        switch self {
        case .m4a: return "m4a"
        case .opus: return "caf"
        }
    }

    var formatID: AudioFormatID {
        switch self {
        case .m4a: return kAudioFormatMPEG4AAC
        case .opus: return kAudioFormatOpus
        }
    }

    var bitrates: [Int] {
        switch self {
        case .m4a: return [8000, 14000, 24000, 28000, 32000, 64000, 96000, 128000, 160000, 192000, 288000]
        case .opus: return [8000, 16000, 24000, 32000, 64000, 96000, 128000, 160000, 192000, 256000, 320000]
        }
    }

    var samplingRates: [Int] {
        switch self {
        case .m4a: return [11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000]
        case .opus: return [8000, 12000, 16000, 24000, 48000]
        }
    }

    /// SAMPLING_RATE_BITRATE_LIMITS: sampling rate -> min...max bitrate.
    var limits: [Int: ClosedRange<Int>] {
        switch self {
        case .m4a:
            return [11025: 8000...15999, 12000: 8000...15999, 16000: 8000...31999, 22050: 24000...31999,
                    24000: 24000...31999, 32000: 32000...160000, 44100: 56000...160000, 48000: 56000...288000]
        case .opus:
            return [8000: 8000...320000, 12000: 16000...320000, 16000: 28000...320000,
                    24000: 48000...320000, 48000: 64000...320000]
        }
    }
}

let defaultBitrate = 96000
let defaultSamplingRate = 48000
let defaultFilenamePattern = "%Y%M%D_%h%m%s"
let defaultRecordingsFolder = "Recordings"
let fastForwardSkip: TimeInterval = 10
let monthSeconds: TimeInterval = 30 * 24 * 3600
let daySeconds: TimeInterval = 24 * 3600

/// Microphone modes: upstream MediaRecorder.AudioSource ids mapped to AVAudioSession modes.
enum MicMode: Int, CaseIterable {
    case systemDefault = 0, camcorder = 5, voiceCommunication = 7, unprocessed = 9

    var title: String {
        switch self {
        case .systemDefault: return "System default"
        case .camcorder: return "Camera (video)"
        case .voiceCommunication: return "Voice communication (auto gain)"
        case .unprocessed: return "Unprocessed (raw)"
        }
    }

    var sessionMode: AVAudioSession.Mode {
        switch self {
        case .systemDefault: return .default
        case .camcorder: return .videoRecording
        case .voiceCommunication: return .voiceChat
        case .unprocessed: return .measurement
        }
    }
}

enum RecordingStatus {
    case running, stopped, paused
}

/// Context.getFormattedFilename().
func formattedFilename(_ pattern: String, date: Date = Date()) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    func two(_ v: Int?) -> String { String(format: "%02d", v ?? 0) }
    return pattern
        .replacingOccurrences(of: "%Y", with: "\(c.year ?? 0)")
        .replacingOccurrences(of: "%M", with: two(c.month))
        .replacingOccurrences(of: "%D", with: two(c.day))
        .replacingOccurrences(of: "%h", with: two(c.hour))
        .replacingOccurrences(of: "%m", with: two(c.minute))
        .replacingOccurrences(of: "%s", with: two(c.second))
}
