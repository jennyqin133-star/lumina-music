import SwiftUI
import AppKit

// MARK: - §9.0.1 Color Tokens
extension Color {
    static let bgBase       = Color(red: 0x0E/255, green: 0x0F/255, blue: 0x13/255)
    static let bgElevated   = Color(red: 0x16/255, green: 0x18/255, blue: 0x21/255)
    static let bgInset      = Color(red: 0x0A/255, green: 0x0B/255, blue: 0x0F/255)
    static let bgDeep       = Color(red: 0x06/255, green: 0x07/255, blue: 0x0A/255)
    static let borderSubtle = Color(red: 0x23/255, green: 0x26/255, blue: 0x2F/255)
    static let borderStrong = Color(red: 0x3A/255, green: 0x3D/255, blue: 0x47/255)
    static let textPrimary   = Color(red: 0xEC/255, green: 0xEE/255, blue: 0xF2/255)
    static let textSecondary = Color(red: 0xA0/255, green: 0xA4/255, blue: 0xAE/255)
    static let textTertiary  = Color(red: 0x5E/255, green: 0x63/255, blue: 0x70/255)
    static let textQuat      = Color(red: 0x3F/255, green: 0x43/255, blue: 0x4C/255)

    static let accentPrimary   = Color(red: 0x7C/255, green: 0x5C/255, blue: 0xFF/255)
    static let accentSecondary = Color(red: 0x3F/255, green: 0xB6/255, blue: 0xA8/255)
    static let stateWarning    = Color(red: 0xE0/255, green: 0xA2/255, blue: 0x4A/255)
    static let stateDanger     = Color(red: 0xE0/255, green: 0x59/255, blue: 0x6B/255)

    static let trackVocal = Color(red: 0x7C/255, green: 0x5C/255, blue: 0xFF/255)
    static let trackInst  = Color(red: 0x3F/255, green: 0xB6/255, blue: 0xA8/255)
    static let trackDrum  = Color(red: 0xE0/255, green: 0xA2/255, blue: 0x4A/255)
    static let trackSynth = Color(red: 0xC9/255, green: 0x7A/255, blue: 0xEA/255)
}

// MARK: - §9.0.2 Typography
enum Typo {
    static let ui      = Font.system(size: 13, weight: .regular)
    static let uiBold  = Font.system(size: 13, weight: .semibold)
    static let uiSmall = Font.system(size: 11, weight: .regular)
    static let mono    = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let monoSm  = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let display = Font.system(size: 14, weight: .semibold)
    static let label   = Font.system(size: 9, weight: .semibold).leading(.standard)
}

// MARK: - §9.0.4 Spacing & Radii
enum Radius {
    static let card: CGFloat = 10
    static let button: CGFloat = 6
    static let input: CGFloat = 8
    static let clip: CGFloat = 4
}

// MARK: - Tabs
enum AppTab: String, CaseIterable, Identifiable {
    case agent   = "Agent"
    case editor  = "Editor"
    case dj      = "DJ"
    case artwork = "Artwork"
    var id: String { rawValue }
    var sfSymbol: String {
        switch self {
        case .agent:   return "bubble.left.and.bubble.right"
        case .editor:  return "waveform.path"
        case .dj:      return "headphones"
        case .artwork: return "photo.on.rectangle"
        }
    }
}
