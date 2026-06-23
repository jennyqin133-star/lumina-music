import SwiftUI

// MARK: - Title Bar (custom non-NSToolbar — gives us full §9.0 visual control)
struct TitleBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Left: project meta
            HStack(spacing: 12) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentPrimary)
                Text(state.projectName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary)
                if state.modified {
                    Circle().fill(Color.stateWarning).frame(width: 5, height: 5)
                }
                Text("\(Int(state.bpm)) BPM · \(state.key) · \(state.duration)")
                    .font(Typo.monoSm)
                    .foregroundColor(.textTertiary)
            }
            .padding(.leading, 80)   // leave room for native traffic lights

            Spacer()

            // Center: tab switcher
            TabSwitcher()

            Spacer()

            // Right: tool icons + Export
            HStack(spacing: 4) {
                IconButton(symbol: "slider.horizontal.3")
                IconButton(symbol: "rectangle.stack")
                IconButton(symbol: "person.circle")
                ExportButton()
            }
            .padding(.trailing, 12)
        }
        .frame(height: 36)
        .background(Color.bgElevated)
        .overlay(
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        )
    }
}

private struct IconButton: View {
    let symbol: String
    @State private var hovering = false
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(hovering ? .textPrimary : .textSecondary)
            .frame(width: 26, height: 26)
            .background(hovering ? Color.white.opacity(0.04) : Color.clear)
            .cornerRadius(5)
            .onHover { hovering = $0 }
    }
}

private struct ExportButton: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 10, weight: .semibold))
            Text("Export")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.accentPrimary)
                .shadow(color: Color.accentPrimary.opacity(0.4), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Tab switcher
struct TabSwitcher: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 1) {
            ForEach(AppTab.allCases) { tab in
                TabChip(tab: tab, active: state.selectedTab == tab)
                    .onTapGesture { state.selectedTab = tab }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.bgInset)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.borderSubtle, lineWidth: 0.5)
                )
        )
    }
}

private struct TabChip: View {
    let tab: AppTab
    let active: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tab.sfSymbol)
                .font(.system(size: 10, weight: .medium))
            Text(tab.rawValue)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(active ? .textPrimary : .textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(active ? Color.bgElevated : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(active ? Color.borderStrong : Color.clear, lineWidth: 0.5)
                )
        )
        .onHover { hovering = $0 }
    }
}
