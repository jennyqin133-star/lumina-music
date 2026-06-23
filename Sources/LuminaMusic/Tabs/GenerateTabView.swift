import SwiftUI
import AppKit

// MARK: - §3.2 Generate Tab — text-to-song using Music 2.6
//
// Whole tab is a single panel: prompt on the left, version history on the
// right. No modal — the previous GenerationPanel window is now this tab.
//
// Suno-inspired layout decisions:
//   - Left pane is the "create" surface (lyrics + style + language + sliders)
//   - Right pane is the version list (each generation drops a card here)
//   - Bottom-right: large "Generate" CTA
//   - The result cards have play/extend/save-to-editor buttons inline
//     so the user doesn't have to switch tabs to audition.
struct GenerateTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            GenerateLeftPane()
                .frame(width: 460)
            Divider().overlay(Color.borderSubtle)
            GenerateRightPane()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }
}

// MARK: Left — prompt + params + submit

private struct GenerateLeftPane: View {
    @EnvironmentObject var state: AppState

    @State private var lyrics: String = ""
    @State private var style: String = "Pop, female lead, polished"
    @State private var language: GenerationSpec.Language = .chinese
    @State private var bpm: Double = 120
    @State private var durationSec: Double = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create with Music 2.6")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("Pick the language up front — Music 2.6 won't undo a choice once it starts.")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Lyrics Language")
                Picker("", selection: $language) {
                    ForEach(GenerationSpec.Language.allCases, id: \.self) { l in
                        Text(l.display).tag(l)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Lyrics — leave blank to let Lumina write them")
                ScrollView {
                    TextEditor(text: $lyrics)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120, idealHeight: 160, maxHeight: 220)
                        .font(.system(size: 13))
                        .foregroundColor(.textPrimary)
                }
                .frame(minHeight: 120, idealHeight: 160, maxHeight: 220)
                .background(Color.bgInset)
                .overlay(RoundedRectangle(cornerRadius: Radius.input).stroke(Color.borderSubtle, lineWidth: 0.5))
                .cornerRadius(Radius.input)
            }

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

            HStack(spacing: 16) {
                slider("BPM \(Int(bpm))", value: $bpm, range: 60...180)
                slider("Duration \(Int(durationSec))s", value: $durationSec, range: 30...240)
            }

            Spacer(minLength: 4)

            Button {
                let spec = GenerationSpec(
                    lyrics: lyrics.isEmpty ? "请帮我写一首关于本主题的歌词。" : lyrics,
                    style: style,
                    language: language,
                    bpm: Int(bpm),
                    durationSec: Int(durationSec)
                )
                state.generateMusic(spec: spec)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: state.isGenerating ? "hourglass" : "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text(state.isGenerating ? "Generating…" : "Generate")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(state.modelConnected && !state.isGenerating
                              ? Color.accentPrimary
                              : Color.textQuat)
                )
            }
            .buttonStyle(.plain)
            .disabled(!state.modelConnected || state.isGenerating)

            if !state.modelConnected {
                Text("Model offline — open Preferences (⌘,) and paste your JWT.")
                    .font(.system(size: 11))
                    .foregroundColor(.stateDanger)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.bgElevated)
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(label)
            Slider(value: value, in: range, step: 1).tint(.accentPrimary)
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

// MARK: Right — generation history

private struct GenerateRightPane: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Generations")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(state.lastGeneratedURL == nil ? "—" : "1 ready")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 16).frame(height: 40)
            .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .bottom)

            ScrollView {
                VStack(spacing: 10) {
                    if let url = state.lastGeneratedURL {
                        GeneratedCard(url: url)
                    } else {
                        emptyState
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.textQuat)
            Text("No generations yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textTertiary)
            Text("Fill in the form on the left and hit Generate.")
                .font(.system(size: 11))
                .foregroundColor(.textQuat)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}

private struct GeneratedCard: View {
    let url: URL
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.bgInset)
                Image(systemName: "music.note")
                    .foregroundColor(.accentPrimary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentPrimary))
            }
            .buttonStyle(.plain)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.bgInset))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.bgElevated)
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(Color.borderSubtle, lineWidth: 0.5))
        .cornerRadius(Radius.card)
    }
}
