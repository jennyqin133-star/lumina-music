import Foundation

/// Talks to MiniMax open-platform music generation
/// (`/v1/music_generation`, model `music-2.6`).
///
/// MVP surface:
///   - `generate(spec:)`        — submit a job, return either inline audio bytes
///                                (small jobs) or a task id for polling.
///   - `pollResult(taskId:)`    — poll a queued generation until done.
///
/// We deliberately keep the spec narrow to MVP needs (lyrics, refer to a style,
/// language, bpm, duration). Later phases add cover / reference_audio_id /
/// num_versions / vocal cloning.
public final class MusicService {
    public let client: ApiClient

    public init(client: ApiClient) { self.client = client }

    /// Result of a music_generation call. Either:
    ///   - inline: ready audio bytes (most common for short generations)
    ///   - queued: task id you should poll on a 2-5s cadence
    public enum Outcome {
        case inline(audio: Data, sampleRateHz: Int, durationSec: Double, format: String)
        case queued(taskId: String, estimatedSec: Int?)
    }

    public func generate(spec: GenerationSpec) async throws -> Outcome {
        let req = MusicGenerationRequest(spec: spec)
        let resp: MusicGenerationResponse = try await client.postJSON(
            path: "/v1/music_generation",
            body: req
        )
        // Server can choose to return either the audio inline (base64 hex) or
        // hand back a task_id we have to poll. Newer MiniMax Music 2.6 returns
        // hex audio in `data.audio`; older paths used `task_id`.
        if let audioHex = resp.data?.audio,
           let data = Data(hexString: audioHex),
           !data.isEmpty {
            return .inline(
                audio: data,
                sampleRateHz: resp.data?.sampleRate ?? 44_100,
                durationSec: resp.data?.duration ?? 0,
                format: resp.data?.audioFormat ?? "mp3"
            )
        }
        if let taskId = resp.taskId {
            return .queued(taskId: taskId, estimatedSec: resp.estimatedTime)
        }
        throw ApiError.malformedResponse(
            underlying: NSError(domain: "Lumina.MusicService", code: -1),
            preview: "no inline audio + no task_id"
        )
    }

    public func pollResult(taskId: String) async throws -> Outcome {
        let resp: MusicGenerationResponse = try await client.postJSON(
            path: "/v1/music_generation/\(taskId)",
            body: EmptyBody()
        )
        if let audioHex = resp.data?.audio, let data = Data(hexString: audioHex), !data.isEmpty {
            return .inline(
                audio: data,
                sampleRateHz: resp.data?.sampleRate ?? 44_100,
                durationSec: resp.data?.duration ?? 0,
                format: resp.data?.audioFormat ?? "mp3"
            )
        }
        // Still queued? Surface a transient queued result so callers can re-poll.
        return .queued(taskId: taskId, estimatedSec: resp.estimatedTime)
    }
}

// MARK: - Public spec types

public struct GenerationSpec: Sendable, Equatable {
    public var lyrics: String
    public var style: String         // e.g. "Pop, Dance-pop, female lead"
    public var language: Language    // selected by user via the modal
    public var bpm: Int?
    public var durationSec: Int      // 30..240
    public var emotion: String?      // optional
    public var creativity: Double    // 0...1

    public init(
        lyrics: String,
        style: String,
        language: Language,
        bpm: Int? = nil,
        durationSec: Int = 120,
        emotion: String? = nil,
        creativity: Double = 0.5
    ) {
        self.lyrics = lyrics
        self.style = style
        self.language = language
        self.bpm = bpm
        self.durationSec = max(30, min(240, durationSec))
        self.emotion = emotion
        self.creativity = max(0, min(1, creativity))
    }

    public enum Language: String, CaseIterable, Codable, Sendable {
        case chinese = "zh"
        case english = "en"
        case mixed   = "mixed"

        public var display: String {
            switch self {
            case .chinese: return "中文"
            case .english: return "English"
            case .mixed:   return "中英混合 / Bilingual"
            }
        }
    }
}

// MARK: - Wire format

struct MusicGenerationRequest: Encodable {
    let refer_voice: String? = nil
    let refer_instrumental: String? = nil
    let lyrics: String
    let model: String
    let audioSetting: AudioSetting

    init(spec: GenerationSpec) {
        // MiniMax encodes spec hints in the prompt because /v1/music_generation
        // is a text-conditioned API. Lyrics go in `lyrics`; style + language are
        // appended as a soft prompt.
        var prompt = spec.lyrics
        if !spec.style.isEmpty {
            prompt += "\n\nStyle: \(spec.style)"
        }
        prompt += "\nLanguage: \(spec.language.display)"
        if let bpm = spec.bpm {
            prompt += "\nBPM: \(bpm)"
        }
        if let emotion = spec.emotion {
            prompt += "\nEmotion: \(emotion)"
        }
        self.lyrics = prompt
        self.model = "music-2.6"
        self.audioSetting = AudioSetting(
            sampleRate: 44_100,
            bitrate: 256_000,
            format: "mp3"
        )
    }

    struct AudioSetting: Encodable {
        let sampleRate: Int
        let bitrate: Int
        let format: String

        // Map to the API's expected snake_case via custom keys.
        enum CodingKeys: String, CodingKey {
            case sampleRate = "sample_rate"
            case bitrate
            case format
        }
    }

    enum CodingKeys: String, CodingKey {
        case refer_voice, refer_instrumental, lyrics, model
        case audioSetting = "audio_setting"
    }
}

struct MusicGenerationResponse: Decodable {
    let taskId: String?
    let estimatedTime: Int?
    let data: GenerationData?

    struct GenerationData: Decodable {
        let audio: String?            // hex-encoded MP3
        let status: Int?              // 0 == in progress, 2 == complete
        let duration: Double?
        let sampleRate: Int?
        let audioFormat: String?
    }
}

private struct EmptyBody: Encodable {}

// MARK: - Hex decoding helper

extension Data {
    init?(hexString: String) {
        let cleaned = hexString.replacingOccurrences(of: " ", with: "")
        guard cleaned.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        for _ in 0..<(cleaned.count / 2) {
            let next = cleaned.index(index, offsetBy: 2)
            guard let b = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(b)
            index = next
        }
        self = Data(bytes)
    }
}
