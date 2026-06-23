import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var bridge = ScreenshotBridge.shared

    var body: some View {
        VStack(spacing: 0) {
            TitleBar()

            ZStack {
                switch state.selectedTab {
                case .agent:   AgentTabView()
                case .editor:  EditorTabView()
                case .dj:      DJTabView()
                case .artwork: ArtworkTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TransportBar()
        }
        .frame(minWidth: 1280, minHeight: 800)
        .background(Color.bgBase)
        .preferredColorScheme(.dark)
        .onChange(of: bridge.requestedTab) { newVal in
            guard let v = newVal else { return }
            switch v {
            case "agent":   state.selectedTab = .agent
            case "editor":  state.selectedTab = .editor
            case "dj":      state.selectedTab = .dj
            case "artwork": state.selectedTab = .artwork
            default: break
            }
        }
    }
}
