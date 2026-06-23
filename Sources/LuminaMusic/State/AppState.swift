import SwiftUI
import Combine

// MARK: - App-wide state
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .agent
    @Published var projectName: String = "Lost Highway"
    @Published var bpm: Double = 128.0
    @Published var key: String = "Em"
    @Published var duration: String = "3:42"
    @Published var modified: Bool = true
    @Published var modelConnected: Bool = false   // Will flip to true once a real JWT key is supplied
    @Published var apiBackend: String = "M3 · Music 2.6 · Speech 2.8 HD · Seedream 4.0"
}
