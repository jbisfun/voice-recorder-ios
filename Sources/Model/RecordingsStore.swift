import AVFoundation
import FossifyCommons
import Foundation
import Observation

/// models/Recording.kt.
struct Recording: Identifiable, Hashable {
    let url: URL
    let title: String
    let timestamp: Date
    /// Seconds.
    let duration: Int
    let size: Int64

    var id: String { url.path }
}

/// Where recordings live: Documents/Recordings (Files › On My iPhone) unless the user picked another folder.
enum Folders {
    static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var defaultFolder: URL { documents.appendingPathComponent(defaultRecordingsFolder, isDirectory: true) }

    nonisolated(unsafe) private static var resolved: (Data, URL)?

    /// Resolves the stored security-scoped bookmark (and keeps access to it for the app's lifetime).
    static func url(_ bookmark: Data?) -> URL {
        guard let bookmark else { return defaultFolder }
        if let resolved, resolved.0 == bookmark { return resolved.1 }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return defaultFolder
        }
        _ = url.startAccessingSecurityScopedResource()
        resolved = (bookmark, url)
        return url
    }

    /// Bookmark for a folder returned by the system folder picker.
    static func bookmark(for url: URL) -> Data? {
        _ = url.startAccessingSecurityScopedResource()
        return try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// humanizePath().
    static func humanized(_ url: URL) -> String {
        if url.standardizedFileURL == defaultFolder.standardizedFileURL {
            let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Voice Recorder"
            return "On My iPhone/\(app)/\(defaultRecordingsFolder)"
        }
        let parent = url.deletingLastPathComponent().lastPathComponent
        return parent.isEmpty ? url.lastPathComponent : "\(parent)/\(url.lastPathComponent)"
    }

    /// isAudioFast(): audio file extensions.
    static let audioExtensions: Set<String> = ["mp3", "wav", "wma", "ogg", "m4a", "opus", "flac", "aac", "m4b", "caf", "amr", "3gp", "aif", "aiff"]
}

/// The recording file operations of extensions/Context.kt and extensions/Activity.kt.
@MainActor
@Observable
final class RecordingsStore {
    static let shared = RecordingsStore()

    var recordings: [Recording] = []
    var trashed: [Recording] = []
    var loading = false
    var loadingTrash = false
    var toast: String?
    /// Bumped whenever recordings change on disk (EventBus RecordingCompleted / RecordingTrashUpdated).
    var generation = 0

    @ObservationIgnored private let fm = FileManager.default

    var folder: URL { Folders.url(Config.shared.saveRecordingsFolder) }
    var trashFolder: URL { folder.appendingPathComponent(".trash", isDirectory: true) }

    func refresh() {
        generation += 1
        let folder = folder, trash = trashFolder
        if recordings.isEmpty { loading = true }
        if trashed.isEmpty { loadingTrash = true }
        Task {
            let r = await Self.read(folder)
            let t = await Self.read(trash)
            recordings = r
            trashed = t
            loading = false
            loadingTrash = false
        }
    }

    /// getAllRecordings(): every audio file in a folder with its duration and size.
    nonisolated static func read(_ dir: URL) async -> [Recording] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        var result: [Recording] = []
        for url in files where Folders.audioExtensions.contains(url.pathExtension.lowercased()) {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile ?? true else { continue }
            var duration = 0
            if let time = try? await AVURLAsset(url: url).load(.duration), time.isNumeric {
                duration = Int(time.seconds.rounded())
            }
            result.append(Recording(url: url, title: url.lastPathComponent, timestamp: values?.contentModificationDate ?? Date(),
                                    duration: duration, size: Int64(values?.fileSize ?? 0)))
        }
        return result.sorted { $0.timestamp < $1.timestamp }
    }

    func hasRecordings(in dir: URL) -> Bool {
        ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [])
            .contains { Folders.audioExtensions.contains($0.pathExtension.lowercased()) }
    }

    // MARK: Operations

    func trash(_ items: [Recording]) {
        move(items, to: trashFolder)
        refresh()
    }

    func restore(_ items: [Recording]) {
        move(items, to: folder)
        refresh()
    }

    func delete(_ items: [Recording]) {
        for r in items { try? fm.removeItem(at: r.url) }
        refresh()
    }

    func emptyTrash() {
        delete(trashed)
    }

    var trashSize: Int64 { trashed.reduce(0) { $0 + $1.size } }

    /// RenameRecordingDialog: keeps the old extension.
    func rename(_ r: Recording, to newTitle: String) {
        let ext = r.url.pathExtension
        var base = newTitle
        if !ext.isEmpty && base.hasSuffix(".\(ext)") { base = String(base.dropLast(ext.count + 1)) }
        let name = ext.isEmpty ? base : "\(base).\(ext)"
        let dest = r.url.deletingLastPathComponent().appendingPathComponent(name)
        do {
            try fm.moveItem(at: r.url, to: dest)
        } catch {
            toast = error.localizedDescription
        }
        refresh()
    }

    /// moveRecordings(): every recording of one folder into another (MoveRecordingsDialog).
    func moveAll(from source: URL, to destination: URL) async {
        let all = await Self.read(source)
        move(all, to: destination)
    }

    private func move(_ items: [Recording], to dir: URL) {
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for r in items {
            do {
                try fm.moveItem(at: r.url, to: uniqueURL(dir.appendingPathComponent(r.title)))
            } catch {
                toast = error.localizedDescription
            }
        }
    }

    private func uniqueURL(_ url: URL) -> URL {
        guard fm.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
        var i = 1
        while true {
            let candidate = url.deletingLastPathComponent().appendingPathComponent("\(base)(\(i))").appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            i += 1
        }
    }

    /// deleteExpiredTrashedRecordings(): once a day, drop recycle bin items older than 30 days.
    func deleteExpiredTrashedRecordings() {
        let config = Config.shared
        let now = Date().timeIntervalSince1970
        guard config.useRecycleBin, config.lastRecycleBinCheck < now - daySeconds else { return }
        config.lastRecycleBinCheck = now
        let trash = trashFolder
        Task {
            let expired = await Self.read(trash).filter { $0.timestamp.timeIntervalSince1970 < now - monthSeconds }
            if !expired.isEmpty { delete(expired) }
        }
    }
}
