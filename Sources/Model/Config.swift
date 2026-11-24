import FossifyCommons
import Foundation
import Observation

/// Port of the voice recorder Config (SharedPreferences -> UserDefaults); colors live in FossifyCommons.BaseConfig.
@Observable
final class Config {
    static let shared = Config()

    @ObservationIgnored private let d = UserDefaults.standard

    /// Security-scoped bookmark of the folder picked in "Save recordings in"; nil = Documents/Recordings.
    var saveRecordingsFolder: Data? { didSet { d.set(saveRecordingsFolder, forKey: "save_recordings") } }
    var extension_: Ext { didSet { d.set(extension_.rawValue, forKey: "extension") } }
    var microphoneMode: MicMode { didSet { d.set(microphoneMode.rawValue, forKey: "microphone_mode") } }
    var bitrate: Int { didSet { d.set(bitrate, forKey: "bitrate") } }
    var samplingRate: Int { didSet { d.set(samplingRate, forKey: "sampling_rate") } }
    var recordAfterLaunch: Bool { didSet { d.set(recordAfterLaunch, forKey: "record_after_launch") } }
    var useRecycleBin: Bool { didSet { d.set(useRecycleBin, forKey: "use_recycle_bin") } }
    var lastRecycleBinCheck: Double { didSet { d.set(lastRecycleBinCheck, forKey: "last_recycle_bin_check") } }
    var keepScreenOn: Bool { didSet { d.set(keepScreenOn, forKey: "keep_screen_on") } }
    var wasMicModeWarningShown: Bool { didSet { d.set(wasMicModeWarningShown, forKey: "was_mic_mode_warning_shown") } }
    var filenamePattern: String { didSet { d.set(filenamePattern, forKey: "filename_pattern") } }
    var lastUsedViewPagerPage: Int { didSet { d.set(lastUsedViewPagerPage, forKey: "last_used_view_pager_page") } }

    private init() {
        saveRecordingsFolder = d.data(forKey: "save_recordings")
        extension_ = Ext(rawValue: d.object(forKey: "extension") as? Int ?? Ext.m4a.rawValue) ?? .m4a
        microphoneMode = MicMode(rawValue: d.object(forKey: "microphone_mode") as? Int ?? 0) ?? .systemDefault
        bitrate = d.object(forKey: "bitrate") as? Int ?? defaultBitrate
        samplingRate = d.object(forKey: "sampling_rate") as? Int ?? defaultSamplingRate
        recordAfterLaunch = d.object(forKey: "record_after_launch") as? Bool ?? false
        useRecycleBin = d.object(forKey: "use_recycle_bin") as? Bool ?? true
        lastRecycleBinCheck = d.double(forKey: "last_recycle_bin_check")
        keepScreenOn = d.object(forKey: "keep_screen_on") as? Bool ?? true
        wasMicModeWarningShown = d.object(forKey: "was_mic_mode_warning_shown") as? Bool ?? false
        filenamePattern = d.string(forKey: "filename_pattern") ?? defaultFilenamePattern
        lastUsedViewPagerPage = d.object(forKey: "last_used_view_pager_page") as? Int ?? 0
    }

    /// SettingsActivity.getSamplingRatesArray().
    var availableSamplingRates: [Int] {
        let limits = extension_.limits
        return extension_.samplingRates.filter { limits[$0]?.contains(bitrate) ?? false }
    }

    /// adjustBitrate(): snap to the closest bitrate the format offers.
    func adjustBitrate() {
        let available = extension_.bitrates
        if !available.contains(bitrate) {
            let current = bitrate
            bitrate = available.min { abs($0 - current) < abs($1 - current) } ?? defaultBitrate
        }
    }

    /// adjustSamplingRate().
    func adjustSamplingRate() {
        let available = availableSamplingRates
        if !available.contains(samplingRate) {
            samplingRate = available.contains(defaultSamplingRate) ? defaultSamplingRate : (available.last ?? defaultSamplingRate)
        }
    }
}
