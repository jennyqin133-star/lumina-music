import SwiftUI
import AVFoundation

// MARK: - §9.2 Editor — full timeline / 4-track / canvas waveform / inspector
struct EditorTabView: View {
    @State private var selectedClipID: String? = "vocal-chorus"
    @State private var selectedTool: EditorTool = .selection

    var body: some View {
        HStack(spacing: 0) {
            ToolRail(selected: $selectedTool)
                .frame(width: 44)
            Divider().overlay(Color.borderSubtle)

            TrackSidebar()
                .frame(width: 224)
            Divider().overlay(Color.borderSubtle)

            Timeline(selectedClipID: $selectedClipID)
                .frame(maxWidth: .infinity)
            Divider().overlay(Color.borderSubtle)

            InspectorPane()
                .frame(width: 296)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }
}

enum EditorTool { case selection, cut, hand, undo, redo, marker, automation, snap }

// MARK: - Tool Rail
private struct ToolRail: View {
    @Binding var selected: EditorTool

    var body: some View {
        VStack(spacing: 1) {
            ToolButton(tool: .selection, symbol: "cursorarrow", key: "V", selected: selected == .selection) {
                selected = .selection
            }
            ToolButton(tool: .cut, symbol: "scissors", key: "B", selected: selected == .cut) {
                selected = .cut
            }
            ToolButton(tool: .hand, symbol: "hand.raised", key: "H", selected: selected == .hand) {
                selected = .hand
            }
            divider
            ToolButton(tool: .undo, symbol: "arrow.uturn.backward", key: nil, selected: false) {}
            ToolButton(tool: .redo, symbol: "arrow.uturn.forward", key: nil, selected: false) {}
            divider
            ToolButton(tool: .marker, symbol: "mappin", key: nil, selected: false) {}
            ToolButton(tool: .automation, symbol: "slider.horizontal.below.square.filled.and.square", key: nil, selected: false) {}
            ToolButton(tool: .snap, symbol: "square.grid.2x2", key: nil, selected: false) {}
            Spacer()
        }
        .padding(.vertical, 6)
        .frame(maxHeight: .infinity)
        .background(Color.bgElevated)
    }

    private var divider: some View {
        Rectangle().fill(Color.borderSubtle).frame(width: 20, height: 1).padding(.vertical, 4)
    }
}

private struct ToolButton: View {
    let tool: EditorTool
    let symbol: String
    let key: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundColor(selected ? .accentPrimary : .textSecondary)
                if let key {
                    Text(key)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .padding(.trailing, 3).padding(.bottom, 1)
                }
            }
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.accentPrimary.opacity(0.14) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selected ? Color.accentPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Track Sidebar (Pro DAW header rows)
private struct TrackSidebar: View {
    let tracks = TrackData.demoTracks

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tracks · \(tracks.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(.textTertiary)
                Spacer()
                Text("96kHz · 24bit")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.textQuat)
            }
            .padding(.horizontal, 10).frame(height: 24)
            .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .bottom)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(tracks) { t in
                        TrackHeaderCard(track: t)
                    }
                    AddTrackButton()
                }
                .padding(.horizontal, 6).padding(.vertical, 6)
            }
        }
        .background(Color.bgElevated)
    }
}

private struct TrackHeaderCard: View {
    let track: TrackData

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Row 1: name / meta / M S R
            HStack(spacing: 6) {
                Text(track.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(track.meta)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                MSRButton(label: "M", on: track.muted, onColor: .stateWarning)
                MSRButton(label: "S", on: track.soloed, onColor: .accentSecondary)
                MSRButton(label: "R", on: false, onColor: .stateDanger)
            }
            // Row 2: fader / pan / VU
            HStack(spacing: 6) {
                FaderBar(value: track.fader)
                PanIndicator(value: track.pan)
                VUMeter(level: track.vu)
            }
            // Row 3: FX slots
            HStack(spacing: 3) {
                ForEach(0..<track.fx.count, id: \.self) { i in
                    FXSlot(name: track.fx[i])
                }
            }
            .padding(.top, 3)
            .overlay(
                Rectangle().fill(Color.borderSubtle).frame(height: 0.5),
                alignment: .top
            )
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.bgInset)
        .overlay(
            HStack(spacing: 0) {
                Rectangle().fill(track.color).frame(width: 3)
                Rectangle().fill(Color.clear)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(track.selected ? track.color : Color.borderSubtle, lineWidth: track.selected ? 1 : 0.5)
        )
        .cornerRadius(5)
    }
}

private struct MSRButton: View {
    let label: String
    let on: Bool
    let onColor: Color
    var body: some View {
        Text(label)
            .font(.system(size: 8.5, weight: .bold))
            .tracking(0.3)
            .foregroundColor(on ? .white : .textTertiary)
            .frame(width: 18, height: 16)
            .background(
                RoundedRectangle(cornerRadius: 3).fill(on ? onColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3).stroke(on ? Color.clear : Color.borderStrong, lineWidth: 0.5)
            )
    }
}

private struct FaderBar: View {
    let value: Double   // 0..1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.bgDeep)
                Capsule().fill(
                    LinearGradient(colors: [
                        Color.accentPrimary.opacity(0.4),
                        Color.accentPrimary.opacity(0.85)
                    ], startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: geo.size.width * CGFloat(value))
                Circle().fill(Color.textPrimary)
                    .frame(width: 10, height: 10)
                    .offset(x: max(0, geo.size.width * CGFloat(value) - 5))
                    .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
                HStack {
                    Spacer()
                    Text(String(format: "%.1f dB", 20 * log10(max(value, 0.0001))))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .padding(.trailing, 4)
                }
            }
        }
        .frame(height: 14)
    }
}

private struct PanIndicator: View {
    let value: Double   // -1..1
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Color.bgDeep)
            Rectangle()
                .fill(Color.borderSubtle).frame(width: 1)
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.accentPrimary)
                    .frame(width: 2, height: geo.size.height)
                    .offset(x: geo.size.width / 2 + CGFloat(value) * (geo.size.width / 2 - 2))
            }
            Text(value == 0 ? "C" : (value < 0 ? "L\(Int(abs(value) * 50))" : "R\(Int(value * 50))"))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.textTertiary)
        }
        .frame(width: 36, height: 14)
    }
}

private struct VUMeter: View {
    let level: Double   // 0..1
    var body: some View {
        VStack(spacing: 1) {
            ForEach((0..<6).reversed(), id: \.self) { i in
                let t = Double(i + 1) / 6.0
                let lit = level >= t
                let color: Color = (t > 0.9) ? .stateDanger : (t > 0.7) ? .stateWarning : .accentSecondary
                Rectangle()
                    .fill(lit ? color : Color.bgBase.opacity(0.4))
                    .frame(height: 1.5)
            }
        }
        .padding(2)
        .frame(width: 36, height: 14)
        .background(Color.bgDeep)
        .cornerRadius(3)
    }
}

private struct FXSlot: View {
    let name: String
    var on: Bool { name != "—" }
    var body: some View {
        Text(name)
            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
            .tracking(0.3)
            .foregroundColor(on ? .accentSecondary : .textQuat)
            .frame(maxWidth: .infinity, minHeight: 14)
            .background(on ? Color.accentSecondary.opacity(0.06) : Color.bgDeep)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(on ? Color.accentSecondary.opacity(0.3) : Color.borderSubtle, lineWidth: 0.5)
            )
            .cornerRadius(3)
    }
}

private struct AddTrackButton: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "plus").font(.system(size: 10))
            Text("Add Track").font(.system(size: 11))
        }
        .foregroundColor(.textTertiary)
        .frame(maxWidth: .infinity, minHeight: 28)
        .overlay(
            RoundedRectangle(cornerRadius: 5).stroke(style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
                .foregroundColor(.borderSubtle)
        )
    }
}

// MARK: - Timeline
private struct Timeline: View {
    @Binding var selectedClipID: String?
    private let totalSec: Double = 75
    private let clips = ClipData.demoLayout

    var body: some View {
        VStack(spacing: 0) {
            Ruler(totalSec: totalSec)
            ScrollView {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 4) {
                        ForEach(TrackData.demoTracks) { t in
                            TrackLane(track: t, clips: clips.filter { $0.trackID == t.id }, totalSec: totalSec, selectedClipID: $selectedClipID)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    // Playhead at ~32% (mock state, 01:12.842 / 75s = ~ 0.32)
                    Playhead(totalSec: totalSec, t: 24.0)
                        .padding(.horizontal, 12)
                }
            }
            .background(Color.bgBase)
        }
    }
}

private struct Ruler: View {
    let totalSec: Double
    let sections: [(Double, String, Color)] = [
        (0,  "Intro",   .textTertiary),
        (8,  "Verse 1", .accentSecondary),
        (19, "Chorus",  .accentPrimary),
        (34, "Verse 2", .accentSecondary),
        (49, "Bridge",  .stateWarning),
        (60, "Chorus",  .accentPrimary)
    ]
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.bgInset
            GeometryReader { geo in
                let w = geo.size.width - 24
                let xOffset: CGFloat = 12

                // ticks
                ForEach(0...Int(totalSec / 5), id: \.self) { i in
                    let s = Double(i) * 5
                    let major = (i % 2 == 0)
                    let x = xOffset + CGFloat(s / totalSec) * w
                    Rectangle()
                        .fill(major ? Color.borderStrong : Color.textQuat)
                        .frame(width: 0.5)
                        .offset(x: x, y: major ? 6 : 14)
                        .frame(height: major ? 18 : 10)
                    if major {
                        Text(timecode(s))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(.textTertiary)
                            .offset(x: x + 3, y: 6)
                    }
                }

                // section markers (vertical color line + label)
                ForEach(0..<sections.count, id: \.self) { i in
                    let s = sections[i]
                    let x = xOffset + CGFloat(s.0 / totalSec) * w
                    Rectangle().fill(s.2).frame(width: 1)
                        .offset(x: x, y: 0)
                        .frame(height: 24)
                    Text(s.1)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(s.2)
                        .offset(x: x + 3, y: 1)
                }
            }
        }
        .frame(height: 24)
        .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .bottom)
    }

    private func timecode(_ s: Double) -> String {
        let m = Int(s) / 60
        let r = Int(s) % 60
        return "\(m):\(String(format: "%02d", r))"
    }
}

private struct TrackLane: View {
    let track: TrackData
    let clips: [ClipData]
    let totalSec: Double
    @Binding var selectedClipID: String?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.bgInset)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.borderSubtle, lineWidth: 0.5)
                    )
                    .overlay(
                        HStack(spacing: 0) {
                            Rectangle().fill(track.color).frame(width: 3)
                            Rectangle().fill(Color.clear)
                        }
                    )
                    .overlay(
                        Rectangle().fill(Color.borderSubtle.opacity(0.5))
                            .frame(height: 0.5).frame(maxHeight: .infinity, alignment: .center)
                    )
                ForEach(clips) { c in
                    let x = CGFloat(c.start / totalSec) * geo.size.width
                    let w = CGFloat(c.duration / totalSec) * geo.size.width
                    Clip(clip: c, track: track, width: w, selected: selectedClipID == c.id)
                        .offset(x: x)
                        .onTapGesture { selectedClipID = c.id }
                }
            }
        }
        .frame(height: 64)
    }
}

private struct Clip: View {
    let clip: ClipData
    let track: TrackData
    let width: CGFloat
    let selected: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // body
            RoundedRectangle(cornerRadius: Radius.clip)
                .fill(LinearGradient(
                    colors: [track.clipColor.opacity(0.95), track.clipColor.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                ))
            VStack(spacing: 0) {
                HStack {
                    Text(clip.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                    Spacer()
                    Text("\(Int(clip.duration))s")
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 5).frame(height: 12)
                .background(Color.black.opacity(0.25))
                // waveform canvas
                ClipWaveform(seed: clip.seed, density: clip.density, kind: clip.kind, color: track.waveColor)
            }
        }
        .frame(width: max(8, width), height: 60)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.clip)
                .stroke(selected ? Color.accentPrimary : Color.clear, lineWidth: 1.5)
        )
        .padding(.vertical, 2)
        .shadow(color: selected ? Color.accentPrimary.opacity(0.25) : Color.clear, radius: 3)
    }
}

private struct ClipWaveform: View {
    let seed: Double
    let density: Double
    let kind: ClipData.Kind
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let cols = max(20, Int(size.width * 0.8))
            let h = size.height
            let yMid = h / 2

            if kind == .pad {
                // smooth filled envelope
                var fill = Path()
                fill.move(to: CGPoint(x: 0, y: yMid))
                for i in 0...cols {
                    let x = CGFloat(i) / CGFloat(cols) * size.width
                    let xn = Double(i) / Double(cols)
                    let v = abs(sample(seed: seed, x: xn, density: density, kind: kind))
                    fill.addLine(to: CGPoint(x: x, y: yMid - CGFloat(v) * h * 0.42))
                }
                for i in stride(from: cols, through: 0, by: -1) {
                    let x = CGFloat(i) / CGFloat(cols) * size.width
                    let xn = Double(i) / Double(cols)
                    let v = abs(sample(seed: seed, x: xn, density: density, kind: kind))
                    fill.addLine(to: CGPoint(x: x, y: yMid + CGFloat(v) * h * 0.42))
                }
                ctx.fill(fill, with: .color(color.opacity(0.55)))
                return
            }
            // dense vertical lines (realistic)
            for i in 0..<cols {
                let x = (CGFloat(i) + 0.5) / CGFloat(cols) * size.width
                let xn = Double(i) / Double(cols)
                var maxV: Double = 0
                for k in 0..<4 {
                    let xx = (Double(i) + Double(k) * 0.25) / Double(cols)
                    let v = abs(sample(seed: seed, x: xx, density: density, kind: kind))
                    if v > maxV { maxV = v }
                }
                let half = CGFloat(min(maxV, 1.0)) * h * 0.42
                var p = Path()
                p.move(to: CGPoint(x: x, y: yMid - half))
                p.addLine(to: CGPoint(x: x, y: yMid + half))
                ctx.stroke(p, with: .color(color.opacity(0.85)), lineWidth: 0.8)
            }
        }
    }

    private func sample(seed: Double, x: Double, density: Double, kind: ClipData.Kind) -> Double {
        func pr(_ n: Double) -> Double {
            let s = sin(n * 99971.0 + seed * 13.37) * 43758.5453
            return s - floor(s)
        }
        switch kind {
        case .kit:
            let beats = floor(x * 32)
            let fract = x * 32 - beats
            if fract < 0.04 { return 0.9 * (1 - fract / 0.04) }
            if fract > 0.96 { return 0.85 * ((1 - fract) / 0.04) }
            return 0.05 + pr(beats * 7) * 0.10
        case .pad:
            return 0.3 + 0.3 * sin(x * .pi * 4 + seed) + 0.15 * sin(x * .pi * 11)
        case .vocal, .inst:
            let env = density * (0.55 + 0.35 * sin(x * .pi * 2.8 + seed))
            let detail = (pr(floor(x * 1000)) - 0.5) * 0.55
            let mid = sin(x * 200 + seed) * 0.25 * pr(floor(x * 80))
            return env + detail + mid
        }
    }
}

private struct Playhead: View {
    let totalSec: Double
    let t: Double
    var body: some View {
        GeometryReader { geo in
            let x = CGFloat(t / totalSec) * geo.size.width
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.accentPrimary).frame(width: 1)
                    .offset(x: x)
                    .shadow(color: Color.accentPrimary.opacity(0.7), radius: 3)
                Triangle()
                    .fill(Color.accentPrimary)
                    .frame(width: 9, height: 9)
                    .offset(x: x - 4, y: 0)
                Text("01:12.842")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.accentPrimary)
                    .cornerRadius(2)
                    .offset(x: x + 4, y: 4)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Inspector (right pane) — AI Bridge + Clip + Track tabs
private struct InspectorPane: View {
    @State private var insTab: InsTab = .aiBridge
    enum InsTab { case aiBridge, clip, track }

    var body: some View {
        VStack(spacing: 0) {
            // header tabs
            HStack(spacing: 0) {
                tabHeader("AI Bridge", active: insTab == .aiBridge) { insTab = .aiBridge }
                tabHeader("Clip", active: insTab == .clip) { insTab = .clip }
                tabHeader("Track", active: insTab == .track) { insTab = .track }
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 11)).foregroundColor(.textTertiary)
                    .padding(.trailing, 10)
            }
            .frame(height: 32)
            .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .bottom)

            ScrollView {
                if insTab == .aiBridge { aiBridgeContent }
                else if insTab == .clip { clipContent }
                else { trackContent }
            }

            // Footer CTA
            VStack(spacing: 6) {
                Button(action: {}) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Generate Bridge")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentPrimary))
                }
                .buttonStyle(.plain)
                Text("Cancel")
                    .font(.system(size: 11)).foregroundColor(.textTertiary)
            }
            .padding(10)
            .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .top)
        }
        .background(Color.bgElevated)
    }

    @ViewBuilder private var aiBridgeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sect("Source Analysis", trailing: AnyView(HStack(spacing: 4) {
                Circle().fill(Color.accentSecondary).frame(width: 6, height: 6)
                Text("Locked")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.3)
                    .foregroundColor(.accentSecondary)
            })) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    StatBox(value: "128.0", key: "BPM")
                    StatBox(value: "Em", key: "Key")
                    StatBox(value: "8.2s", key: "Gap")
                    StatBox(value: "Pop", key: "Style")
                }
            }

            sect("Strategy") {
                FlowChips(items: [("Soft swell", .primary), ("Drum fill", .neutral), ("Riser", .neutral), ("Ad-lib", .neutral), ("Silence", .neutral)])
            }

            sect("Parameters") {
                VStack(alignment: .leading, spacing: 4) {
                    paramRow("Length", segs: [("4s", false), ("8s", true), ("12s", false), ("Custom", false)])
                    paramRow("Vocal", segs: [("Keep", true), ("Hum", false), ("Drop", false)])
                    paramRow("Energy", segs: [("Low", false), ("Rise", true), ("Peak", false)])
                }
            }

            sect("Generation Params") {
                HStack(spacing: 6) {
                    KnobView(label: "Temp", value: "0.72", angle: -110)
                    KnobView(label: "CFG",  value: "5.0",  angle: 0)
                    KnobView(label: "Seed", value: "42",   angle: 85)
                }
            }

            sect("Prompt") {
                Text("Rising synth swell with held vocal pad — keep ")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                +
                Text("female lead")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentPrimary)
                +
                Text(" presence, no new lyrics, smooth fade into chorus.")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }

            sect("Reference") {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 11))
                    Text("Drop audio · MP3/WAV · ≤ 30s")
                        .font(.system(size: 10))
                }
                .foregroundColor(.textTertiary)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4).stroke(style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
                        .foregroundColor(.borderSubtle)
                )
                .background(Color.bgInset)
                .cornerRadius(4)
            }
        }
        .padding(12)
    }

    @ViewBuilder private var clipContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sect("Clip · Chorus") {
                Text("0:32 – 1:02 · 30.0s")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textSecondary)
            }
            sect("Gain / Fade") {
                Text("Coming Week 2 sprint.")
                    .font(.system(size: 11)).foregroundColor(.textTertiary)
            }
        }
        .padding(12)
    }

    @ViewBuilder private var trackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sect("Track · Vocal") {
                Text("Female · Bright").font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textSecondary)
            }
            sect("Routing") {
                Text("IN: Default · OUT: Master\nBus 1 · Send -inf dB")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private func sect<Content: View>(_ label: String, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                LabelText(text: label)
                Spacer()
                if let trailing { trailing }
            }
            content()
        }
    }

    private func tabHeader(_ name: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(name)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.2)
                    .foregroundColor(active ? .textPrimary : .textTertiary)
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                Rectangle()
                    .fill(active ? Color.accentPrimary : Color.clear)
                    .frame(height: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func paramRow(_ label: String, segs: [(String, Bool)]) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(.textTertiary)
                .frame(width: 50, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(0..<segs.count, id: \.self) { i in
                    let s = segs[i]
                    Text(s.0)
                        .font(.system(size: 10))
                        .foregroundColor(s.1 ? .accentPrimary : .textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 18)
                        .background(s.1 ? Color.accentPrimary.opacity(0.14) : Color.bgInset)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(s.1 ? Color.accentPrimary.opacity(0.4) : Color.borderSubtle, lineWidth: 0.5)
                        )
                        .cornerRadius(3)
                }
            }
        }
        .font(.system(size: 10.5))
    }
}

private struct KnobView: View {
    let label: String
    let value: String
    let angle: Double
    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(
                    RadialGradient(colors: [Color.bgInset, Color.bgDeep],
                                   center: UnitPoint(x: 0.5, y: 0.6),
                                   startRadius: 4, endRadius: 16)
                )
                .overlay(Circle().stroke(Color.borderSubtle, lineWidth: 0.5))
                Rectangle().fill(Color.accentPrimary)
                    .frame(width: 1.5, height: 12)
                    .offset(y: -8)
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: 36, height: 36)
            Text(label).font(.system(size: 9)).foregroundColor(.textTertiary)
            Text(value).font(.system(size: 9.5, design: .monospaced)).foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Demo data
struct TrackData: Identifiable {
    let id: String
    let name: String
    let meta: String
    let color: Color
    let clipColor: Color
    let waveColor: Color
    var fader: Double
    var pan: Double
    var vu: Double
    var fx: [String]
    var muted: Bool = false
    var soloed: Bool = false
    var selected: Bool = false

    static let demoTracks: [TrackData] = [
        TrackData(id: "vocal", name: "Vocal", meta: "Female Bright",
                  color: .trackVocal,
                  clipColor: Color(red: 0x6F/255, green: 0x50/255, blue: 0xDC/255),
                  waveColor: Color(red: 0xE2/255, green: 0xD5/255, blue: 0xFF/255),
                  fader: 0.78, pan: -0.05, vu: 0.72,
                  fx: ["Comp", "EQ", "Verb"], selected: true),
        TrackData(id: "inst", name: "Inst", meta: "Gtr · Bass",
                  color: .trackInst,
                  clipColor: Color(red: 0x2E/255, green: 0x8C/255, blue: 0x82/255),
                  waveColor: Color(red: 0xB5/255, green: 0xE8/255, blue: 0xE0/255),
                  fader: 0.62, pan: 0.15, vu: 0.55,
                  fx: ["EQ", "—", "Verb"]),
        TrackData(id: "drum", name: "Drum", meta: "Acoustic Kit",
                  color: .trackDrum,
                  clipColor: Color(red: 0xB0/255, green: 0x7E/255, blue: 0x2E/255),
                  waveColor: Color(red: 0xFF/255, green: 0xE0/255, blue: 0xB0/255),
                  fader: 0.81, pan: 0, vu: 0,
                  fx: ["Comp", "Sat", "—"], muted: true),
        TrackData(id: "synth", name: "Synth", meta: "Pad · Lead",
                  color: .trackSynth,
                  clipColor: Color(red: 0x95/255, green: 0x59/255, blue: 0xB8/255),
                  waveColor: Color(red: 0xEA/255, green: 0xC9/255, blue: 0xFF/255),
                  fader: 0.45, pan: -0.30, vu: 0.42,
                  fx: ["—", "Chor", "Verb"], soloed: true)
    ]
}

struct ClipData: Identifiable {
    enum Kind { case vocal, inst, kit, pad }
    let id: String
    let trackID: String
    let start: Double
    let duration: Double
    let label: String
    let density: Double
    let kind: Kind
    let seed: Double

    static let demoLayout: [ClipData] = [
        ClipData(id: "vocal-v1",     trackID: "vocal", start: 3,  duration: 13, label: "Verse 1 lead", density: 0.50, kind: .vocal, seed: 1),
        ClipData(id: "vocal-chorus", trackID: "vocal", start: 19, duration: 14, label: "Chorus",       density: 0.85, kind: .vocal, seed: 2),
        ClipData(id: "vocal-v2",     trackID: "vocal", start: 34, duration: 14, label: "Verse 2 lead", density: 0.55, kind: .vocal, seed: 3),
        ClipData(id: "vocal-chorus2",trackID: "vocal", start: 60, duration: 13, label: "Chorus rep",   density: 0.82, kind: .vocal, seed: 4),

        ClipData(id: "inst-1", trackID: "inst", start: 0,  duration: 33, label: "Backing — full mix", density: 0.65, kind: .inst, seed: 11),
        ClipData(id: "inst-2", trackID: "inst", start: 34, duration: 39, label: "Backing — full mix", density: 0.68, kind: .inst, seed: 12),

        ClipData(id: "drum-1", trackID: "drum", start: 8,  duration: 25, label: "Kit · 128 BPM", density: 0.95, kind: .kit, seed: 21),
        ClipData(id: "drum-2", trackID: "drum", start: 34, duration: 14, label: "Kit · 128 BPM", density: 0.95, kind: .kit, seed: 22),
        ClipData(id: "drum-3", trackID: "drum", start: 49, duration: 10, label: "Bridge fill",   density: 0.7,  kind: .kit, seed: 23),
        ClipData(id: "drum-4", trackID: "drum", start: 60, duration: 13, label: "Kit · 128 BPM", density: 0.95, kind: .kit, seed: 24),

        ClipData(id: "synth-1", trackID: "synth", start: 19, duration: 14, label: "Pad sustain",   density: 0.30, kind: .pad, seed: 31),
        ClipData(id: "synth-2", trackID: "synth", start: 41, duration: 8,  label: "AI Bridge ●",   density: 0.50, kind: .pad, seed: 32),
        ClipData(id: "synth-3", trackID: "synth", start: 49, duration: 11, label: "Bridge lead",   density: 0.55, kind: .pad, seed: 33)
    ]
}
