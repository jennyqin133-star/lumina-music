import SwiftUI

// MARK: - Reusable building blocks

struct InsetCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .background(Color.bgInset)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
            .cornerRadius(Radius.button)
    }
}

struct LabelText: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.6)
            .foregroundColor(.textTertiary)
    }
}

struct StatBox: View {
    let value: String
    let key: String
    var color: Color = .textPrimary
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(color)
            Text(key.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgInset)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
        .cornerRadius(4)
    }
}

struct Chip: View {
    let text: String
    var style: ChipStyle = .neutral
    enum ChipStyle { case neutral, primary, secondary }
    var fg: Color {
        switch style {
        case .neutral:   return .textSecondary
        case .primary:   return .accentPrimary
        case .secondary: return .accentSecondary
        }
    }
    var bg: Color {
        switch style {
        case .neutral:   return .bgInset
        case .primary:   return Color.accentPrimary.opacity(0.12)
        case .secondary: return Color.accentSecondary.opacity(0.12)
        }
    }
    var border: Color {
        switch style {
        case .neutral:   return .borderSubtle
        case .primary:   return Color.accentPrimary.opacity(0.35)
        case .secondary: return Color.accentSecondary.opacity(0.35)
        }
    }
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(bg)
            )
            .overlay(
                Capsule().stroke(border, lineWidth: 0.5)
            )
    }
}

struct PrimaryButton: View {
    let title: String
    let symbol: String?
    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
            Text(title).font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Radius.button)
                .fill(Color.accentPrimary)
        )
    }
}

struct BorderedButton: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(Color.borderStrong, lineWidth: 1)
            )
    }
}

// MARK: - Placeholder tab body
struct ComingSoonView: View {
    let title: String
    let blurb: String
    let symbol: String
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.textTertiary)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text(blurb)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }
}

// MARK: - Public FlowChips (used by both Agent and Editor inspectors)
struct FlowChips: View {
    let items: [(String, Chip.ChipStyle)]
    var body: some View {
        let chunks = chunkInto(items, perRow: 3)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<chunks.count, id: \.self) { i in
                HStack(spacing: 4) {
                    ForEach(0..<chunks[i].count, id: \.self) { j in
                        let it = chunks[i][j]
                        Chip(text: it.0, style: it.1)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
    private func chunkInto(_ arr: [(String, Chip.ChipStyle)], perRow: Int) -> [[(String, Chip.ChipStyle)]] {
        var out: [[(String, Chip.ChipStyle)]] = []
        var i = 0
        while i < arr.count {
            let end = min(i + perRow, arr.count)
            out.append(Array(arr[i..<end]))
            i = end
        }
        return out
    }
}
