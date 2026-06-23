import Foundation

// MARK: - Chat domain
//
// A Conversation is the unit of work in the Agent tab: a thread of messages
// between the user and the Lumina Agent (which is one or more LLM/audio
// model calls behind the scenes).
//
// Persistence and serialization live in Persistence/ProjectStore.swift —
// these types only model the shape and identity of a chat.

public struct Conversation: Identifiable, Codable, Hashable {
    public let id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var messages: [Message]

    public init(
        id: UUID = UUID(),
        title: String = "Untitled draft",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [Message] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

public struct Message: Identifiable, Codable, Hashable {
    public let id: UUID
    public var role: Role
    public var text: String
    public var timestamp: Date
    /// Free-form tag rendered as a small badge on the message bubble
    /// (e.g. "M3 · analysis", "streaming", "tool · audio.analyze").
    public var tag: String?
    /// Optional audio attachment, e.g. when the user uploaded a reference.
    public var attachment: AudioAttachment?
    /// `nil` when the assistant has finished streaming; non-nil while
    /// tokens are still arriving.
    public var streaming: StreamState?

    public init(
        id: UUID = UUID(),
        role: Role,
        text: String = "",
        timestamp: Date = Date(),
        tag: String? = nil,
        attachment: AudioAttachment? = nil,
        streaming: StreamState? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.tag = tag
        self.attachment = attachment
        self.streaming = streaming
    }

    public enum Role: String, Codable, Hashable {
        case user
        case assistant
        case system
    }

    public struct StreamState: Codable, Hashable {
        public var label: String      // e.g. "Music 2.6 · streaming · 35% · est 14s"
        public var percent: Double?   // 0...1 if known
        public init(label: String, percent: Double? = nil) {
            self.label = label
            self.percent = percent
        }
    }

    public struct AudioAttachment: Codable, Hashable {
        public var filename: String
        public var sizeBytes: Int64?
        public var durationSeconds: Double?
        public var bitrate: Int?
        public var localPath: String?
        public init(
            filename: String,
            sizeBytes: Int64? = nil,
            durationSeconds: Double? = nil,
            bitrate: Int? = nil,
            localPath: String? = nil
        ) {
            self.filename = filename
            self.sizeBytes = sizeBytes
            self.durationSeconds = durationSeconds
            self.bitrate = bitrate
            self.localPath = localPath
        }
    }
}
