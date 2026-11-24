import FossifyCommons
import SwiftUI

/// dialogs/DeleteConfirmationDialog.kt.
struct DeleteConfirmationDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let message: String
    let showSkipRecycleBinOption: Bool
    let onConfirm: (_ skipRecycleBin: Bool) -> Void
    @State private var skip = false

    var body: some View {
        DialogFrame(title: nil, scroll: false) {
            Text(message).font(.system(size: 18)).padding(.bottom, 16)
            if showSkipRecycleBinOption {
                CheckRow(title: "Skip the recycle bin, delete files directly", on: $skip)
            }
            DialogButtons(ok: "Yes") {
                dismiss()
                onConfirm(skip)
            }
        }
    }
}

/// dialogs/RenameRecordingDialog.kt.
struct RenameRecordingDialog: View {
    @Environment(RecordingsStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let recording: Recording
    let onDone: () -> Void
    @State private var title = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        DialogFrame(title: "Rename", scroll: false) {
            TextField("", text: $title)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(palette.primaryColor).frame(height: 1) }
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(.red).padding(.top, 6)
            }
            DialogButtons {
                let newTitle = title.trimmingCharacters(in: .whitespaces)
                if newTitle.isEmpty {
                    error = "Please enter a name"
                } else if !newTitle.isAValidFilename {
                    error = "The name contains invalid characters"
                } else {
                    store.rename(recording, to: newTitle)
                    onDone()
                    dismiss()
                }
            }
        }
        .onAppear {
            title = recording.url.deletingPathExtension().lastPathComponent
            focused = true
        }
    }
}

/// dialogs/FilenamePatternDialog.kt + DateTimePatternInfoDialog.
struct FilenamePatternDialog: View {
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var pattern = ""
    @State private var info = false
    @FocusState private var focused: Bool

    var body: some View {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        let error = validate(trimmed)
        DialogFrame(title: "Filename pattern", scroll: false) {
            HStack {
                TextField("", text: $pattern, prompt: Text("Filename pattern").foregroundStyle(palette.secondaryText))
                    .focused($focused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button { info = true } label: { Image(systemName: "info.circle").font(.system(size: 20)) }
                    .foregroundStyle(palette.textColor)
            }
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(error == nil ? palette.primaryColor : .red).frame(height: 1) }
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(.red).padding(.top, 6)
            }
            DialogButtons(okEnabled: error == nil) {
                config.filenamePattern = trimmed
                dismiss()
            }
        }
        .onAppear {
            pattern = config.filenamePattern
            focused = true
        }
        .alert("", isPresented: $info) {
            Button("OK") {}
        } message: {
            Text("You can use the following patterns to name your file automatically:\n\n%Y - year\n%M - month\n%D - day\n%h - hour\n%m - minute\n%s - second")
        }
    }

    private func validate(_ p: String) -> String? {
        if p.isEmpty { return "Filename cannot be empty" }
        if !p.isAValidFilename { return "The name contains invalid characters" }
        if !["%Y", "%M", "%D", "%h", "%m", "%s"].allSatisfy({ p.contains($0) }) {
            return "Must include all placeholders for unique filenames (%Y, %M, %D, %h, %m, %s)"
        }
        return nil
    }
}

/// dialogs/MoveRecordingsDialog.kt: offers moving existing recordings into the new folder;
/// `onDone` (switching the folder) runs whatever the answer.
struct MoveRecordingsDialog: View {
    @Environment(RecordingsStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let from: URL
    let to: URL
    let onDone: () -> Void
    @State private var moving = false

    var body: some View {
        DialogFrame(title: "Move recordings", scroll: false) {
            Text("You have existing recordings. Do you want to move them to your new folder?")
                .opacity(moving ? 0.5 : 1)
            if moving {
                ProgressView().tint(palette.primaryColor).frame(maxWidth: .infinity).padding(.top, 16)
            }
            HStack(spacing: 24) {
                Spacer()
                Button("No") { dismiss() }
                Button("Yes") {
                    moving = true
                    Task {
                        await store.moveAll(from: from, to: to)
                        dismiss()
                    }
                }
            }
            .disabled(moving)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(palette.primaryColor)
            .padding(.top, 16)
        }
        .interactiveDismissDisabled(moving)
        .onDisappear(perform: onDone)
    }
}
