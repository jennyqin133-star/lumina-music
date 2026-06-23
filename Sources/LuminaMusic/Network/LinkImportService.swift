import Foundation

// MARK: - LinkImportService
//
// User pastes a URL into the Agent composer (or drops it on the chat). We
// politely try to fetch it. Three outcomes:
//
//   .imported(localURL, contentType, sizeBytes)
//       — Success. The remote content is audio/* and was downloaded to a
//         temp directory; caller hands the URL to AppState.openAudioFile.
//
//   .notAudio(contentType, statusCode)
//       — HTTP 200 but the response isn't audio (probably an HTML page like
//         a NetEase / QQ Music landing page that's gated behind JS player).
//
//   .blocked(reason, statusCode?)
//       — Fetch failed with a meaningful error (403/anti-bot, 404, timeout,
//         network down).
//
// We intentionally do NOT implement yt-dlp / NetEase API scraping — those
// surfaces have anti-bot defences and would put Lumina on their block lists.
// Per user decision (B in v0.2.0 scope): "尝试访问失败给错".
public final class LinkImportService {

    public enum Outcome {
        case imported(localURL: URL, contentType: String, sizeBytes: Int)
        case notAudio(contentType: String, statusCode: Int)
        case blocked(reason: String, statusCode: Int?)
    }

    private let session: URLSession

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 120
        // Try to look like a normal browser so generic CDNs don't 403 us.
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept": "audio/*,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        ]
        self.session = URLSession(configuration: cfg)
    }

    /// Attempt to fetch the URL. The host is classified up front so we can
    /// tell the user "Lumina can't pull NetEase / QQ" without even trying.
    public func attemptImport(urlString: String) async -> Outcome {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host?.lowercased()
        else {
            return .blocked(reason: "无效的 URL 格式。", statusCode: nil)
        }

        // Known-hostile hosts → fast-fail with a useful explanation.
        if let knownBlockedReason = Self.knownBlockedHosts[host] {
            return .blocked(reason: knownBlockedReason, statusCode: nil)
        }
        for (suffix, reason) in Self.knownBlockedHostSuffixes {
            if host.hasSuffix(suffix) {
                return .blocked(reason: reason, statusCode: nil)
            }
        }

        // Generic GET. If it fails we still want HTTP status for the error.
        do {
            let (tmpURL, resp) = try await session.download(from: url)
            defer { try? FileManager.default.removeItem(at: tmpURL) }

            guard let http = resp as? HTTPURLResponse else {
                return .blocked(reason: "服务器响应无效。", statusCode: nil)
            }
            if !(200..<300).contains(http.statusCode) {
                return .blocked(
                    reason: explain(statusCode: http.statusCode),
                    statusCode: http.statusCode
                )
            }
            let contentType = (http.allHeaderFields["Content-Type"] as? String)
                ?? (http.allHeaderFields["content-type"] as? String)
                ?? "application/octet-stream"

            if !looksLikeAudio(contentType: contentType, url: url) {
                return .notAudio(contentType: contentType, statusCode: http.statusCode)
            }

            // Move the downloaded tmp file to a stable cache location.
            let finalURL = try persist(tmpURL: tmpURL, sourceURL: url)
            let size = (try? FileManager.default.attributesOfItem(atPath: finalURL.path)[.size] as? Int) ?? 0
            return .imported(localURL: finalURL, contentType: contentType, sizeBytes: size)

        } catch let urlErr as URLError {
            return .blocked(reason: friendly(urlErr), statusCode: nil)
        } catch {
            return .blocked(reason: error.localizedDescription, statusCode: nil)
        }
    }

    // MARK: - Persistence

    private func persist(tmpURL: URL, sourceURL: URL) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base
            .appendingPathComponent("Lumina Music", isDirectory: true)
            .appendingPathComponent("link-imports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let suggested = sourceURL.lastPathComponent.isEmpty
            ? "import-\(Int(Date().timeIntervalSince1970)).mp3"
            : sourceURL.lastPathComponent
        let final = dir.appendingPathComponent(suggested)
        try? FileManager.default.removeItem(at: final)
        try FileManager.default.moveItem(at: tmpURL, to: final)
        return final
    }

    // MARK: - Classification helpers

    private static let knownBlockedHosts: [String: String] = [
        "music.163.com":     "网易云音乐有强反爬保护, Lumina 无法直接拉取。请在浏览器下载 mp3 后上传。",
        "y.qq.com":          "QQ 音乐有强反爬保护, Lumina 无法直接拉取。请在浏览器下载 mp3 后上传。",
        "qishui.douyin.com": "汽水音乐 (字节跳动) 链接需要 App 内播放, Lumina 无法直接拉取。请录屏或在 App 内下载后上传。",
    ]

    private static let knownBlockedHostSuffixes: [(String, String)] = [
        (".163.com",      "网易系链接有反爬保护, Lumina 无法直接拉取。请下载 mp3 后上传。"),
        (".qq.com",       "腾讯系链接有反爬保护, Lumina 无法直接拉取。请下载 mp3 后上传。"),
        ("youtube.com",   "YouTube 不支持直接下载, 请使用第三方工具导出 mp3 后上传。"),
        ("youtu.be",      "YouTube 不支持直接下载, 请使用第三方工具导出 mp3 后上传。"),
        ("spotify.com",   "Spotify 受 DRM 保护, 无法直接下载。"),
        ("bilibili.com",  "B 站需要解析 BV 号, Lumina 暂未集成。请用浏览器下载视频音轨后上传。"),
    ]

    private func looksLikeAudio(contentType: String, url: URL) -> Bool {
        if contentType.lowercased().hasPrefix("audio/") { return true }
        // Some CDNs serve audio as application/octet-stream; fall back to ext.
        let ext = url.pathExtension.lowercased()
        return ["mp3", "wav", "flac", "m4a", "aac", "ogg", "opus"].contains(ext)
    }

    private func explain(statusCode: Int) -> String {
        switch statusCode {
        case 401, 403: return "服务器拒绝访问 (\(statusCode))。多半是反爬虫或需要登录。"
        case 404:      return "链接不存在或已失效 (404)。"
        case 429:      return "请求被限流 (429)。稍后再试。"
        case 500...599: return "服务器内部错误 (\(statusCode))。"
        default:       return "HTTP \(statusCode)。"
        }
    }

    private func friendly(_ err: URLError) -> String {
        switch err.code {
        case .timedOut:           return "网络超时, 服务器没有及时响应。检查链接是否能在浏览器打开。"
        case .notConnectedToInternet: return "未连接到互联网。"
        case .cannotFindHost:     return "找不到主机, 域名拼写错了?"
        case .cannotConnectToHost: return "无法连接到服务器。"
        case .networkConnectionLost: return "网络中断。"
        case .badServerResponse:  return "服务器响应无效。"
        default:                  return err.localizedDescription
        }
    }
}
