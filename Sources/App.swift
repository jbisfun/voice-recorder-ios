import FossifyCommons
import Observation
import SwiftUI
import UIKit

enum Route: Hashable {
    case settings
    case customizeColors
    case about
}

@MainActor
@Observable
final class Router {
    var path: [Route] = []

    func push(_ r: Route) { path.append(r) }
}

/// The whole app as one view: the standalone app's window content, and what
/// the launcher presents.
public struct VoiceRecorderRoot: View {
    @State private var router = Router()

    public init() {}

    public var body: some View {
        RootView()
            .environment(router)
            .environment(Config.shared)
            .environment(RecordingsStore.shared)
            .environment(RecorderService.shared)
            .environment(PlayerModel.shared)
            .environment(DateTimeFormat.shared)
            .fossifyTheme()
    }
}

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(RecordingsStore.self) private var store

    var body: some View {
        @Bindable var router = router
        @Bindable var store = store
        NavigationStack(path: $router.path) {
            MainView()
                .navigationDestination(for: Route.self) { route in
                    Group {
                        switch route {
                        case .settings: SettingsView()
                        case .customizeColors: CustomizeColorsView()
                        case .about: AboutView(app: .voiceRecorder)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .paletteBackground()
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .toast($store.toast)
    }
}
