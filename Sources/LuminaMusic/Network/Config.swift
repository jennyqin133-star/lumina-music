import Foundation
import Security

/// Loads MiniMax / API credentials from one of three sources, in priority order:
///
///   1. `~/.config/lumina/secrets.env`     (developer setup, never committed)
///   2. Process environment                (CI, ad-hoc shells)
///   3. macOS Keychain                     (production: user pastes into Preferences)
///
/// Lookup is read-only here — writes (`save()`) only go to the Keychain so that
/// production users don't have to know about the secrets.env file.
///
/// The Config snapshot is a value type — call `Config.current()` to re-read
/// after the user changes the key in Preferences.
public struct Config: Equatable {
    public var apiKey: String?
    public var groupId: String?
    public var apiBase: URL

    public static let defaultBase = URL(string: "https://api.minimaxi.com")!
    public static let secretsPath = "\(NSHomeDirectory())/.config/lumina/secrets.env"
    public static let keychainService = "io.minimaxi.lumina.music"
    public static let keychainAccountAPIKey = "MINIMAX_API_KEY"
    public static let keychainAccountGroupID = "MINIMAX_GROUP_ID"

    public var isUsable: Bool { !(apiKey?.isEmpty ?? true) }

    // MARK: Snapshot

    public static func current() -> Config {
        let env = loadDotEnvFile()
        let merged: (String) -> String? = { key in
            ProcessInfo.processInfo.environment[key].flatMap(nonEmpty)
                ?? env[key].flatMap(nonEmpty)
                ?? readFromKeychain(account: key).flatMap(nonEmpty)
        }
        let key = merged("MINIMAX_API_KEY")
        let group = merged("MINIMAX_GROUP_ID")
        let base = merged("MINIMAX_API_BASE")
            .flatMap(URL.init(string:))
            ?? Self.defaultBase

        return Config(apiKey: key, groupId: group, apiBase: base)
    }

    // MARK: Persistence — Keychain only

    /// Stores the API key + group ID in the macOS Keychain (in the user's login
    /// keychain). Throws on failure so the Preferences window can surface the
    /// system error to the user.
    public static func save(apiKey: String, groupId: String?) throws {
        try writeToKeychain(account: keychainAccountAPIKey, value: apiKey)
        try writeToKeychain(account: keychainAccountGroupID, value: groupId ?? "")
    }

    // MARK: Sources

    /// Reads a tiny KEY=VALUE .env file. Lines starting with `#` are comments;
    /// surrounding double-quotes on the value are stripped. Returns empty
    /// on missing/unreadable file.
    private static func loadDotEnvFile() -> [String: String] {
        guard let raw = try? String(contentsOfFile: secretsPath, encoding: .utf8) else {
            return [:]
        }
        var out: [String: String] = [:]
        for line in raw.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<eq].trimmingCharacters(in: .whitespaces)
            var val = trimmed[trimmed.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if val.hasPrefix("\""), val.hasSuffix("\""), val.count >= 2 {
                val = String(val.dropFirst().dropLast())
            }
            out[key] = val
        }
        return out
    }

    private static func nonEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func readFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrService as String:     keychainService,
            kSecAttrAccount as String:     account,
            kSecReturnData as String:      true,
            kSecMatchLimit as String:      kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8)
        else { return nil }
        return str
    }

    private static func writeToKeychain(account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError("encode utf8 failed")
        }
        let base: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  account,
        ]
        // Try update first; if not present, add.
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw KeychainError("SecItemAdd OSStatus \(addStatus)")
            }
            return
        }
        throw KeychainError("SecItemUpdate OSStatus \(updateStatus)")
    }
}

public struct KeychainError: Error, CustomStringConvertible {
    public let description: String
    public init(_ message: String) { self.description = "KeychainError: \(message)" }
}
