import FossifyCommons
import SwiftUI

/// Port of the Android home-screen widget (MyWidgetRecordDisplayProvider +
/// WidgetRecordDisplayConfigureActivity), drawn by launcher-ios on its home grid.
///
/// A 1x1 microphone button: white while idle, tinted with the widget color while a
/// recording is running (TOGGLE_WIDGET_UI), always at the widget color's alpha.
/// Tapping it starts recording in the background, or stops and saves a running
/// recording (BackgroundRecordActivity), without opening the app.
public enum VoiceRecorderWidgets {
    public static let all: [HomeWidgetKind] = [
        HomeWidgetKind(
            id: "voicerecorder.record",
            title: "Record",
            defaultSize: CGSize(width: 1, height: 1), // minWidth/minHeight 40dp, no resizeMode
            resizable: false,
            configure: { context, done in AnyView(RecordWidgetConfigureView(context: context, done: done)) },
            content: { context in AnyView(RecordWidgetView(context: context)) }
        ),
    ]
}

/// R.color.default_widget_bg_color.
let defaultWidgetBgColor: UInt32 = 0xFFF57C00

/// config.widgetBgColor, kept per placed widget.
private func widgetBgColor(_ context: HomeWidgetContext) -> UInt32 {
    (UserDefaults.standard.object(forKey: context.key("bg_color")) as? Int).map { UInt32(truncatingIfNeeded: $0) } ?? defaultWidgetBgColor
}

struct RecordWidgetView: View {
    let context: HomeWidgetContext
    @AppStorage private var storedColor: Int

    init(context: HomeWidgetContext) {
        self.context = context
        _storedColor = AppStorage(wrappedValue: Int(defaultWidgetBgColor), context.key("bg_color"))
    }

    var body: some View {
        let recorder = RecorderService.shared
        let bg = UInt32(truncatingIfNeeded: storedColor)
        let alpha = Double((bg >> 24) & 0xFF) / 255
        // changeWidgetIcon(): widget color while recording, white otherwise; alpha of the widget color.
        let tint = recorder.isRunning ? Color(argb: bg | 0xFF000000) : .white
        Button {
            // BackgroundRecordActivity: stopService (which saves) or startService.
            if recorder.isRunning { recorder.save() } else { recorder.start() }
        } label: {
            MicrophoneShape()
                .fill(tint.opacity(alpha))
                .aspectRatio(1, contentMode: .fit)
                .padding(5) // layout_margin 5dp
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.isRunning ? "Stop recording" : "Start recording")
    }
}

/// WidgetRecordDisplayConfigureActivity: preview, color swatch, alpha seekbar and OK.
struct RecordWidgetConfigureView: View {
    let context: HomeWidgetContext
    let done: (Bool) -> Void
    @State private var colorWithoutTransparency: UInt32
    @State private var alpha: Double
    @State private var pickingColor = false

    init(context: HomeWidgetContext, done: @escaping (Bool) -> Void) {
        self.context = context
        self.done = done
        let color = widgetBgColor(context)
        _colorWithoutTransparency = State(initialValue: color | 0xFF000000)
        _alpha = State(initialValue: Double((color >> 24) & 0xFF) / 255)
    }

    private var widgetColor: UInt32 {
        let a = UInt32((alpha * 255).rounded()) & 0xFF
        return a << 24 | (colorWithoutTransparency & 0xFFFFFF)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            MicrophoneShape()
                .fill(Color(argb: widgetColor))
                .frame(width: 72, height: 72) // main_button_size
            Spacer()
            ConfigBar(color: widgetColor, alpha: $alpha) { pickingColor = true }
            HStack {
                Spacer()
                ConfigSaveButton {
                    UserDefaults.standard.set(Int(widgetColor), forKey: context.key("bg_color"))
                    done(true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fossifyTheme()
        .paletteBackground()
        .sheet(isPresented: $pickingColor) {
            ColorPickerDialog(color: colorWithoutTransparency) { colorWithoutTransparency = $0 }
        }
    }
}

private struct ConfigBar: View {
    @Environment(\.palette) private var palette
    let color: UInt32
    @Binding var alpha: Double
    let pickColor: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: pickColor) {
                Circle()
                    .fill(Color(argb: color))
                    .overlay(Circle().stroke(Color(argb: color | 0xFF000000), lineWidth: 2))
                    .frame(width: 50, height: 50) // widget_colorpicker_size
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Background color")
            Slider(value: $alpha, in: 0...1)
                .tint(palette.primaryColor)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Capsule().fill(palette.surface)) // widget_config_seekbar_background
                .accessibilityLabel("Transparency")
        }
    }
}

private struct ConfigSaveButton: View {
    @Environment(\.palette) private var palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("OK")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.onPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(palette.primaryColor))
        }
        .buttonStyle(.plain)
    }
}

/// commons ic_microphone_vector (24x24 viewport).
struct MicrophoneShape: Shape {
    private static let data = "M12 14.02c1.691 0 3.046-1.365 3.046-3.057l0.01-6.113c0-1.69-1.365-3.056-3.056-3.056S8.943 3.159 8.943 4.85v6.113c0 1.691 1.366 3.057 3.057 3.057zm5.4-3.057c0 3.057-2.588 5.196-5.4 5.196-2.812 0-5.406-2.007-5.406-5.064 0 0 0-1.037-0.844-1.033-0.843 0.005-0.882 0.901-0.882 0.901 0 3.474 2.771 6.347 6.113 6.847v3.273s-0.107 1.11 1.025 1.123c1.11 0.013 1.013-1.124 1.013-1.124V17.81c3.341-0.49 6.113-3.362 6.113-6.847 0 0 0.004-0.906-0.835-0.893-0.856 0.014-0.897 0.893-0.897 0.893z"
    private static let path = VectorPath.parse(data)

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let t = CGAffineTransform(translationX: rect.midX - 12 * s, y: rect.midY - 12 * s).scaledBy(x: s, y: s)
        return Self.path.applying(t)
    }
}

/// Minimal Android pathData parser (M L H V C S Z, absolute and relative).
enum VectorPath {
    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var num = ""
        func flush() { if !num.isEmpty { tokens.append(num); num = "" } }
        for ch in d {
            if ch.isLetter && ch != "e" {
                flush(); tokens.append(String(ch))
            } else if ch == "-" && !num.isEmpty && !num.hasSuffix("e") {
                flush(); num = "-"
            } else if ch == "." && num.contains(".") {
                flush(); num = "."
            } else if ch == " " || ch == "," {
                flush()
            } else {
                num.append(ch)
            }
        }
        flush()

        var p = Path()
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint?
        func n() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            let o = rel ? cur : .zero
            switch cmd.uppercased() {
            case "M":
                cur = CGPoint(x: o.x + n(), y: o.y + n()); start = cur; p.move(to: cur); lastCtrl = nil
                cmd = rel ? "l" : "L"
            case "L":
                cur = CGPoint(x: o.x + n(), y: o.y + n()); p.addLine(to: cur); lastCtrl = nil
            case "H":
                cur.x = (rel ? cur.x : 0) + n(); p.addLine(to: cur); lastCtrl = nil
            case "V":
                cur.y = (rel ? cur.y : 0) + n(); p.addLine(to: cur); lastCtrl = nil
            case "C":
                let c1 = CGPoint(x: o.x + n(), y: o.y + n()), c2 = CGPoint(x: o.x + n(), y: o.y + n())
                cur = CGPoint(x: o.x + n(), y: o.y + n())
                p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: o.x + n(), y: o.y + n())
                cur = CGPoint(x: o.x + n(), y: o.y + n())
                p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "Z":
                p.closeSubpath(); cur = start; lastCtrl = nil
                continue
            default:
                i += 1
            }
        }
        return p
    }
}
