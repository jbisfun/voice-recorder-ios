import AVFoundation
import FossifyCommons
import SwiftUI

/// MainActivity: search menu, Recorder / Player / Recycle bin pages and bottom tabs.
struct MainView: View {
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(RecordingsStore.self) private var store
    @Environment(RecorderService.self) private var recorder
    @Environment(PlayerModel.self) private var player
    @Environment(\.palette) private var palette

    @State private var tab = 0
    @State private var launched = false
    @State private var query = ""
    @State private var searching = false
    @FocusState private var searchFocused: Bool
    @State private var selection = Set<String>()

    @State private var share: ShareItems?
    @State private var rename: Recording?
    @State private var deleteDialog = false
    @State private var confirmTrashDelete = false

    private var tabs: [Int] { config.useRecycleBin ? [0, 1, 2] : [0, 1] }

    var body: some View {
        VStack(spacing: 0) {
            if selection.isEmpty { searchBar } else { selectionBar }
            TabView(selection: $tab) {
                RecorderView().tag(0)
                PlayerView(query: query, selection: $selection).tag(1)
                if config.useRecycleBin {
                    TrashView(query: query, selection: $selection).tag(2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            bottomTabs
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear(perform: onLaunch)
        .onChange(of: tab) { _, t in
            config.lastUsedViewPagerPage = t
            selection.removeAll()
            if t == 0 { closeSearch() }
        }
        .onChange(of: config.useRecycleBin) { _, on in if !on && tab == 2 { tab = 1 } }
        .sheet(item: $share) { ShareSheet(items: $0.urls) }
        .sheet(item: $rename) { r in
            RenameRecordingDialog(recording: r) { selection.removeAll() }
        }
        .sheet(isPresented: $deleteDialog) {
            DeleteConfirmationDialog(message: deleteQuestion, showSkipRecycleBinOption: config.useRecycleBin) { skip in
                deleteSelected(toRecycleBin: !skip && config.useRecycleBin)
            }
        }
        .alert(String(format: "Delete %@?", itemsText(store.trashed)), isPresented: $confirmTrashDelete) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) {
                store.delete(store.trashed.filter { selection.contains($0.id) })
                selection.removeAll()
            }
        }
    }

    private func onLaunch() {
        guard !launched else { return }
        launched = true
        tab = tabs.contains(config.lastUsedViewPagerPage) ? config.lastUsedViewPagerPage : 0
        store.deleteExpiredTrashedRecordings()
        store.refresh()
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                if !granted { RecordingsStore.shared.toast = "Audio permission is required" }
            }
        }
        if config.recordAfterLaunch && !recorder.isRunning { recorder.start() }
    }

    // MARK: Search menu (MySearchMenu)

    private var searchBar: some View {
        HStack(spacing: 0) {
            if !searching { CloseAppButton() }
            Button {
                if searching { closeSearch() } else { openSearch() }
            } label: {
                Image(systemName: searching ? "arrow.left" : "magnifyingglass")
                    .font(.system(size: 18))
                    .frame(width: 48, height: 48)
            }
            TextField("", text: $query, prompt: Text("Search").foregroundStyle(palette.secondaryText))
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onChange(of: searchFocused) { _, f in if f { openSearch() } }
            if !query.isEmpty {
                IconButton(icon: "xmark") { query = "" }
            }
            Menu {
                Button { router.push(.settings) } label: { Label("Settings", systemImage: "gearshape") }
                Button { router.push(.about) } label: { Label("About", systemImage: "info.circle") }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 18))
                    .frame(width: 48, height: 48)
            }
        }
        .foregroundStyle(palette.textColor)
        .background(Capsule().fill(palette.surface))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// onSearchOpenListener: searching from the recorder jumps to the player.
    private func openSearch() {
        searching = true
        searchFocused = true
        if tab == 0 { withAnimation { tab = 1 } }
    }

    private func closeSearch() {
        query = ""
        searching = false
        searchFocused = false
    }

    // MARK: Action mode (cab_recordings.xml / cab_trash.xml)

    private var selectionBar: some View {
        HStack(spacing: 0) {
            IconButton(icon: "xmark") { selection.removeAll() }
            Text("\(selection.count)").font(.system(size: 20, weight: .medium)).padding(.leading, 8)
            Spacer()
            if tab == 2 {
                IconButton(icon: "trash") { confirmTrashDelete = true }
                Menu {
                    Button { restoreSelected() } label: { Label("Restore selected files", systemImage: "arrow.uturn.backward") }
                    Button { selectAll(store.trashed) } label: { Label("Select all", systemImage: "checklist") }
                } label: { overflowIcon }
            } else {
                if selection.count == 1 {
                    IconButton(icon: "pencil") { rename = selected(store.recordings).first }
                }
                IconButton(icon: "square.and.arrow.up") { share = ShareItems(selected(store.recordings).map(\.url)) }
                IconButton(icon: "trash") { deleteDialog = true }
                Menu {
                    if selection.count == 1 {
                        Button {
                            if let r = selected(store.recordings).first, !Launcher.openWith(r.url) { store.toast = "No valid app found" }
                        } label: {
                            Label("Open with", systemImage: "arrow.up.forward.app")
                        }
                    }
                    Button { selectAll(store.recordings) } label: { Label("Select all", systemImage: "checklist") }
                } label: { overflowIcon }
            }
        }
        .foregroundStyle(palette.onPrimary)
        .padding(.horizontal, 4)
        .frame(height: 64)
        .background(palette.primaryColor.ignoresSafeArea(edges: .top))
    }

    private var overflowIcon: some View {
        Image(systemName: "ellipsis").rotationEffect(.degrees(90)).font(.system(size: 18)).frame(width: 44, height: 48)
    }

    private func selected(_ list: [Recording]) -> [Recording] { list.filter { selection.contains($0.id) } }

    private func selectAll(_ list: [Recording]) {
        let q = query
        selection = Set(list.filter { q.isEmpty || $0.title.localizedCaseInsensitiveContains(q) }.map(\.id))
    }

    /// "\"title\"" for one item, "N recordings" for more (R.plurals.delete_recordings).
    private func itemsText(_ list: [Recording]) -> String {
        let items = selected(list)
        if items.count == 1 { return "\"\(items[0].title)\"" }
        return "\(items.count) recording\(items.count == 1 ? "" : "s")"
    }

    private var deleteQuestion: String {
        let items = itemsText(store.recordings)
        return config.useRecycleBin
            ? "Are you sure you want to move \(items) into the recycle bin?"
            : "Delete \(items)?"
    }

    /// RecordingsAdapter.deleteRecordings() / trashRecordings() and doDeleteAnimation().
    private func deleteSelected(toRecycleBin: Bool) {
        let q = query
        let list = q.isEmpty ? store.recordings : store.recordings.filter { $0.title.localizedCaseInsensitiveContains(q) }
        let removed = selected(store.recordings)
        let removedIDs = Set(removed.map(\.id))
        let oldIndex = list.firstIndex { $0.id == player.current?.id }
        if toRecycleBin { store.trash(removed) } else { store.delete(removed) }
        selection.removeAll()
        if let current = player.current, removedIDs.contains(current.id) {
            let remaining = list.filter { !removedIDs.contains($0.id) }
            if remaining.isEmpty {
                player.reset()
            } else {
                player.play(remaining[min(oldIndex ?? 0, remaining.count - 1)], playOnPrepared: false)
            }
        }
    }

    private func restoreSelected() {
        store.restore(selected(store.trashed))
        selection.removeAll()
    }

    // MARK: Tabs

    private var bottomTabs: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { t in
                Button {
                    withAnimation { tab = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon(t)).font(.system(size: 20))
                        Text(title(t)).font(.system(size: 13, weight: t == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(t == tab ? palette.primaryColor : palette.textColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(palette.surface.ignoresSafeArea(edges: .bottom))
    }

    private func icon(_ t: Int) -> String {
        switch t {
        case 0: return "mic.fill"
        case 1: return "music.note.list"
        default: return "trash"
        }
    }

    private func title(_ t: Int) -> String {
        switch t {
        case 0: return "Recorder"
        case 1: return "Player"
        default: return "Recycle bin"
        }
    }
}
