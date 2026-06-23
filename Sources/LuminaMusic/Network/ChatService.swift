import Foundation

/// Talks to MiniMax open-platform chat-completion endpoint
/// (`/v1/text/chatcompletion_v2`, model `MiniMax-M1` / `abab6.5s-chat`).
///
/// We expose two surfaces:
///   - `ping()`         — single quick request used at app startup to verify
///                         JWT auth works. Returns the model id on success;
///                         throws on auth failure.
///   - `streamReply()`  — SSE stream of token deltas for live UI rendering.
///                         Yields plain text chunks the AgentTabView appends
///                         to the current assistant message.
public final class ChatService {
    public let client: ApiClient
    private let model: String

    public init(client: ApiClient, model: String = "MiniMax-M1") {
        self.client = client
        self.model = model
    }

    // MARK: Ping (used at app launch / preferences save)

    /// Returns the responding model id (e.g. "MiniMax-M1") if the API key
    /// works and the model accepts our request. Throws ApiError otherwise.
    public func ping() async throws -> String {
        let req = ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "system", content: "You are Lumina Music's onboard agent."),
                .init(role: "user", content: "ping"),
            ],
            stream: false,
            maxTokens: 16,
            temperature: 0.0,
            topP: 1.0
        )
        let resp: ChatCompletionResponse = try await client.postJSON(
            path: "/v1/text/chatcompletion_v2",
            body: req
        )
        return resp.model ?? model
    }

    // MARK: Streaming

    /// Open an SSE chat completion. Yields delta-text chunks as they arrive.
    /// Errors are surfaced via the stream's terminal close (await for-in).
    public func streamReply(
        history: [Message],
        userText: String,
        systemPrompt: String = ChatService.defaultSystemPrompt
    ) -> AsyncThrowingStream<String, Error> {
        var apiMessages: [ChatCompletionRequest.Message] = [
            .init(role: "system", content: systemPrompt)
        ]
        for m in history {
            switch m.role {
            case .system:
                apiMessages.append(.init(role: "system", content: m.text))
            case .user:
                apiMessages.append(.init(role: "user", content: m.text))
            case .assistant:
                apiMessages.append(.init(role: "assistant", content: m.text))
            }
        }
        apiMessages.append(.init(role: "user", content: userText))

        let req = ChatCompletionRequest(
            model: model,
            messages: apiMessages,
            stream: true,
            maxTokens: 4096,
            temperature: 0.7,
            topP: 0.95
        )

        let upstream = client.streamSSE(
            path: "/v1/text/chatcompletion_v2",
            body: req,
            as: ChatCompletionStreamChunk.self
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in upstream {
                        if Task.isCancelled { break }
                        switch event {
                        case .data(let chunk, _):
                            if let delta = chunk.firstDelta {
                                continuation.yield(delta)
                            }
                        case .meta:
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public static let defaultSystemPrompt: String = """
    You are Lumina Music's in-app assistant. You help the user analyze, \
    compose, edit, and finish original music. Be concise and concrete; reply \
    in the user's language. When the user uploads a song, summarize structure, \
    BPM, key, style and vocal character before suggesting next steps. When the \
    user wants to generate music, first confirm: language (Chinese / English / \
    mixed), style, BPM, target duration, then call the music generation tool.
    """
}

// MARK: - Wire format

public struct ChatCompletionRequest: Encodable, Sendable {
    public let model: String
    public let messages: [Message]
    public let stream: Bool
    public let maxTokens: Int
    public let temperature: Double
    public let topP: Double

    public struct Message: Encodable, Sendable {
        public let role: String
        public let content: String
    }
}

public struct ChatCompletionResponse: Decodable {
    public let id: String?
    public let model: String?
    public let choices: [Choice]?

    public struct Choice: Decodable {
        public let message: Message?
        public let finishReason: String?
    }
    public struct Message: Decodable {
        public let role: String?
        public let content: String?
    }
}

/// SSE chunks have a single delta per choice; we only ever look at the first.
public struct ChatCompletionStreamChunk: Decodable {
    public let choices: [Choice]?
    public struct Choice: Decodable {
        public let delta: Delta?
        public let finishReason: String?
    }
    public struct Delta: Decodable {
        public let role: String?
        public let content: String?
    }

    var firstDelta: String? {
        choices?.first?.delta?.content
    }
}
