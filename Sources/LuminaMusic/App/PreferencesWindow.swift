import SwiftUI
import AppKit

// MARK: - Preferences window
//
// Opened via `Lumina Music → Preferences…` (⌘,). Lets the user paste an
// MiniMax JWT API key + Group ID, then writes them to the macOS Keychain
// via Config.save. On close it asks AppState to re-ping the API.
struct PreferencesView: View {
    @EnvironmentObject var state: AppState

    @State private var apiKeyInput: String = ""
    @State private var groupIdInput: String = ""
    @State private var showSavedFlash: Bool = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ─── Header ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("MiniMax API")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("JWT (JSON Web Token) credential from platform.minimaxi.com → API Keys. The string starts with eyJhbGci… and is several hundred characters long.")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // ─── API key ─────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("JWT API Key")
                SecureField("eyJhbGciOiJSUzI1NiIs…", text: $apiKeyInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.bgInset)
                    .overlay(RoundedRectangle(cornerRadius: Radius.input).stroke(Color.borderSubtle, lineWidth: 0.5))
                    .cornerRadius(Radius.input)
            }

            // ─── Group ID ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Group ID (optional but required for music generation)")
                TextField("1234567890123456789", text: $groupIdInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.bgInset)
                    .overlay(RoundedRectangle(cornerRadius: Radius.input).stroke(Color.borderSubtle, lineWidth: 0.5))
                    .cornerRadius(Radius.input)
            }

            // ─── Status pill ─────────────────────────────────────────
            HStack(spacing: 6) {
                Circle()
                    .fill(state.modelConnected ? Color.accentSecondary : Color.stateDanger)
                    .frame(width: 6, height: 6)
                Text(state.connectionMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                if state.isPinging {
                    ProgressView()
                        .controlSize(.mini)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.bgInset)
            .cornerRadius(Radius.button)

            if let err = saveError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.stateDanger)
                    .padding(.horizontal, 6).padding(.vertical, 4)
            }
            if showSavedFlash {
                Text("Saved to Keychain.")
                    .font(.system(size: 11))
                    .foregroundColor(.accentSecondary)
                    .padding(.horizontal, 6).padding(.vertical, 4)
            }

            Spacer(minLength: 8)

            // ─── Actions ─────────────────────────────────────────────
            HStack {
                Link("Get a JWT key →", destination: URL(string: "https://platform.minimaxi.com")!)
                    .font(.system(size: 11))
                    .foregroundColor(.accentSecondary)
                Spacer()
                Button("Test Connection") {
                    Task {
                        await state.refreshConnection()
                    }
                }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(state.isPinging)

                Button("Save") {
                    do {
                        try Config.save(
                            apiKey: apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines),
                            groupId: groupIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        saveError = nil
                        showSavedFlash = true
                        Task {
                            await state.refreshConnection()
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            await MainActor.run { showSavedFlash = false }
                        }
                    } catch {
                        saveError = "Keychain write failed: \(error.localizedDescription)"
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(Color.bgBase)
        .onAppear {
            // Pre-fill from current Config snapshot (Keychain / env / secrets.env).
            let cfg = Config.current()
            apiKeyInput = cfg.apiKey ?? ""
            groupIdInput = cfg.groupId ?? ""
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(.textTertiary)
    }
}

// MARK: - Window controller — singleton so ⌘, doesn't open multiple windows.

@MainActor
final class PreferencesWindowController: NSObject {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?

    func show(state: AppState) {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = PreferencesView().environmentObject(state)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Preferences"
        win.contentViewController = hosting
        win.titlebarAppearsTransparent = false
        win.isReleasedWhenClosed = false
        win.center()
        win.delegate = self
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        // Keep the window cached for the next ⌘,.
    }
}
