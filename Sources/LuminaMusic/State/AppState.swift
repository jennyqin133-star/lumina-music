import SwiftUI
import Combine

// MARK: - App-wide state
//
// Holds:
//   - the currently selected tab (top bar)
//   - lightweight metadata about the active project
//   - the live Conversation in the Agent tab
//   - API connection status (driven by Network/ChatService.ping)
//
// Single source of truth �� both UI and Network code observe / mutate it
// via @EnvironmentObject on the View side.
@MainActor
final class AppState: ObservableObject {
    // MARK: Tab + project metadata
    @Published var selectedTab: AppTab = .agent
    @Published var projectName: String = "Lost Highway"
    @Published var bpm: Double = 128.0
    @Published var key: String = "Em"
    @Published var duration: String = "3:42"
    @Published var modified: Bool = true
    @Published var apiBackend: String = "M3 · Music 2.6 · Speech 2.8 HD · Seedream 4.0"

    // MARK: API connection
    @Published var modelConnected: Bool = false
    @Published var connectionMessage: String = "Model offline · need JWT key"
    @Published var isPinging: Bool = false

    // MARK: Conversation (Agent tab)
    @Published var conversation: Conversation = .demoSeed
    @Published var isComposing: Bool = false   // assistant is replying
    @Published var composerInput: String = ""

    // MARK: Networking
    let api: ApiClient
    let chat: ChatService
    let music: MusicService
    let linkImport = LinkImportService()
    private var streamingTask: Task<Void, Never>?

    // MARK: Audio (current source)
    let audioEngine = AudioEngine.shared
    @Published var currentAudioURL: URL? = nil
    @Published var currentAudioPeaks: [Float] = []
    @Published var currentAudioAnalysis: AnalysisSummary? = nil
    @Published var isAnalysing: Bool = false

    // MARK: Generation
    @Published var isGenerating: Bool = false
    @Published var lastGeneratedURL: URL? = nil

    init() {
        let client = ApiClient()
        self.api = client
        self.chat = ChatService(client: client)
        self.music = MusicService(client: client)
    }

    // MARK: Lifecycle

    func bootstrap() {
        Task { await self.refreshConnection() }
    }

    func refreshConnection() async {
        api.refreshConfig()
        guard api.isUsable else {
            self.modelConnected = false
            self.connectionMessage = "Model offline · paste JWT in Preferences (⌘,)"
            return
        }
        self.isPinging = true
        defer { self.isPinging = false }
        do {
            let modelId = try await chat.ping()
            self.modelConnected = true
            // Friendly format: tell user *which* model they're actually on
            // (M3 if available, else fallback M1) + which downstream models
            // we can reach.
            self.connectionMessage = "\(modelId) chat · Music 2.6 · Speech 2.8 HD"
            self.apiBackend = modelId
        } catch {
            self.modelConnected = false
            self.connectionMessage = "Auth failed: \(error.localizedDescription)"
        }
    }

    // MARK: Composer / chat

    /// Sends the current composer text to the agent. Appends a user message,
    /// then an empty assistant placeholder, then streams tokens into the
    /// placeholder as they arrive. Updates `isComposing` for the UI.
    ///
    /// Pre-routing (PRD v4 §1):
    ///   - If the trimmed text is a valid local file path → open as audio.
    ///   - If it's an http/https URL → attempt link import.
    ///   - Otherwise → normal chat completion.
    func sendCurrentInput() {
        let text = composerInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isComposing else { return }
        composerInput = ""

        // Route 1: local file path
        if Self.looksLikePath(text), FileManager.default.fileExists(atPath: text) {
            openAudioFile(at: URL(fileURLWithPath: text))
            return
        }

        // Route 2: URL
        if Self.looksLikeURL(text) {
            handlePastedLink(text)
            return
        }

        // Route 3: plain chat (default)
        sendChatMessage(text)
    }

    /// Called by paste handler / drop handler when a URL is detected.
    func handlePastedLink(_ urlString: String) {
        // Append a user message so the conversation reflects what they did
        conversation.messages.append(
            Message(role: .user, text: urlString)
        )

        // Loading placeholder from Lumina
        let placeholder = Message(
            role: .assistant,
            text: "尝试从链接下载…\n\(urlString)",
            tag: "link · fetch",
            streaming: .init(label: "downloading…")
        )
        conversation.messages.append(placeholder)
        let idx = conversation.messages.count - 1
        isComposing = true

        Task { [weak self] in
            guard let self else { return }
            let outcome = await self.linkImport.attemptImport(urlString: urlString)
            await MainActor.run {
                if idx < self.conversation.messages.count {
                    self.conversation.messages.remove(at: idx)
                }
                self.isComposing = false
            }
            switch outcome {
            case .imported(let localURL, _, _):
                await MainActor.run {
                    self.conversation.messages.append(
                        Message(
                            role: .assistant,
                            text: "✓ 下载成功: \(localURL.lastPathComponent)。正在分析…",
                            tag: "link · ok"
                        )
                    )
                }
                self.openAudioFile(at: localURL)

            case .notAudio(let contentType, _):
                await MainActor.run {
                    self.conversation.messages.append(
                        Message(
                            role: .assistant,
                            text: "这个链接返回的不是音频文件 (Content-Type: \(contentType))。可能是个网页 — 请在浏览器打开下载 mp3 后再上传。",
                            tag: "link · not audio"
                        )
                    )
                }

            case .blocked(let reason, let status):
                let stat = status.map { "（HTTP \($0)）" } ?? ""
                await MainActor.run {
                    self.conversation.messages.append(
                        Message(
                            role: .assistant,
                            text: "✗ 链接拉取失败\(stat): \(reason)",
                            tag: "link · blocked"
                        )
                    )
                }
            }
        }
    }

    /// Pure chat completion — extracted from sendCurrentInput so the path /
    /// URL routes can stay clean.
    private func sendChatMessage(_ text: String) {
        let userMsg = Message(role: .user, text: text)
        conversation.messages.append(userMsg)
        conversation.updatedAt = Date()

        guard modelConnected else {
            let stub = Message(
                role: .assistant,
                text: "我现在没有接到 MiniMax。请在 Preferences（⌘,）里粘贴 JWT key 后再试。",
                tag: "offline"
            )
            conversation.messages.append(stub)
            return
        }

        let placeholder = Message(
            role: .assistant,
            text: "",
            tag: "M3 · streaming",
            streaming: .init(label: "Receiving tokens…")
        )
        conversation.messages.append(placeholder)
        let placeholderIndex = conversation.messages.count - 1
        isComposing = true

        let history = Array(conversation.messages.dropLast(2))

        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = self.chat.streamReply(history: history, userText: text)
                for try await delta in stream {
                    await MainActor.run {
                        guard placeholderIndex < self.conversation.messages.count else { return }
                        self.conversation.messages[placeholderIndex].text += delta
                    }
                }
                await MainActor.run {
                    if placeholderIndex < self.conversation.messages.count {
                        var done = self.conversation.messages[placeholderIndex]
                        done.streaming = nil
                        done.tag = "M3"
                        self.conversation.messages[placeholderIndex] = done
                    }
                    self.isComposing = false
                }
            } catch {
                await MainActor.run {
                    if placeholderIndex < self.conversation.messages.count {
                        var fail = self.conversation.messages[placeholderIndex]
                        fail.text += "\n\n⚠ \(error.localizedDescription)"
                        fail.streaming = nil
                        fail.tag = "error"
                        self.conversation.messages[placeholderIndex] = fail
                    }
                    self.isComposing = false
                }
            }
        }
    }

    // MARK: Routing helpers

    private static func looksLikePath(_ s: String) -> Bool {
        // Absolute path or ~/-prefixed
        if s.hasPrefix("/") || s.hasPrefix("~") { return true }
        // file:// URL
        if s.lowercased().hasPrefix("file://") { return true }
        return false
    }

    private static func looksLikeURL(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://")
    }

    /// Reset the conversation to an empty thread (e.g. "New Chat").
    func newConversation() {
        streamingTask?.cancel()
        isComposing = false
        conversation = Conversation(
            title: "Untitled",
            messages: []
        )
    }

    // MARK: - Audio loading

    /// Load a local audio file: kick AVAudioEngine to play-ready state,
    /// extract a waveform peak array on a background task, run a quick
    /// local analysis (BPM/Key/LUFS), and append a Lumina message in the
    /// chat acknowledging the upload.
    func openAudioFile(at url: URL) {
        audioEngine.load(url: url)
        currentAudioURL = url
        currentAudioPeaks = []
        currentAudioAnalysis = nil
        isAnalysing = true

        let filename = url.lastPathComponent
        let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        let duration = audioEngine.duration
        let attachment = Message.AudioAttachment(
            filename: filename,
            sizeBytes: sizeBytes,
            durationSeconds: duration > 0 ? duration : nil,
            bitrate: nil,
            localPath: url.path
        )
        conversation.messages.append(
            Message(role: .user, text: "我上传了 \(filename)", attachment: attachment)
        )

        // Off-thread analysis
        Task.detached(priority: .userInitiated) { [weak self] in
            let peaks = AudioEngine.extractWaveformPeaks(url: url, resolution: 512)
            let analysis = AudioAnalyser.analyse(url: url)
            guard let strongSelf = self else { return }
            await MainActor.run {
                strongSelf.currentAudioPeaks = peaks ?? []
                strongSelf.currentAudioAnalysis = analysis
                strongSelf.isAnalysing = false
                if let a = analysis {
                    strongSelf.bpm = a.bpm > 0 ? a.bpm : strongSelf.bpm
                    strongSelf.key = a.keyGuess
                    let summary = """
                    本地分析跑完了:
                    • BPM \(String(format: "%.1f", a.bpm))
                    • Key 估计 \(a.keyGuess)
                    • 响度 \(String(format: "%.1f", a.lufs)) LUFS
                    • 时长 \(String(format: "%.1f", a.durationSec))s · 音色 \(a.brightTag)
                    要不要我用 Music 2.6 基于这个风格生成新歌? 告诉我语言、时长、想要的情绪就好。
                    """
                    strongSelf.conversation.messages.append(
                        Message(role: .assistant, text: summary, tag: "local · audio.analyze")
                    )
                }
            }
        }
    }

    // MARK: - Music generation (Music 2.6)

    /// Submit a music generation job and stream the result into the chat.
    /// `pendingChoice` blocks if language hasn't been chosen — the UI shows a
    /// modal first then calls back.
    func generateMusic(spec: GenerationSpec) {
        guard modelConnected else {
            conversation.messages.append(
                Message(
                    role: .assistant,
                    text: "我现在没有接到 MiniMax。请在 Preferences（⌘,）里粘贴 JWT key 后再试。",
                    tag: "offline"
                )
            )
            return
        }
        isGenerating = true
        let placeholder = Message(
            role: .assistant,
            text: "正在用 Music 2.6 生成歌曲… 语言 \(spec.language.display), 风格 \(spec.style), 时长 \(spec.durationSec)s",
            tag: "Music 2.6 · streaming",
            streaming: .init(label: "submitting…")
        )
        conversation.messages.append(placeholder)
        let placeholderIndex = conversation.messages.count - 1

        Task { [weak self] in
            guard let self else { return }
            do {
                let outcome = try await self.music.generate(spec: spec)
                let finalURL: URL
                switch outcome {
                case .inline(let audio, _, let dur, let format):
                    finalURL = try self.persistGenerated(data: audio, format: format)
                    await MainActor.run {
                        self.lastGeneratedURL = finalURL
                        let msg = Message(
                            role: .assistant,
                            text: "✔ 生成完成: \(finalURL.lastPathComponent) (≈ \(Int(dur))s)。已存到 ~/Library/Application Support/Lumina Music/generations/。",
                            tag: "Music 2.6",
                            attachment: .init(
                                filename: finalURL.lastPathComponent,
                                sizeBytes: Int64(audio.count),
                                durationSeconds: dur > 0 ? dur : nil,
                                bitrate: 256,
                                localPath: finalURL.path
                            )
                        )
                        if placeholderIndex < self.conversation.messages.count {
                            self.conversation.messages[placeholderIndex] = msg
                        } else {
                            self.conversation.messages.append(msg)
                        }
                    }
                case .queued(let taskId, _):
                    await MainActor.run {
                        if placeholderIndex < self.conversation.messages.count {
                            var p = self.conversation.messages[placeholderIndex]
                            p.streaming = .init(label: "queued · task \(taskId)…")
                            self.conversation.messages[placeholderIndex] = p
                        }
                    }
                    finalURL = try await self.pollUntilDone(taskId: taskId, placeholderIndex: placeholderIndex)
                    await MainActor.run { self.lastGeneratedURL = finalURL }
                }
            } catch {
                await MainActor.run {
                    if placeholderIndex < self.conversation.messages.count {
                        var p = self.conversation.messages[placeholderIndex]
                        p.text += "\n\n⚠ \(error.localizedDescription)"
                        p.streaming = nil
                        p.tag = "error"
                        self.conversation.messages[placeholderIndex] = p
                    }
                }
            }
            await MainActor.run { self.isGenerating = false }
        }
    }

    private func pollUntilDone(taskId: String, placeholderIndex: Int) async throws -> URL {
        for _ in 0..<60 {  // up to ~5 minutes at 5s cadence
            try await Task.sleep(nanoseconds: 5_000_000_000)
            let outcome = try await music.pollResult(taskId: taskId)
            if case .inline(let audio, _, let dur, let format) = outcome {
                let url = try persistGenerated(data: audio, format: format)
                await MainActor.run {
                    if placeholderIndex < self.conversation.messages.count {
                        let msg = Message(
                            role: .assistant,
                            text: "✔ 生成完成: \(url.lastPathComponent) (≈ \(Int(dur))s)。",
                            tag: "Music 2.6",
                            attachment: .init(
                                filename: url.lastPathComponent,
                                sizeBytes: Int64(audio.count),
                                durationSeconds: dur > 0 ? dur : nil,
                                bitrate: 256,
                                localPath: url.path
                            )
                        )
                        self.conversation.messages[placeholderIndex] = msg
                    }
                }
                return url
            }
        }
        throw NSError(
            domain: "Lumina.MusicService",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Generation did not finish within 5 minutes."]
        )
    }

    private func persistGenerated(data: Data, format: String) throws -> URL {
        let dir = try Self.appSupportDir().appendingPathComponent("generations", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("gen-\(stamp).\(format)")
        try data.write(to: url)
        return url
    }

    private static func appSupportDir() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("Lumina Music", isDirectory: true)
    }
}

// MARK: - Demo seed (shown when no real API is configured yet, so the UI
// is never empty / depressing at first launch).

extension Conversation {
    static var demoSeed: Conversation {
        Conversation(
            title: "Lost Highway · Pop-Rock",
            messages: [
                Message(
                    role: .user,
                    text: "帮我分析这首歌的结构和风格。我特别喜欢副歌那段的音色，想用类似的感觉生成一首新歌。",
                    timestamp: dateAt(8, 1),
                    attachment: .init(
                        filename: "lost-highway-reference.mp3",
                        sizeBytes: 5_872_640,
                        durationSeconds: 222,
                        bitrate: 320
                    )
                ),
                Message(
                    role: .assistant,
                    text: "收到。先帮你跑完整套分析——结构 / BPM / Key / 风格 / 音色 / 能量曲线，一会儿就好。",
                    timestamp: dateAt(8, 1),
                    tag: "M3 · analysis"
                ),
                Message(
                    role: .assistant,
                    text: """
                    这首是标准 Pop-Rock，128 BPM、E 小调，3:42 全长。结构很经典：\
                    前奏 → 主歌 A → 副歌 → 主歌 B → 副歌 → 桥段 → 副歌 → 尾奏。\

                    你说\u{201C}喜欢副歌的音色\u{201D}——第一段副歌在 0:32–1:02。\
                    女声偏亮的抒情嗓 + 合成器铺底 + 紧凑鼓点 + 副贝斯，能量比主歌高 +6 dB。
                    """,
                    timestamp: dateAt(8, 1)
                ),
                Message(
                    role: .user,
                    text: "生成新歌，中文歌词，电子风格，3 分钟左右。BPM 用一样的 128。",
                    timestamp: dateAt(8, 2)
                ),
                Message(
                    role: .assistant,
                    text: "好。我用 Music 2.6 生成 4 个候选版本，128 BPM / Em / 电子 / 3:00 / 女声主唱。歌词我让 M3 先写 4 套候选，等你挑：",
                    timestamp: dateAt(8, 2),
                    tag: "streaming",
                    streaming: .init(label: "模型未接通 · 演示数据 · 等真 JWT key")
                ),
            ]
        )
    }

    private static func dateAt(_ hour: Int, _ minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour; comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}
