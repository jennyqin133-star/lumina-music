import SwiftUI

struct AgentStatusBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(state.modelConnected ? Color.accentSecondary : Color.stateDanger)
                    .frame(width: 6, height: 6)
                Text(state.modelConnected ? "Connected" : "Offline")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(state.modelConnected ? .accentSecondary : .stateDanger)
                Text("·").foregroundColor(.textQuat)
                Text(state.connectionMessage.prefix(64))
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
            .padding(.leading, 16)

            Spacer()

            if state.isComposing { statusPill("M3 streaming", color: .accentPrimary) }
            if state.isGenerating { statusPill("Music 2.6 generating", color: .accentSecondary) }
            if state.isAnalysing { statusPill("Analysing audio", color: .stateWarning) }

            HStack(spacing: 12) {
                infoPair("Messages", "\(state.conversation.messages.count)")
                infoPair("Session", state.conversation.title)
            }
            .padding(.trailing, 14)
        }
        .frame(height: 36)
        .background(Color.bgElevated)
        .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .top)
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text).font(.system(size: 10.5, weight: .medium)).foregroundColor(color)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5))
    }

    private func infoPair(_ k: String, _ v: String) -> some View {
        HStack(spacing: 4) {
            Text(k.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4).foregroundColor(.textTertiary)
            Text(v)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1).truncationMode(.middle)
        }
    }
}
