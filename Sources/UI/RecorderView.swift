import FossifyCommons
import SwiftUI

/// fragment_recorder.xml / RecorderFragment.
struct RecorderView: View {
    @Environment(RecorderService.self) private var recorder
    @Environment(\.palette) private var palette
    @State private var confirmCancel = false

    var body: some View {
        VStack(spacing: 0) {
            AmplitudeVisualizer(amplitudes: recorder.amplitudes)
                .padding(16)
            Text(recorder.status == .stopped ? " " : recorder.duration.formattedDuration())
                .font(.system(size: 30))
                .monospacedDigit()
                .padding(.bottom, 24)
            HStack(spacing: 0) {
                sideButton("xmark", label: "Cancel") { confirmCancel = true }
                    .frame(maxWidth: .infinity)
                toggleButton
                sideButton("checkmark", label: "Save") { recorder.save() }
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 16)
        }
        .alert("Discard recording", isPresented: $confirmCancel) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) { recorder.cancel() }
        } message: {
            Text("Are you sure you want to discard the current recording? This cannot be undone.")
        }
    }

    private var toggleButton: some View {
        // Paused: blink the button every 500 ms (only its alpha, so it stays tappable).
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let blinkOff = recorder.status == .paused && Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            Button { recorder.toggle() } label: {
                Image(systemName: recorder.status == .stopped ? "mic.fill" : "pause.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(palette.onPrimary)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(palette.primaryColor))
                    .opacity(blinkOff ? 0 : 1)
                    .contentShape(Circle())
            }
            .buttonStyle(PressedStyle())
            .accessibilityLabel(recorder.status == .stopped ? "Record" : "Pause")
        }
        .frame(width: 64, height: 64)
    }

    @ViewBuilder
    private func sideButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        if recorder.status != .stopped {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(palette.textColor)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressedStyle())
            .accessibilityLabel(label)
        } else {
            Color.clear.frame(width: 56, height: 56)
        }
    }
}
