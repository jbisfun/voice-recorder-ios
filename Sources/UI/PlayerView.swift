import FossifyCommons
import SwiftUI

/// fragment_player.xml / PlayerFragment.
struct PlayerView: View {
    @Environment(RecordingsStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.palette) private var palette
    let query: String
    @Binding var selection: Set<String>

    var body: some View {
        let list = filtered
        VStack(spacing: 0) {
            ZStack {
                if store.loading && store.recordings.isEmpty {
                    ProgressView().tint(palette.primaryColor)
                } else if list.isEmpty {
                    Placeholder(text: query.isEmpty ? "No recordings created by this app\nhave been found" : "No items found.")
                } else {
                    RecordingsList(recordings: list, currentID: player.current?.id, selection: $selection) { r in
                        player.play(r, playOnPrepared: true)
                        if player.playedIDs.last != r.id { player.playedIDs.append(r.id) }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            controls(list)
        }
        .onChange(of: list.isEmpty) { _, empty in if empty { player.reset() } }
    }

    /// Search filter (onSearchTextChanged).
    var filtered: [Recording] {
        query.isEmpty ? store.recordings : store.recordings.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func controls(_ list: [Recording]) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(palette.divider).frame(height: 1)
            Text(player.current?.title ?? " ")
                .font(.system(size: 18))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
                .padding(16)
                .padding(.top, 8)
                .contentShape(Rectangle())
                .onLongPressGesture {
                    if let title = player.current?.title, !title.isEmpty { store.toast = Launcher.copy(title) }
                }
            HStack(spacing: 8) {
                Button { player.skip(forward: false) } label: {
                    Text(player.progress.formattedDuration()).monospacedDigit()
                }
                .buttonStyle(PressedStyle())
                Slider(value: Binding(get: { Double(min(player.progress, player.max)) },
                                      set: { v in if !player.playedIDs.isEmpty { player.seek(to: Int(v.rounded())) } }),
                       in: 0...Double(max(player.max, 1)))
                    .tint(palette.primaryColor)
                    .disabled(player.max == 0)
                Button { player.skip(forward: true) } label: {
                    Text(player.max.formattedDuration()).monospacedDigit()
                }
                .buttonStyle(PressedStyle())
            }
            .font(.system(size: 15))
            .foregroundStyle(palette.textColor)
            .padding(.horizontal, 12)
            HStack(spacing: 48) {
                Button { previous(list) } label: {
                    Image(systemName: "backward.end.fill").font(.system(size: 24)).frame(width: 48, height: 48)
                }
                .accessibilityLabel("Previous")
                Button {
                    if player.playedIDs.isEmpty || player.max == 0 { next(list) } else { player.togglePlayPause() }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(palette.onPrimary)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(palette.primaryColor))
                }
                .accessibilityLabel("Play/Pause")
                Button { next(list) } label: {
                    Image(systemName: "forward.end.fill").font(.system(size: 24)).frame(width: 48, height: 48)
                }
                .accessibilityLabel("Next")
            }
            .buttonStyle(PressedStyle())
            .foregroundStyle(palette.textColor)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    private func next(_ list: [Recording]) {
        guard !list.isEmpty else { return }
        let old = list.firstIndex { $0.id == player.current?.id } ?? -1
        let new = list[(old + 1) % list.count]
        player.play(new, playOnPrepared: true)
        player.playedIDs.append(new.id)
    }

    private func previous(_ list: [Recording]) {
        guard !player.playedIDs.isEmpty else { return }
        var wanted = player.playedIDs.removeLast()
        if wanted == player.current?.id && !player.playedIDs.isEmpty { wanted = player.playedIDs.removeLast() }
        guard let prev = list.first(where: { $0.id == wanted }) else { return }
        player.play(prev, playOnPrepared: true)
    }
}

/// fragment_trash.xml / TrashFragment.
struct TrashView: View {
    @Environment(RecordingsStore.self) private var store
    @Environment(\.palette) private var palette
    let query: String
    @Binding var selection: Set<String>

    var body: some View {
        let list = query.isEmpty ? store.trashed : store.trashed.filter { $0.title.localizedCaseInsensitiveContains(query) }
        ZStack {
            if store.loadingTrash && store.trashed.isEmpty {
                ProgressView().tint(palette.primaryColor)
            } else if list.isEmpty {
                Placeholder(text: query.isEmpty ? "The recycle bin is empty" : "No items found.")
            } else {
                RecordingsList(recordings: list, selection: $selection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
