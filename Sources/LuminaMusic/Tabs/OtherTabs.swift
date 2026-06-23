import SwiftUI

// MARK: - §9.3 DJ Console — dual-deck + crossfader + EQ + pads
struct DJTabView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SampleLibrary()
                    .frame(width: 200)
                Divider().overlay(Color.borderSubtle)
                Deck(label: "A", bpm: 128.0, key: "Em", time: "3:42",
                     deckColor: .accentPrimary)
                Divider().overlay(Color.borderSubtle)
                Deck(label: "B", bpm: 128.0, key: "G",  time: "4:15",
                     deckColor: .accentSecondary)
            }
            .frame(maxHeight: .infinity)

            DJBottomPanel()
                .frame(height: 220)
        }
        .background(Color.bgBase)
    }
}

// MARK: - Sample Library
private struct SampleLibrary: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Library").font(.system(size: 9, weight: .semibold)).tracking(0.6).foregroundColor(.textTertiary)
                Spacer()
                Image(systemName: "magnifyingglass").font(.system(size: 9)).foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 10).frame(height: 24)
            .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    libCategory("Current Project", items: ["Lost Highway — Chorus", "Lost Highway — Drop", "Lost Highway — Bridge"], icon: "folder.fill")
                    libCategory("Samples", items: ["808 sub", "Vocal chop FX", "Riser", "Down sweep", "Cymbal crash"], icon: "music.quarternote.3")
                    libCategory("Effects", items: ["Echo / Delay", "Reverb hall", "Filter sweep", "Flanger", "Phaser"], icon: "waveform")
                    libCategory("Loops", items: ["House 128", "Techno 124", "Trap 140"], icon: "repeat")
                }
                .padding(.vertical, 6)
            }
        }
        .background(Color.bgElevated)
    }

    @ViewBuilder private func libCategory(_ name: String, items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(.textSecondary)
                Text(name)
                    .font(.system(size: 10, weight: .semibold)).tracking(0.3)
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            VStack(spacing: 1) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill").font(.system(size: 7)).foregroundColor(.textQuat)
                        Text(item).font(.system(size: 11)).foregroundColor(.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 3)
                    .background(Color.clear)
                }
            }
        }
    }
}

// MARK: - Deck (left and right)
private struct Deck: View {
    let label: String
    let bpm: Double
    let key: String
    let time: String
    let deckColor: Color

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("DECK \(label)")
                    .font(.system(size: 11, weight: .heavy)).tracking(0.8)
                    .foregroundColor(deckColor)
                Spacer()
                Text("Lost Highway")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "ellipsis").font(.system(size: 11)).foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 14).padding(.top, 12)

            // Big waveform panel
            DeckWaveformCard(color: deckColor)
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity)

            // Info row
            HStack(spacing: 14) {
                infoCell("BPM", String(format: "%.1f", bpm), color: deckColor)
                infoCell("Key", key)
                infoCell("Time", time, color: .textPrimary)
                infoCell("Gain", "0.0 dB")
            }
            .padding(.horizontal, 14)

            // CUE / Play row
            HStack(spacing: 10) {
                cueButton()
                cueDots()
                playButton(color: deckColor)
            }
            .padding(.horizontal, 14).padding(.bottom, 8)

            // FX row
            VStack(alignment: .leading, spacing: 6) {
                Text("FX")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.6).foregroundColor(.textTertiary)
                HStack(spacing: 4) {
                    fxToggle("Echo", on: true, color: deckColor)
                    fxToggle("Reverb", on: false, color: deckColor)
                    fxToggle("Filter", on: true, color: deckColor)
                    fxToggle("Flange", on: false, color: deckColor)
                    fxToggle("Phaser", on: false, color: deckColor)
                    fxToggle("Bitcrush", on: false, color: deckColor)
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }

    private func infoCell(_ k: String, _ v: String, color: Color = .textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k.uppercased())
                .font(.system(size: 8.5, weight: .semibold)).tracking(0.5)
                .foregroundColor(.textTertiary)
            Text(v)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cueButton() -> some View {
        Text("CUE")
            .font(.system(size: 10, weight: .heavy)).tracking(1.0)
            .foregroundColor(.white)
            .frame(width: 60, height: 32)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.bgInset))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(deckColor.opacity(0.5), lineWidth: 1))
    }

    private func cueDots() -> some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(i < 3 ? deckColor : Color.borderStrong)
                    .frame(width: 8, height: 28)
                    .cornerRadius(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func playButton(color: Color) -> some View {
        ZStack {
            Circle().fill(color).shadow(color: color.opacity(0.6), radius: 3, x: 0, y: 1)
            Image(systemName: "play.fill")
                .font(.system(size: 14)).foregroundColor(.white)
        }
        .frame(width: 42, height: 42)
    }

    private func fxToggle(_ name: String, on: Bool, color: Color) -> some View {
        Text(name)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(on ? .white : .textSecondary)
            .frame(maxWidth: .infinity, minHeight: 26)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(on ? color : Color.bgInset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(on ? Color.clear : Color.borderSubtle, lineWidth: 0.5)
            )
    }
}

private struct DeckWaveformCard: View {
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color.bgDeep)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderSubtle, lineWidth: 0.5))
            Canvas { ctx, size in
                let cols = max(80, Int(size.width * 0.7))
                let yMid = size.height / 2
                let lines = 3.0
                for line in 0..<Int(lines) {
                    let baseY = yMid + CGFloat(line - 1) * size.height * 0.25
                    for i in 0..<cols {
                        let x = (CGFloat(i) + 0.5) / CGFloat(cols) * size.width
                        let xn = Double(i) / Double(cols)
                        let beats = floor(xn * 64)
                        let fract = xn * 64 - beats
                        let amp = (line == 1) ?
                            (0.4 + 0.4 * sin(xn * .pi * 8 + Double(line))) :  // sub channel
                            (fract < 0.05 ? 0.9 * (1 - fract / 0.05) : 0.1 + 0.2 * (sin(beats * 7.0) * 0.5 + 0.5))
                        let half = CGFloat(amp) * size.height * 0.12
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: baseY - half))
                        p.addLine(to: CGPoint(x: x, y: baseY + half))
                        ctx.stroke(p, with: .color(color.opacity(line == 1 ? 0.95 : 0.5)), lineWidth: 0.8)
                    }
                }
            }
            .padding(8)

            // playhead at center
            VStack(spacing: 0) {
                Rectangle().fill(color).frame(width: 1)
            }
            .shadow(color: color.opacity(0.8), radius: 3)

            // time labels
            HStack {
                Text("01:12")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .padding(.leading, 10)
                Spacer()
                Text("/  03:42")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .padding(.trailing, 10)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Bottom Panel — Crossfader + EQ + pads
private struct DJBottomPanel: View {
    var body: some View {
        HStack(spacing: 12) {
            EQColumn(label: "A", color: .accentPrimary)
                .frame(width: 130)
            VStack(spacing: 10) {
                Crossfader()
                SyncRow()
                PadGrid()
            }
            .frame(maxWidth: .infinity)
            EQColumn(label: "B", color: .accentSecondary)
                .frame(width: 130)
        }
        .padding(14)
        .background(Color.bgElevated)
        .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 0.5), alignment: .top)
    }
}

private struct EQColumn: View {
    let label: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EQ \(label)")
                .font(.system(size: 9, weight: .semibold)).tracking(0.6)
                .foregroundColor(color)
            HStack(spacing: 6) {
                eqKnob("LOW", value: 0.65, angle: -50, color: color)
                eqKnob("MID", value: 0.5, angle: 0, color: color)
                eqKnob("HI",  value: 0.8, angle: 90, color: color)
            }
            HStack(spacing: 6) {
                killBtn(color: color)
                killBtn(color: color)
                killBtn(color: color)
            }
        }
    }

    private func eqKnob(_ name: String, value: Double, angle: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(
                    RadialGradient(colors: [Color.bgInset, Color.bgDeep],
                                   center: UnitPoint(x: 0.5, y: 0.6),
                                   startRadius: 4, endRadius: 18)
                )
                .overlay(Circle().stroke(Color.borderSubtle, lineWidth: 0.5))
                Rectangle().fill(color)
                    .frame(width: 1.5, height: 13)
                    .offset(y: -9)
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: 38, height: 38)
            Text(name).font(.system(size: 8, weight: .semibold)).foregroundColor(.textTertiary)
        }
    }

    private func killBtn(color: Color) -> some View {
        Text("KILL")
            .font(.system(size: 7.5, weight: .heavy)).tracking(0.6)
            .foregroundColor(.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 16)
            .background(Color.bgInset)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.borderSubtle, lineWidth: 0.5))
            .cornerRadius(3)
    }
}

private struct Crossfader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("DECK A").font(.system(size: 9, weight: .semibold)).foregroundColor(.accentPrimary).tracking(0.4)
                Spacer()
                Text("CROSSFADER").font(.system(size: 8.5, weight: .semibold)).tracking(0.6).foregroundColor(.textTertiary)
                Spacer()
                Text("DECK B").font(.system(size: 9, weight: .semibold)).foregroundColor(.accentSecondary).tracking(0.4)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.bgDeep)
                LinearGradient(colors: [Color.accentPrimary.opacity(0.7), Color.accentSecondary.opacity(0.7)],
                               startPoint: .leading, endPoint: .trailing)
                    .mask(Capsule())
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4).fill(Color.textPrimary)
                        .frame(width: 16, height: 24)
                        .offset(x: geo.size.width * 0.42 - 8, y: -4)
                        .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
            }
            .frame(height: 16)
        }
    }
}

private struct SyncRow: View {
    var body: some View {
        HStack(spacing: 6) {
            syncBtn("BPM SYNC", on: true, icon: "link")
            syncBtn("KEY LOCK", on: false, icon: "lock")
            Text("Loop").font(.system(size: 9, weight: .semibold)).tracking(0.4).foregroundColor(.textTertiary)
            ForEach([1, 2, 4, 8, 16], id: \.self) { n in
                loopBtn("\(n)", on: n == 4)
            }
            syncBtn("AUTO MIX", on: false, icon: "cpu")
            syncBtn("REC", on: true, icon: "record.circle", color: .stateDanger)
        }
    }

    private func syncBtn(_ name: String, on: Bool, icon: String, color: Color = .accentSecondary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            Text(name).font(.system(size: 9, weight: .semibold)).tracking(0.4)
        }
        .foregroundColor(on ? color : .textSecondary)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(on ? color.opacity(0.14) : Color.bgInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(on ? color.opacity(0.3) : Color.borderSubtle, lineWidth: 0.5)
        )
    }

    private func loopBtn(_ n: String, on: Bool) -> some View {
        Text(n)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(on ? .white : .textSecondary)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 3).fill(on ? Color.accentSecondary : Color.bgInset))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(on ? Color.clear : Color.borderSubtle, lineWidth: 0.5))
    }
}

private struct PadGrid: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("SAMPLE PADS · 1–16")
                .font(.system(size: 9, weight: .semibold)).tracking(0.6)
                .foregroundColor(.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(1...8, id: \.self) { i in
                    pad(i, lit: [1, 3, 6].contains(i))
                }
            }
            HStack(spacing: 4) {
                ForEach(9...16, id: \.self) { i in
                    pad(i, lit: [11, 14].contains(i))
                }
            }
        }
    }

    private func pad(_ n: Int, lit: Bool) -> some View {
        Text("\(n)")
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundColor(lit ? .white : .textTertiary)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(lit ? Color.accentPrimary : Color.bgInset)
                    .shadow(color: lit ? Color.accentPrimary.opacity(0.6) : Color.clear, radius: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(lit ? Color.clear : Color.borderSubtle, lineWidth: 0.5)
            )
    }
}

// MARK: - §9.4 Artwork (minimal stub UI — Week 4 sprint will flesh out)
struct ArtworkTabView: View {
    var body: some View {
        HStack(spacing: 0) {
            ArtworkLeft()
                .frame(width: 360)
            Divider().overlay(Color.borderSubtle)
            ArtworkRight()
        }
        .background(Color.bgBase)
    }
}

private struct ArtworkLeft: View {
    @State private var mode: Mode = .text
    enum Mode { case auto, text, refImg, lyrics }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabelText(text: "Creation Mode")
                modePick("Auto · from style", on: mode == .auto)
                modePick("Text prompt", on: mode == .text)
                modePick("Reference image + text", on: mode == .refImg)
                modePick("Extract from lyrics", on: mode == .lyrics)

                LabelText(text: "Prompt")
                TextEditorMock(text: "赛博朋克风格的夜晚城市天际线，霓虹灯紫色调，电影感")

                LabelText(text: "Style Templates")
                let styles = ["Photography", "Illustration", "Abstract",
                              "Minimal", "Vintage", "Cyberpunk",
                              "Guofeng", "Dark", "Dreamy"]
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(styles, id: \.self) { s in
                        Text(s)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(s == "Cyberpunk" ? .accentPrimary : .textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 24)
                            .background(s == "Cyberpunk" ? Color.accentPrimary.opacity(0.12) : Color.bgInset)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(
                                s == "Cyberpunk" ? Color.accentPrimary.opacity(0.4) : Color.borderSubtle, lineWidth: 0.5))
                            .cornerRadius(4)
                    }
                }

                LabelText(text: "Text Overlay")
                HStack {
                    Image(systemName: "checkmark.square.fill").foregroundColor(.accentPrimary)
                    Text("Song title: Lost Highway")
                        .font(.system(size: 11)).foregroundColor(.textPrimary)
                }
                HStack {
                    Image(systemName: "checkmark.square.fill").foregroundColor(.accentPrimary)
                    Text("Artist: Jenny Qin")
                        .font(.system(size: 11)).foregroundColor(.textPrimary)
                }
                HStack {
                    Text("Font:").font(.system(size: 11)).foregroundColor(.textTertiary)
                    Text("Inter Bold ▾").font(.system(size: 11)).foregroundColor(.textPrimary)
                }

                Button(action: {}) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Generate Artwork")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentPrimary))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(Color.bgElevated)
    }

    private func modePick(_ name: String, on: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: on ? "largecircle.fill.circle" : "circle")
                .foregroundColor(on ? .accentPrimary : .textTertiary)
                .font(.system(size: 12))
            Text(name).font(.system(size: 11)).foregroundColor(on ? .textPrimary : .textSecondary)
        }
    }
}

private struct TextEditorMock: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
            .padding(8)
            .background(Color.bgInset)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.borderSubtle, lineWidth: 0.5))
            .cornerRadius(4)
    }
}

private struct ArtworkRight: View {
    var body: some View {
        VStack(spacing: 14) {
            // big preview
            ZStack {
                LinearGradient(colors: [
                    Color(red: 0x3A/255, green: 0x16/255, blue: 0x6B/255),
                    Color(red: 0x6E/255, green: 0x27/255, blue: 0x8C/255),
                    Color(red: 0xB8/255, green: 0x3F/255, blue: 0x9B/255)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)

                // fake city skyline silhouette
                Canvas { ctx, size in
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: size.height))
                    var x = 0.0
                    while x < size.width {
                        let h = (size.height * 0.4) + sin(x * 0.04) * 60
                        let w = Double.random(in: 30...90)
                        p.addLine(to: CGPoint(x: x, y: size.height - h))
                        p.addLine(to: CGPoint(x: x + w * 0.6, y: size.height - h))
                        x += w
                    }
                    p.addLine(to: CGPoint(x: size.width, y: size.height))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(Color.black.opacity(0.65)))

                    // window dots
                    for _ in 0..<60 {
                        let dx = CGFloat.random(in: 0...size.width)
                        let dy = CGFloat.random(in: size.height * 0.4...size.height * 0.95)
                        ctx.fill(Circle().path(in: CGRect(x: dx, y: dy, width: 1.5, height: 1.5)),
                                 with: .color(Color.accentPrimary.opacity(0.8)))
                    }
                }

                VStack(spacing: 4) {
                    Spacer()
                    Text("LOST HIGHWAY")
                        .font(.system(size: 28, weight: .heavy)).tracking(2.0)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4)
                    Text("JENNY QIN")
                        .font(.system(size: 12, weight: .semibold)).tracking(2.5)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, 30)
                }
            }
            .frame(maxWidth: 480, maxHeight: 480)
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(6)
            .padding(.top, 16)

            // resolution + variants row
            HStack(spacing: 6) {
                resPill("1K", on: false)
                resPill("2K", on: true)
                resPill("4K", on: false)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "dice").font(.system(size: 11))
                    Text("Reroll").font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.borderStrong, lineWidth: 1))
            }
            .frame(maxWidth: 480)

            // variant strip
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
                    ZStack {
                        LinearGradient(colors: [
                            Color(red: 0.2 + Double(i)*0.1, green: 0.1, blue: 0.5),
                            Color(red: 0.6, green: 0.2 + Double(i)*0.05, blue: 0.6 - Double(i)*0.1)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Text("v\(i+1)")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: 90, height: 90)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(i == 1 ? Color.accentPrimary : Color.clear, lineWidth: 1.5)
                    )
                }
                Spacer()
            }
            .frame(maxWidth: 480)

            // download row
            HStack(spacing: 8) {
                actionBtn("Download", "arrow.down.to.line", primary: true)
                actionBtn("Copy to Project", "doc.on.doc", primary: false)
                Spacer()
            }
            .frame(maxWidth: 480)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }

    private func resPill(_ s: String, on: Bool) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(on ? .accentPrimary : .textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(on ? Color.accentPrimary.opacity(0.14) : Color.bgInset)
            .overlay(Capsule().stroke(on ? Color.accentPrimary.opacity(0.4) : Color.borderSubtle, lineWidth: 0.5))
            .clipShape(Capsule())
    }

    private func actionBtn(_ name: String, _ icon: String, primary: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(name).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(primary ? .white : .textPrimary)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 5).fill(primary ? Color.accentPrimary : Color.bgElevated))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(primary ? Color.clear : Color.borderStrong, lineWidth: 1))
    }
}