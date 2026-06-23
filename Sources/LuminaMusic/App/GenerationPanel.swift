import SwiftUI
import AppKit

// MARK: - Generation panel
//
// Opened via:
//   - Menu  : File → Generate Music with Music 2.6… (⌘⇧G)
//   - Agent : the language-selection prompt the agent emits when it can't
//             infer the language from the user's text (PRD §3.2.4 mandatory
//             interaction point)
//
// Collects the GenerationSpec (lyrics, style, language, BPM, duration) and
// hands it to AppState.generateMusic — which appends a streaming placeholder
// to the conversation and writes the result mp3 to ~/Library/Application
// Support/Lumina Music/generations/.

struct GenerationPanelView: View {
    @EnvironmentObject var state: AppState
    var onSubmit: () -> Void
    var onCancel: () -> Void

    @State private var lyrics: String = ""
    @State private var style: String = "Pop, female lead, polished"
    @State private var language: GenerationSpec.Language = .chinese
    @State private var bpm: Double = 120
    @State private var durationSec: Double = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generate with Music 2.6")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("Pick the language up front — Music 2.6 won't undo a choice once it starts.")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }

            // ─── Language picker (PRD §3.2.4 mandatory step) ──────────
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Lyrics Language")
                Picker("", selection: $language) {
                    ForEach(GenerationSpec.Language.allCases, id: \.self) { l in
                        Text(l.display).tag(l)
                    }
                }
                .pickerStyle(.segmented)
            }

            // ─── Lyrics box ───────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Lyrics — leave blank to let Lumina write them")
                ScrollView {
                    TextEditor(text: $lyrics)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80, idealHeight: 110, maxHeight: 140)
                        .font(.system(size: 13))
                        .foregroundColor(.textPrimary)
                }
                .frame(minHeight: 80, idealHeight: 110, maxHeight: 140)
                .background(Color.bgInset)
                .overlay(RoundedRectangle(cornerRadius: Radius.input).stroke(Color.borderSubtle, lineWidth: 0.5))
                .cornerRadius(Radius.input)
            }

            // ─── Style ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Style")
                TextField("Pop, female lead, polished", text: $style)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.bgInset)
                    .overlay(RoundedRectangle(cornerRadius: Radius.input).stroke(Color.borderSubtle, lineWidth: 0.5))
                    .cornerRadius(Radius.input)
            }

            // ─── BPM + duration sliders ───────────────────────────────
            HStack(spacing: 16) {
                slider("BPM \(Int(bpm))", value: $bpm, range: 60...180)
                slider("Duration \(Int(durationSec))s", value: $durationSec, range: 30...240)
            }

            Spacer(minLength: 4)

            HStack {
                Text(state.modelConnected
                     ? "Connected"
                     : "Model offline — submit will fail until JWT is set in Preferences.")
                    .font(.system(size: 11))
                    .foregroundColor(state.modelConnected ? .textTertiary : .stateDanger)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Generate") {
                    let spec = GenerationSpec(
                        lyrics: lyrics.isEmpty
                            ? "请帮我写一首关于本主题的歌词。" : lyrics,
                        style: style,
                        language: language,
                        bpm: Int(bpm),
                        durationSec: Int(durationSec)
                    )
                    state.generateMusic(spec: spec)
                    onSubmit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!state.modelConnected || state.isGenerating)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(Color.bgBase)
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(label)
            Slider(value: value, in: range, step: 1)
                .tint(.accentPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(.textTertiary)
    }
}

// MARK: - Window controller

@MainActor
final class GenerationPanelController: NSObject {
    static let shared = GenerationPanelController()
    private var window: NSWindow?

    func show(state: AppState) {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = GenerationPanelView(
            onSubmit: { [weak self] in self?.window?.close() },
            onCancel: { [weak self] in self?.window?.close() }
        )
        .environmentObject(state)

        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Generate Music"
        win.contentViewController = hosting
        win.isReleasedWhenClosed = false
        win.center()
        win.delegate = self
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension GenerationPanelController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        // Keep the window cached.
    }
}
