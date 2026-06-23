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
    private var streamingTask: Task<Void, Never>?

    init() {
        let client = ApiClient()
        self.api = client
        self.chat = ChatService(client: client)
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
            self.connectionMessage = "Connected: \(modelId)"
        } catch {
            self.modelConnected = false
            self.connectionMessage = "Auth failed: \(error.localizedDescription)"
        }
    }

    // MARK: Composer / chat

    /// Sends the current composer text to the agent. Appends a user message,
    /// then an empty assistant placeholder, then streams tokens into the
    /// placeholder as they arrive. Updates `isComposing` for the UI.
    func sendCurrentInput() {
        let text = composerInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isComposing else { return }
        composerInput = ""

        // 1. Append user message
        let userMsg = Message(role: .user, text: text)
        conversation.messages.append(userMsg)
        conversation.updatedAt = Date()

        // 2. If we're not connected, append a stub explaining and stop.
        guard modelConnected else {
            let stub = Message(
                role: .assistant,
                text: "我现在没有接到 MiniMax。请在 Preferences（⌘,）里粘贴 JWT key 后再试。",
                tag: "offline"
            )
            conversation.messages.append(stub)
            return
        }

        // 3. Append empty assistant placeholder & start streaming into it
        let placeholder = Message(
            role: .assistant,
            text: "",
            tag: "M3 · streaming",
            streaming: .init(label: "Receiving tokens…")
        )
        conversation.messages.append(placeholder)
        let placeholderIndex = conversation.messages.count - 1
        isComposing = true

        // Snapshot prior history excluding the placeholder & user msg we just added.
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

    /// Reset the conversation to an empty thread (e.g. "New Chat").
    func newConversation() {
        streamingTask?.cancel()
        isComposing = false
        conversation = Conversation(
            title: "Untitled",
            messages: []
        )
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
