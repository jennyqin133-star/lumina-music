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

            // Messages
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    UserMessage()
                    AgentToolTraceMessage()
                    AgentAnalysisMessage()
                    UserFollowUpMessage()
                    AgentStreamingMessage()
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .background(Color.bgBase)

            // Composer
            ComposerView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Chat — individual message blocks
private struct UserMessage: View {
    var body: some View {
        MessageRow(avatar: "JQ", avatarBg: .bgElevated, avatarFg: .textSecondary, name: "Jenny", time: "08:01", tag: nil) {
            Text("帮我分析这首歌的结构和风格。我特别喜欢副歌那段的音色，想用类似的感觉生成一首新歌。")
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            FileAttachmentCard()
                .padding(.top, 6)
        }
    }
}

private struct FileAttachmentCard: View {
    var body: some View {
        HStack(spacing: 10) {
            // mini waveform tile
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color.bgDeep)
                MiniWaveform()
            }
            .frame(width: 42, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("lost-highway-reference.mp3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                Text("3:42 · 5.6 MB · 320 kbps")
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
}

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

private struct AgentToolTraceMessage: View {
    var body: some View {
        MessageRow(avatar: "L", avatarBg: .accentPrimary, avatarFg: .white, name: "Lumina Agent", time: "08:01", tag: "M3 · analysis") {
            Text("收到。先帮你跑完整套分析——结构 / BPM / Key / 风格 / 音色 / 能量曲线，一会儿就好。")
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Tool trace card
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Text("tool · audio.analyze")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.4)
                            .foregroundColor(.accentSecondary)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.accentSecondary.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.accentSecondary.opacity(0.3), lineWidth: 0.5))
                            .cornerRadius(3)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.accentSecondary)
                        Text("Structural · Spectral · Vocal")
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Text("2.4s · 17.3K tokens · ¥0.062")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textTertiary)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.bgInset)
                .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .bottom)

                HStack(spacing: 6) {
                    StatBox(value: "128.0", key: "BPM")
                    StatBox(value: "E min", key: "Key")
                    StatBox(value: "Pop-Rock", key: "Style")
                    StatBox(value: "3:42", key: "Length")
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                HStack {
                    Text("Identified 8 sections · 4 distinct timbral zones · 1 lead vocalist (female, bright).")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
            }
            .background(Color.bgElevated)
            .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(Color.borderSubtle, lineWidth: 0.5))
            .cornerRadius(Radius.button)
            .padding(.top, 6)
        }
    }
}

private struct AgentAnalysisMessage: View {
    var body: some View {
        MessageRow(avatar: "L", avatarBg: .accentPrimary, avatarFg: .white, name: "Lumina Agent", time: "08:01", tag: nil) {
            firstParagraph
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            SectionMapBar()
                .padding(.top, 8)

            secondParagraph
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            ActionRow()
                .padding(.top, 10)
        }
    }

    private var firstParagraph: Text {
        let head = Text("这首是 ") + Text("标准 Pop-Rock").foregroundColor(.accentPrimary).bold()
        let mid  = Text("，") + Text("128 BPM").foregroundColor(.accentPrimary).bold()
        let key  = Text("、") + Text("E 小调").foregroundColor(.accentPrimary).bold()
        let tail = Text("，3:42 全长。结构很经典：前奏 → 主歌 A → 副歌 → 主歌 B → 副歌 → 桥段 → 副歌 → 尾奏。点时间码可以直接跳转试听：")
        return head + mid + key + tail
    }

    private var secondParagraph: Text {
        let s1 = Text("你说\"喜欢副歌的音色\"——我帮你定位了：第一段副歌在 ") + Text("0:32–1:02").foregroundColor(.accentPrimary).font(.system(size: 13, weight: .bold, design: .monospaced))
        let s2 = Text("。这段的音色我也拆出来了：") + Text("女声，偏亮的抒情嗓 + 合成器铺底 + 紧凑鼓点 + 副贝斯").foregroundColor(.accentSecondary).bold()
        let s3 = Text("，能量比主歌高 +6 dB。\n\n你想用这个副歌的音色感觉去 ") + Text("生成新歌").foregroundColor(.accentPrimary).bold()
        let s4 = Text("，还是 ") + Text("在这首歌基础上做 Remix").foregroundColor(.accentPrimary).bold() + Text("？")
        return s1 + s2 + s3 + s4
    }
}

private struct SectionMapBar: View {
    let segs: [(name: String, frac: CGFloat, color: Color)] = [
        ("In",     0.036, .textQuat),
        ("V1",     0.108, .borderStrong),
        ("Chorus", 0.135, .accentPrimary),
        ("V2",     0.117, .borderStrong),
        ("Chorus", 0.135, .accentPrimary),
        ("Bridge", 0.135, .stateWarning),
        ("Chorus", 0.144, .accentPrimary),
        ("Outro",  0.190, .textQuat)
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabelText(text: "Section Map · 3:42")
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(0..<segs.count, id: \.self) { i in
                        let s = segs[i]
                        ZStack {
                            Rectangle().fill(s.color)
                            Text(s.name)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .frame(width: max(20, geo.size.width * s.frac))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 22)
            .cornerRadius(3)
        }
        .padding(10)
        .background(Color.bgElevated)
        .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(Color.borderSubtle, lineWidth: 0.5))
        .cornerRadius(Radius.button)
    }
}

private struct ActionRow: View {
    var body: some View {
        HStack(spacing: 6) {
            actBtn("生成新歌（用副歌音色）", "sparkles", primary: true)
            actBtn("Remix 这首歌", "arrow.triangle.2.circlepath")
            actBtn("打开 Editor 精修", "waveform.path")
            actBtn("导出分析报告", "arrow.down.to.line")
        }
    }
    private func actBtn(_ title: String, _ symbol: String, primary: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
            Text(title).font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(primary ? .white : .textPrimary)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(primary ? Color.accentPrimary : Color.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(primary ? Color.accentPrimary : Color.borderStrong, lineWidth: 1)
        )
    }
}

private struct UserFollowUpMessage: View {
    var body: some View {
        MessageRow(avatar: "JQ", avatarBg: .bgElevated, avatarFg: .textSecondary, name: "Jenny", time: "08:02", tag: nil) {
            Text("生成新歌，中文歌词，电子风格，3 分钟左右。BPM 用一样的 128。")
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .lineSpacing(3)
        }
    }
}

private struct AgentStreamingMessage: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        MessageRow(avatar: "L", avatarBg: .accentPrimary, avatarFg: .white, name: "Lumina Agent", time: "08:02", tag: "streaming") {
            paragraph
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            TypingIndicator(label: state.modelConnected
                            ? "Music 2.6 · streaming · 35% · est 14s"
                            : "模型未接通 · 演示数据 · 等真 JWT key")
                .padding(.top, 6)
        }
    }

    private var paragraph: Text {
        let p1 = Text("好。我用 ") + Text("Music 2.6").foregroundColor(.accentPrimary).bold()
        let p2 = Text(" 生成 4 个候选版本，") + Text("128 BPM / Em / 电子 / 3:00 / 女声主唱").foregroundColor(.accentSecondary).bold()
        let p3 = Text("。歌词我让 ") + Text("M3").foregroundColor(.accentPrimary).bold() + Text(" 先写 4 套候选，等你挑：")
        return p1 + p2 + p3
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
                Text("Ask Agent · 拖入音频文件 · 输入 / 快捷指令")
                    .font(.system(size: 13))
                    .foregroundColor(.textTertiary)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                HStack(spacing: 4) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 13)).foregroundColor(.textSecondary)
                        .frame(width: 28, height: 28)
                    Image(systemName: "mic")
                        .font(.system(size: 13)).foregroundColor(.textSecondary)
                        .frame(width: 28, height: 28)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11)).foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.accentPrimary))
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
                    Text(state.modelConnected ? "Connected: \(state.apiBackend)" : "Model offline · need JWT key")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
        .background(Color.bgElevated)
        .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .top)
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
