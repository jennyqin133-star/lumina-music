import Foundation

/// Tiny URLSession-based HTTP client for MiniMax open-platform endpoints.
///
/// Centralises:
///   - JWT Bearer auth header injection
///   - GroupId query-param injection (some endpoints require it)
///   - URL composition + JSON encoding/decoding
///   - SSE / chunked-line streaming via AsyncThrowingStream
///   - Friendly mapping of platform error codes (1004 etc.) to errors users
///     can act on.
///
/// Endpoint-specific wrappers live in ChatService / MusicService / TtsService.
public final class ApiClient: @unchecked Sendable {
    private let session: URLSession
    private var config: Config

    public init(config: Config = .current(), session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func refreshConfig() {
        self.config = Config.current()
    }

    public var isUsable: Bool { config.isUsable }
    public var snapshot: Config { config }

    // MARK: - JSON request → JSON response

    public func postJSON<Response: Decodable>(
        path: String,
        body: Encodable,
        addGroupId: Bool = true,
        as: Response.Type = Response.self
    ) async throws -> Response {
        let req = try makeRequest(path: path, method: "POST", body: body, addGroupId: addGroupId)
        let (data, resp) = try await session.data(for: req)
        try Self.throwIfHTTPError(resp: resp, body: data)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw ApiError.malformedResponse(
                underlying: error,
                preview: String(data: data, encoding: .utf8)?.prefix(800).description ?? "<binary>"
            )
        }
    }

    // MARK: - SSE streaming

    /// Returns an async stream of decoded JSON lines from an SSE response.
    /// Each `data:` line is decoded as `Element`. Lines that are exactly
    /// `[DONE]` end the stream cleanly. Non-`data:` lines (event: / id: /
    /// comments) are surfaced via `meta` for callers that care.
    public func streamSSE<Element: Decodable>(
        path: String,
        body: Encodable,
        addGroupId: Bool = true,
        as: Element.Type = Element.self
    ) -> AsyncThrowingStream<SSEEvent<Element>, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [self] in
                do {
                    let req = try makeRequest(path: path, method: "POST", body: body, addGroupId: addGroupId, sse: true)
                    let (bytes, resp) = try await session.bytes(for: req)
                    try Self.throwIfHTTPError(resp: resp, body: nil)

                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase

                    var currentEvent: String?
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if line.isEmpty {
                            currentEvent = nil
                            continue
                        }
                        if line.hasPrefix(":") { continue }       // comment / keepalive
                        if line.hasPrefix("event:") {
                            currentEvent = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
                            continue
                        }
                        if line.hasPrefix("data:") {
                            let raw = String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)
                            if raw == "[DONE]" {
                                break
                            }
                            guard let data = raw.data(using: .utf8) else { continue }
                            do {
                                let payload = try decoder.decode(Element.self, from: data)
                                continuation.yield(.data(payload, event: currentEvent))
                            } catch {
                                // Some endpoints emit non-element control frames; bubble as meta.
                                continuation.yield(.meta(raw: raw, event: currentEvent))
                            }
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

    public enum SSEEvent<Element> {
        case data(Element, event: String?)
        case meta(raw: String, event: String?)
    }

    // MARK: - Request shaping

    private func makeRequest(
        path: String,
        method: String,
        body: Encodable?,
        addGroupId: Bool,
        sse: Bool = false
    ) throws -> URLRequest {
        guard let key = config.apiKey, !key.isEmpty else {
            throw ApiError.notConfigured
        }
        var comps = URLComponents(url: config.apiBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if addGroupId, let group = config.groupId, !group.isEmpty {
            var items = comps?.queryItems ?? []
            items.append(URLQueryItem(name: "GroupId", value: group))
            comps?.queryItems = items
        }
        guard let url = comps?.url else {
            throw ApiError.badURL(path)
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if sse {
            req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        } else {
            req.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        req.timeoutInterval = 60

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }
        return req
    }

    // MARK: - Error mapping

    private static func throwIfHTTPError(resp: URLResponse, body: Data?) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        if (200..<300).contains(http.statusCode) {
            // Some MiniMax endpoints return 200 with a nested `base_resp.status_code`
            // indicating failure (1004 == auth fail, 1008 == insufficient balance).
            // Try to detect that cheaply without forcing a separate decode path.
            if let body, let parsed = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let baseResp = parsed["base_resp"] as? [String: Any],
               let code = baseResp["status_code"] as? Int,
               code != 0 {
                let msg = baseResp["status_msg"] as? String ?? "unknown"
                throw ApiError.platform(code: code, message: msg)
            }
            return
        }
        let snippet = body.flatMap { String(data: $0, encoding: .utf8)?.prefix(500).description } ?? "<no body>"
        throw ApiError.http(status: http.statusCode, body: snippet)
    }
}

// MARK: - Error type

public enum ApiError: Error, LocalizedError {
    case notConfigured
    case badURL(String)
    case http(status: Int, body: String)
    case platform(code: Int, message: String)
    case malformedResponse(underlying: Error, preview: String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "MiniMax JWT API key not set. Open Preferences (⌘,) and paste your key."
        case .badURL(let path):
            return "Could not form request URL for \(path)."
        case .http(let status, let body):
            return "HTTP \(status): \(body)"
        case .platform(let code, let message):
            return "MiniMax platform error \(code): \(message)"
        case .malformedResponse(_, let preview):
            return "Malformed response: \(preview)"
        }
    }
}

// MARK: - AnyEncodable shim

/// Lets ApiClient accept any Encodable without making method generic on the request.
private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        self.encode = { encoder in try wrapped.encode(to: encoder) }
    }
    func encode(to encoder: Encoder) throws { try encode(encoder) }
}
