import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var bridge = ScreenshotBridge.shared

    var body: some View {
        VStack(spacing: 0) {
            TitleBar()

            ZStack {
                switch state.selectedTab {
                case .agent:    AgentTabView()
                case .generate: GenerateTabView()
                case .editor:   EditorTabView()
                case .dj:       DJTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            switch state.selectedTab {
            case .editor, .dj:
                TransportBar()
            case .agent, .generate:
                AgentStatusBar()
            }
        }
        .frame(minWidth: 1280, minHeight: 800)
        .background(Color.bgBase)
        .preferredColorScheme(.dark)
        .onChange(of: bridge.requestedTab) { newVal in
            guard let v = newVal else { return }
            switch v {
            case "agent":    state.selectedTab = .agent
            case "generate": state.selectedTab = .generate
            case "editor":   state.selectedTab = .editor
            case "dj":       state.selectedTab = .dj
            default: break
            }
        }
    }
}
