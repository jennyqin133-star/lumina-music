import SwiftUI

// MARK: - §9.1 Agent Tab — 3-pane: History | Chat | Analysis Inspector
struct AgentTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            SessionHistoryPane()
                .frame(width: 240)
            Divider().overlay(Color.borderSubtle)
            ChatPane()
            Divider().overlay(Color.borderSubtle)
            AnalysisInspectorPane()
                .frame(width: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }
}

// MARK: Left — Session History
private struct SessionHistoryPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                LabelText(text: "Sessions")
                Spacer()
                Text("12")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.textQuat)
            }
            .padding(.horizontal, 12).frame(height: 32)
            .overlay(
                Rectangle().fill(Color.borderSubtle).frame(height: 0.5),
                alignment: .bottom
            )

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                Text("Search sessions")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.bgInset)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.borderSubtle, lineWidth: 0.5))
            .cornerRadius(5)
            .padding(.horizontal, 10).padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Today")
                    sessionRow(title: "Lost Highway · Pop-Rock", sub: "128 BPM · Em · analyzing", active: true)
                    sessionRow(title: "Untitled draft", sub: "prompt only", state: .draft)

                    sectionHeader("Yesterday")
                    sessionRow(title: "Cyberpunk City BGM", sub: "Synthwave · 110 BPM", state: .done)
                    sessionRow(title: "Lo-fi study mix", sub: "Lo-fi Hip-Hop · 88 BPM", state: .done)
                    sessionRow(title: "Voice clone — Jenny", sub: "Speech 2.8 HD · 12 takes", state: .done)

                    sectionHeader("Earlier this week")
                    sessionRow(title: "Wedding background", sub: "Acoustic Folk · 90 BPM", state: .done)
                    sessionRow(title: "Workout intro", sub: "EDM · 140 BPM", state: .done)
                    sessionRow(title: "Anime OP cover", sub: "J-Pop · 138 BPM", state: .done)
                }
                .padding(.horizontal, 10).padding(.bottom, 12).padding(.top, 4)
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.bgElevated)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(.textTertiary)
            .padding(.top, 10).padding(.bottom, 4).padding(.horizontal, 4)
    }

    enum SessionState { case active, draft, done, idle }
    private func sessionRow(title: String, sub: String, state s: SessionState = .idle, active: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(dotColor(state: active ? .active : s)).frame(width: 6, height: 6)
                    Text(title)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }
                Text(sub)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .padding(.leading, 12)
            }
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(active ? Color.accentPrimary.opacity(0.12) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(active ? Color.accentPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(5)
    }

    private func dotColor(state: SessionState) -> Color {
        switch state {
        case .active: return .accentPrimary
        case .draft:  return .stateWarning
        case .done:   return .accentSecondary
        case .idle:   return .textQuat
        }
    }
}

// MARK: Middle — Chat Pane
private struct ChatPane: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(state.projectName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("·  Music Analysis & Generation")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Image(systemName: "square.and.arrow.up")
                    Image(systemName: "pin")
                }
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 16).frame(height: 40)
            .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .bottom)

            // Messages — driven by live conversation state
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(state.conversation.messages) { msg in
                            LiveMessageView(message: msg)
                                .id(msg.id)
                        }
                        // Trailing anchor so we can scroll-to-bottom on send.
                        Color.clear
                            .frame(height: 1)
                            .id("BOTTOM")
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                }
                .background(Color.bgBase)
                .onChange(of: state.conversation.messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }

            // Composer
            ComposerView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - LiveMessageView — single bubble driven by a Message value.
//
// Replaces the old hard-coded UserMessage / AgentToolTraceMessage /
// AgentAnalysisMessage / AgentStreamingMessage structs. The visual style
// (avatar, badge, typing indicator, file attachment card) is preserved, but
// now driven by the data model so the same bubble works whether tokens are
// arriving from the live SSE stream or from the demo seed.
private struct LiveMessageView: View {
    let message: Message

    var body: some View {
        MessageRow(
            avatar: avatar,
            avatarBg: isAssistant ? .accentPrimary : .bgElevated,
            avatarFg: isAssistant ? .white : .textSecondary,
            name: isAssistant ? "Lumina Agent" : "You",
            time: Self.timeFormatter.string(from: message.timestamp),
            tag: message.tag
        ) {
            if !message.text.isEmpty {
                Text(message.text)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let att = message.attachment {
                LiveFileAttachmentCard(att: att)
                    .padding(.top, 6)
            }
            if let stream = message.streaming {
                TypingIndicator(label: stream.label)
                    .padding(.top, 6)
            }
        }
    }

    private var isAssistant: Bool { message.role == .assistant }
    private var avatar: String { isAssistant ? "L" : "U" }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

private struct LiveFileAttachmentCard: View {
    let att: Message.AudioAttachment
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color.bgDeep)
                MiniWaveform()
            }
            .frame(width: 42, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(att.filename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                Text(meta)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color.bgElevated)
        .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(Color.borderSubtle, lineWidth: 0.5))
        .cornerRadius(Radius.button)
        .frame(maxWidth: 320, alignment: .leading)
    }

    private var meta: String {
        var parts: [String] = []
        if let d = att.durationSeconds {
            let m = Int(d) / 60
            let s = Int(d) % 60
            parts.append(String(format: "%d:%02d", m, s))
        }
        if let b = att.sizeBytes {
            parts.append(String(format: "%.1f MB", Double(b) / 1_048_576))
        }
        if let br = att.bitrate {
            parts.append("\(br) kbps")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: Chat — internal pieces (MiniWaveform used by LiveFileAttachmentCard)

private struct MiniWaveform: View {
    var body: some View {
        Canvas { ctx, size in
            let cols = 16
            let center = size.height / 2
            for i in 0..<cols {
                let x = CGFloat(i) / CGFloat(cols - 1) * (size.width - 2) + 1
                let seed = Double(i) * 13.7
                let h = (sin(seed) * 0.5 + 0.5) * size.height * 0.7 + 4
                let half = h / 2
                var path = Path()
                path.move(to: CGPoint(x: x, y: center - half))
                path.addLine(to: CGPoint(x: x, y: center + half))
                ctx.stroke(path, with: .color(.accentPrimary), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


private struct TypingIndicator: View {
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.accentPrimary).frame(width: 4, height: 4)
            Circle().fill(Color.accentPrimary.opacity(0.6)).frame(width: 4, height: 4)
            Circle().fill(Color.accentPrimary.opacity(0.3)).frame(width: 4, height: 4)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(.accentPrimary)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Color.bgInset)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderSubtle, lineWidth: 0.5))
        .cornerRadius(8)
    }
}

// MARK: Message row wrapper
private struct MessageRow<Content: View>: View {
    let avatar: String
    let avatarBg: Color
    let avatarFg: Color
    let name: String
    let time: String
    let tag: String?
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(avatarBg)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.borderStrong, lineWidth: 0.5))
                Text(avatar).font(.system(size: 10, weight: .heavy)).foregroundColor(avatarFg)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(name).font(.system(size: 10, weight: .semibold)).foregroundColor(.textSecondary).tracking(0.3)
                    Text(time).font(.system(size: 9.5, design: .monospaced)).foregroundColor(.textQuat)
                    if let tag {
                        Text(tag.uppercased())
                            .font(.system(size: 9, weight: .semibold)).tracking(0.4)
                            .foregroundColor(.accentPrimary)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.accentPrimary.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.accentPrimary.opacity(0.3), lineWidth: 0.5))
                            .cornerRadius(3)
                    }
                }
                content
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: Composer
private struct ComposerView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                slashChip("/analyze", on: true, "waveform.path")
                slashChip("/generate", "sparkles")
                slashChip("/cover", "arrow.2.squarepath")
                slashChip("/voice-clone", "person.wave.2")
                slashChip("/lyrics", "music.note.list")
                Spacer()
            }

            HStack(alignment: .top, spacing: 8) {
                ComposerInputField()
                HStack(spacing: 4) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 13)).foregroundColor(.textSecondary)
                        .frame(width: 28, height: 28)
                    Image(systemName: "mic")
                        .font(.system(size: 13)).foregroundColor(.textSecondary)
                        .frame(width: 28, height: 28)
                    Button {
                        state.sendCurrentInput()
                    } label: {
                        Image(systemName: state.isComposing ? "stop.fill" : "paperplane.fill")
                            .font(.system(size: 11)).foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(canSend ? Color.accentPrimary : Color.textQuat))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding(.trailing, 8).padding(.bottom, 4)
            }
            .background(Color.bgInset)
            .overlay(RoundedRectangle(cornerRadius: Radius.input).stroke(Color.borderSubtle, lineWidth: 0.5))
            .cornerRadius(Radius.input)

            HStack {
                HStack(spacing: 12) {
                    kbdHint("⏎", "Send")
                    kbdHint("⇧⏎", "New line")
                    kbdHint("⌘K", "Commands")
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(state.modelConnected ? Color.accentSecondary : Color.stateDanger).frame(width: 6, height: 6)
                    Text(state.modelConnected ? "Connected: \(state.apiBackend)" : state.connectionMessage)
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
        .background(Color.bgElevated)
        .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .top)
    }

    private var canSend: Bool {
        !state.composerInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !state.isComposing
    }

    private func slashChip(_ text: String, on: Bool = false, _ symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 10))
            Text(text).font(.system(size: 10.5, weight: .medium))
        }
        .foregroundColor(on ? .accentPrimary : .textSecondary)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(on ? Color.accentPrimary.opacity(0.1) : Color.bgInset))
        .overlay(Capsule().stroke(on ? Color.accentPrimary.opacity(0.35) : Color.borderSubtle, lineWidth: 0.5))
    }

    private func kbdHint(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.bgInset)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.borderSubtle, lineWidth: 0.5))
                .cornerRadius(3)
            Text(desc).font(.system(size: 10)).foregroundColor(.textTertiary)
        }
    }
}

/// Real text input bound to `AppState.composerInput`. Submits on Enter.
private struct ComposerInputField: View {
    @EnvironmentObject var state: AppState
    @FocusState private var focused: Bool

    var body: some View {
        TextField(
            "Ask Agent · 拖入音频文件 · 输入 / 快捷指令",
            text: $state.composerInput,
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .focused($focused)
        .lineLimit(1...6)
        .font(.system(size: 13))
        .foregroundColor(.textPrimary)
        .tint(.accentPrimary)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        .onSubmit {
            state.sendCurrentInput()
        }
        .onAppear { focused = true }
    }
}

// MARK: Right — Analysis Inspector
private struct AnalysisInspectorPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Source Analysis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("● Locked")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(.accentSecondary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Color.accentSecondary.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.accentSecondary.opacity(0.3), lineWidth: 0.5))
                    .cornerRadius(3)
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 14).frame(height: 40)
            .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    insSection("Technical") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                            StatBox(value: "128.0", key: "BPM")
                            StatBox(value: "E min", key: "Key")
                            StatBox(value: "4/4", key: "Meter")
                            StatBox(value: "−9.2 LUFS", key: "Loudness")
                        }
                    }

                    insSection("Energy Curve · 3:42") {
                        EnergyCurveCard()
                    }

                    insSection("Style Tags") {
                        FlowChips(items: [
                            ("Pop-Rock", .primary), ("Anthemic", .primary),
                            ("Hopeful", .neutral), ("Driving", .neutral), ("Mid-tempo", .neutral)
                        ])
                    }

                    insSection("Sections") {
                        VStack(spacing: 4) {
                            sectionRow("0:00", "Intro", "0:08")
                            sectionRow("0:08", "Verse 1", "0:24")
                            sectionRow("0:32", "Chorus ★", "0:30", highlight: .accentPrimary)
                            sectionRow("1:02", "Verse 2", "0:26")
                            sectionRow("1:28", "Chorus", "0:30")
                            sectionRow("1:58", "Bridge", "0:30", highlight: .stateWarning)
                            sectionRow("2:28", "Chorus", "0:32")
                            sectionRow("3:00", "Outro", "0:42")
                        }
                    }

                    insSection("Vocal Profile") {
                        FlowChips(items: [
                            ("Female", .secondary), ("Bright", .secondary),
                            ("Mezzo-soprano", .neutral), ("Belted chorus", .neutral), ("Vibrato medium", .neutral)
                        ])
                    }
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgElevated)
    }

    @ViewBuilder
    private func insSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabelText(text: label)
            content()
        }
    }

    private func sectionRow(_ ts: String, _ name: String, _ dur: String, highlight: Color? = nil) -> some View {
        HStack {
            Text(ts).font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(highlight ?? .accentPrimary)
                .frame(width: 36, alignment: .leading)
            Text(name).font(.system(size: 11, weight: highlight != nil ? .semibold : .regular))
                .foregroundColor(highlight ?? .textPrimary)
            Spacer()
            Text(dur).font(.system(size: 10, design: .monospaced)).foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(highlight?.opacity(0.08) ?? Color.bgInset)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke((highlight ?? Color.borderSubtle).opacity(highlight == nil ? 0.5 : 0.4), lineWidth: 0.5)
        )
        .cornerRadius(4)
    }
}

private struct EnergyCurveCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                // y points (normalized — match HTML mock)
                let pts: [CGPoint] = [
                    CGPoint(x: 0, y: 50),
                    CGPoint(x: 11, y: 48),
                    CGPoint(x: 22, y: 42),
                    CGPoint(x: 43, y: 22),
                    CGPoint(x: 82, y: 20),
                    CGPoint(x: 82, y: 32),
                    CGPoint(x: 114, y: 30),
                    CGPoint(x: 114, y: 20),
                    CGPoint(x: 155, y: 12),
                    CGPoint(x: 205, y: 10),
                    CGPoint(x: 205, y: 30),
                    CGPoint(x: 228, y: 8),
                    CGPoint(x: 268, y: 6),
                    CGPoint(x: 268, y: 38),
                    CGPoint(x: 300, y: 42)
                ]
                let sx = w / 300.0
                let sy = h / 60.0

                // Highlight bands (chorus / bridge)
                ctx.fill(Rectangle().path(in: CGRect(x: 43*sx, y: 0, width: 40*sx, height: h)), with: .color(Color.accentPrimary.opacity(0.08)))
                ctx.fill(Rectangle().path(in: CGRect(x: 119*sx, y: 0, width: 40*sx, height: h)), with: .color(Color.accentPrimary.opacity(0.08)))
                ctx.fill(Rectangle().path(in: CGRect(x: 200*sx, y: 0, width: 40*sx, height: h)), with: .color(Color.stateWarning.opacity(0.10)))

                // Filled curve
                var fill = Path()
                fill.move(to: CGPoint(x: 0, y: h))
                for p in pts { fill.addLine(to: CGPoint(x: p.x*sx, y: p.y*sy)) }
                fill.addLine(to: CGPoint(x: w, y: h))
                fill.closeSubpath()
                ctx.fill(fill, with: .linearGradient(
                    Gradient(colors: [Color.accentPrimary.opacity(0.6), Color.accentPrimary.opacity(0.05)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)
                ))
                // Stroke line
                var line = Path()
                line.move(to: CGPoint(x: pts[0].x*sx, y: pts[0].y*sy))
                for p in pts.dropFirst() { line.addLine(to: CGPoint(x: p.x*sx, y: p.y*sy)) }
                ctx.stroke(line, with: .color(.accentPrimary), lineWidth: 1.2)
            }
            .frame(height: 60)

            HStack {
                Text("0:00").font(.system(size: 9.5, design: .monospaced)).foregroundColor(.textTertiary)
                Spacer()
                Text("peak +6 dB @ 2:32").font(.system(size: 9.5, design: .monospaced)).foregroundColor(.textTertiary)
                Spacer()
                Text("3:42").font(.system(size: 9.5, design: .monospaced)).foregroundColor(.textTertiary)
            }
        }
        .padding(10)
        .background(Color.bgInset)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.borderSubtle, lineWidth: 0.5))
        .cornerRadius(4)
    }
}
