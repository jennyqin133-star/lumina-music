import SwiftUI
import AppKit
import Sparkle
import UniformTypeIdentifiers

@main
struct LuminaMusicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updaterController = AppUpdater.shared
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 1280, minHeight: 800)
                .onAppear {
                    if let win = NSApp.windows.first {
                        win.title = "Lumina Music"
                        win.titlebarAppearsTransparent = true
                        win.titleVisibility = .hidden
                        win.styleMask.insert(.fullSizeContentView)
                        win.setContentSize(NSSize(width: 1440, height: 900))
                        win.center()
                    }
                    state.bootstrap()
                    AppDelegate.maybeScreenshotAndExit()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Sparkle "Check for Updates..."
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates()
                }
                .disabled(!updaterController.canCheck)
            }
            // Preferences (⌘,) — opens our PreferencesWindowController.
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") {
                    PreferencesWindowController.shared.show(state: state)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            // File → New / Open / Generate
            CommandGroup(replacing: .newItem) {
                Button("New Conversation") {
                    state.newConversation()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Open Audio File…") {
                    openAudioFile()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Divider()

                Button("Generate Music with Music 2.6…") {
                    GenerationPanelController.shared.show(state: state)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(!state.modelConnected)
            }
        }
    }

    /// Show NSOpenPanel for an audio file and feed it to AppState.
    private func openAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .mp3, .wav, .audio, .mpeg4Audio, .aiff
        ]
        panel.prompt = "Open Audio"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.openAudioFile(at: url)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// If launched with `--screenshot <path>` then render the main window after 800ms and exit.
    static func maybeScreenshotAndExit() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--screenshot"), i + 1 < args.count else { return }
        let path = args[i + 1]
        let tab = args.contains("--tab") ? args[args.firstIndex(of: "--tab")! + 1] : "agent"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Switch tab via notification (simple: just trigger via shared state)
            ScreenshotBridge.shared.requestedTab = tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard let win = NSApp.windows.first(where: { $0.contentView != nil }) else {
                    print("no window"); exit(1)
                }
                guard let view = win.contentView else { exit(1) }
                let bounds = view.bounds
                guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
                    print("no rep"); exit(1)
                }
                view.cacheDisplay(in: bounds, to: rep)
                guard let data = rep.representation(using: .png, properties: [:]) else {
                    print("no data"); exit(1)
                }
                try? data.write(to: URL(fileURLWithPath: path))
                print("saved \(rep.pixelsWide)x\(rep.pixelsHigh) -> \(path)")
                exit(0)
            }
        }
    }
}

/// Bridge for screenshot-mode tab selection.
final class ScreenshotBridge: ObservableObject {
    static let shared = ScreenshotBridge()
    @Published var requestedTab: String? = nil
}
