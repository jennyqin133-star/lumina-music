import SwiftUI

// MARK: - Bottom transport bar
struct TransportBar: View {
    @EnvironmentObject var state: AppState
    @State private var isPlaying = true

    var body: some View {
        HStack(spacing: 0) {
            // Left: info pairs
            HStack(spacing: 14) {
                infoPair("Time", "01:12.842")
                infoPair("BPM", "\(String(format: "%.1f", state.bpm))", color: .accentPrimary)
                infoPair("Key", state.key)
                infoPair("Bar / Beat", "14.3.2")
                infoPair("Tracks", "4 / 12")
            }
            .padding(.leading, 16)

            Spacer()

            // Center: transport
            HStack(spacing: 3) {
                transBtn("backward.end.fill")
                transBtn("backward.fill")
                ZStack {
                    Circle().fill(Color.accentPrimary)
                        .shadow(color: Color.accentPrimary.opacity(0.5), radius: 2, x: 0, y: 1)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 28, height: 28)
                transBtn("forward.fill")
                transBtn("forward.end.fill")
            }

            Spacer()

            // Right: toggles
            HStack(spacing: 6) {
                pillToggle("Loop", "repeat", on: true, color: .accentSecondary)
                pillToggle("Metronome", "metronome", on: false, color: .accentSecondary)
                pillToggle("Rec Armed", "record.circle", on: true, color: .stateDanger)
            }
            .padding(.trailing, 14)
        }
        .frame(height: 44)
        .background(Color.bgElevated)
        .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .top)
    }

    private func infoPair(_ k: String, _ v: String, color: Color = .textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k.uppercased())
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.textTertiary)
            Text(v)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
    }

    private func transBtn(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12))
            .foregroundColor(.textSecondary)
            .frame(width: 24, height: 24)
    }

    private func pillToggle(_ label: String, _ symbol: String, on: Bool, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 10))
            Text(label).font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(on ? color : .textSecondary)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(
            Capsule().fill(on ? color.opacity(0.12) : Color.bgInset)
        )
        .overlay(
            Capsule().stroke(on ? color.opacity(0.3) : Color.borderSubtle, lineWidth: 0.5)
        )
    }
}
