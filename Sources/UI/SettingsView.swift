import FossifyCommons
import SwiftUI
import UniformTypeIdentifiers

/// SettingsActivity.
struct SettingsView: View {
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(RecordingsStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var dateFormat = false
    @State private var pickFolder = false
    @State private var move: PendingMove?
    @State private var filenamePattern = false
    @State private var pickExtension = false
    @State private var pickBitrate = false
    @State private var pickSamplingRate = false
    @State private var micWarning = false
    @State private var pickMicMode = false
    @State private var confirmEmpty = false

    var body: some View {
        @Bindable var config = config
        VStack(spacing: 0) {
            TopBar(title: "Settings")
            ScrollView {
                VStack(spacing: 0) {
                    Text("Color customization").sectionHeader(palette)
                    SettingsItem("Customize colors") { router.push(.customizeColors) }

                    Text("General").sectionHeader(palette)
                    SettingsItem("Change date and time format") { dateFormat = true }

                    Text("Recording").sectionHeader(palette)
                    SettingsToggle("Start recording automatically after launching the app", isOn: $config.recordAfterLaunch)
                    SettingsToggle("Keep the screen on during recording", isOn: $config.keepScreenOn)
                    SettingsItem("Save recordings in", value: Folders.humanized(store.folder)) { pickFolder = true }
                    SettingsItem("Filename pattern", value: config.filenamePattern) { filenamePattern = true }
                    SettingsItem("Extension", value: config.extension_.title) { pickExtension = true }

                    Text("Audio").sectionHeader(palette)
                    SettingsItem("Bitrate", value: bitrateText(config.bitrate)) { pickBitrate = true }
                    SettingsItem("Sample rate", value: "\(config.samplingRate) Hz") { pickSamplingRate = true }
                    SettingsItem("Microphone mode", value: config.microphoneMode.title) {
                        if config.wasMicModeWarningShown { pickMicMode = true } else { micWarning = true }
                    }

                    Text("Recycle bin").sectionHeader(palette)
                    SettingsToggle("Move deleted items to recycle bin", isOn: $config.useRecycleBin)
                    if config.useRecycleBin {
                        SettingsItem("Empty the recycle bin", value: store.trashSize.formattedSize) {
                            if store.trashed.isEmpty { store.toast = "The recycle bin is empty" } else { confirmEmpty = true }
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear { store.refresh() }
        .sheet(isPresented: $dateFormat) { ChangeDateTimeFormatDialog() }
        .sheet(isPresented: $filenamePattern) { FilenamePatternDialog() }
        .sheet(isPresented: $pickExtension) {
            RadioDialog(title: nil, items: Ext.allCases.map { ($0, $0.title) }, selected: config.extension_) {
                config.extension_ = $0
                config.adjustBitrate()
                config.adjustSamplingRate()
            }
        }
        .sheet(isPresented: $pickBitrate) {
            RadioDialog(title: nil, items: config.extension_.bitrates.map { ($0, bitrateText($0)) }, selected: config.bitrate) {
                config.bitrate = $0
                config.adjustSamplingRate()
            }
        }
        .sheet(isPresented: $pickSamplingRate) {
            RadioDialog(title: nil, items: config.availableSamplingRates.map { ($0, "\($0) Hz") }, selected: config.samplingRate) {
                config.samplingRate = $0
            }
        }
        .sheet(isPresented: $pickMicMode) {
            RadioDialog(title: nil, items: MicMode.allCases.map { ($0, $0.title) }, selected: config.microphoneMode) {
                config.microphoneMode = $0
            }
        }
        .alert("Microphone mode", isPresented: $micWarning) {
            Button("OK") {
                config.wasMicModeWarningShown = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pickMicMode = true }
            }
        } message: {
            Text("This changes how your device routes and processes audio. Results vary by device and can impact volume, noise, and other factors.")
        }
        .alert("Are you sure you want to empty the recycle bin? The files will be permanently lost.", isPresented: $confirmEmpty) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) { store.emptyTrash() }
        }
        .fileImporter(isPresented: $pickFolder, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result, let bookmark = Folders.bookmark(for: url) else { return }
            let current = store.folder
            let new = Folders.url(bookmark)
            let apply = {
                config.saveRecordingsFolder = new.standardizedFileURL == Folders.defaultFolder.standardizedFileURL ? nil : bookmark
                store.refresh()
            }
            if new.standardizedFileURL != current.standardizedFileURL && store.hasRecordings(in: current) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { move = PendingMove(from: current, to: new, apply: apply) }
            } else {
                apply()
            }
        }
        .sheet(item: $move) { m in MoveRecordingsDialog(from: m.from, to: m.to, onDone: m.apply) }
    }

    private func bitrateText(_ value: Int) -> String { "\(value / 1000) kbps" }
}

struct PendingMove: Identifiable {
    let from: URL
    let to: URL
    let apply: () -> Void
    var id: URL { to }
}

extension AppInfo {
    public static let voiceRecorder = AppInfo(
        name: "Voice Recorder", icon: "waveform", upstream: "Voice-Recorder", port: "voice-recorder-ios", policy: "voice-recorder",
        faq: [("How can I select multiple items at once?",
               "Long press one item to start the selection mode, then tap other items to select them. Use Select all from the menu to select everything.")])
}
