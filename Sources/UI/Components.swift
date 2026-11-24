import FossifyCommons
import SwiftUI
import UIKit

/// item_recording.xml.
struct RecordingRow: View {
    @Environment(\.palette) private var palette
    @Environment(DateTimeFormat.self) private var dateTime
    let recording: Recording
    var isCurrent = false
    var selected = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title)
                    .font(.system(size: 17))
                    .lineLimit(2)
                    .foregroundStyle(isCurrent ? palette.primaryColor : palette.textColor)
                Text(dateTime.format(recording.timestamp))
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .opacity(0.6)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(recording.duration.formattedDuration()).font(.system(size: 14))
                Text(recording.size.formattedSize).font(.system(size: 14)).opacity(0.6)
            }
            .lineLimit(1)
        }
        .foregroundStyle(palette.textColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? palette.primaryColor.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
    }
}

/// A list of recordings with tap / long-press selection (MyRecyclerViewAdapter).
struct RecordingsList: View {
    let recordings: [Recording]
    var currentID: String?
    @Binding var selection: Set<String>
    var onClick: (Recording) -> Void = { _ in }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(recordings) { r in
                    RecordingRow(recording: r, isCurrent: r.id == currentID, selected: selection.contains(r.id))
                        .onTapGesture {
                            if selection.isEmpty { onClick(r) } else { toggle(r) }
                        }
                        .onLongPressGesture { toggle(r) }
                }
            }
        }
    }

    private func toggle(_ r: Recording) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if selection.contains(r.id) { selection.remove(r.id) } else { selection.insert(r.id) }
    }
}

/// Centered italic placeholder text (recordings_placeholder / trash_placeholder).
struct Placeholder: View {
    @Environment(\.palette) private var palette
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 18).italic())
            .lineSpacing(4)
            .foregroundStyle(palette.textColor)
            .opacity(0.8)
            .multilineTextAlignment(.center)
            .padding(16)
            .frame(maxWidth: .infinity)
    }
}

/// com.visualizer.amplitude.AudioRecordView: rounded 3 pt chunks, 1 pt apart, centered.
struct AmplitudeVisualizer: View {
    @Environment(\.palette) private var palette
    let amplitudes: [CGFloat]

    var body: some View {
        Canvas { ctx, size in
            let width: CGFloat = 3, space: CGFloat = 1, minH: CGFloat = 2
            let maxH = min(200, size.height - 16)
            let fit = Int(size.width / (width + space))
            let shown = amplitudes.suffix(fit)
            for (i, a) in shown.enumerated() {
                let h = max(minH, a * maxH)
                let x = CGFloat(i) * (width + space)
                let rect = CGRect(x: x, y: (size.height - h) / 2, width: width, height: h)
                ctx.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(palette.primaryColor))
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.primaryColor.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.divider, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
