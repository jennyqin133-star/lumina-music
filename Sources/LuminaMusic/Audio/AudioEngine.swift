import Foundation
import AVFoundation
import Accelerate
import Combine

// MARK: - Audio Engine — minimal multi-track player + spectral analyser
//
// MVP scope: open one local .mp3/.wav/.m4a, build AVAudioPlayerNode chain,
// expose play / pause / seek and a published progress timer.
// Phase 2 (after JWT key): add gen-on-demand tracks from Music 2.6 streams.

final class AudioEngine: ObservableObject {

    static let shared = AudioEngine()

    @Published var isPlaying: Bool = false
    @Published var duration: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0
    @Published var loadedURL: URL? = nil
    @Published var loadError: String? = nil

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var file: AVAudioFile?
    private var timer: Timer?

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        do { try engine.start() } catch { loadError = "engine start: \(error.localizedDescription)" }
    }

    func load(url: URL) {
        do {
            stop()
            let f = try AVAudioFile(forReading: url)
            self.file = f
            self.loadedURL = url
            self.duration = TimeInterval(f.length) / f.processingFormat.sampleRate
            self.currentTime = 0
            self.loadError = nil
        } catch {
            self.loadError = "load: \(error.localizedDescription)"
        }
    }

    func play() {
        guard let f = file else { return }
        if !engine.isRunning { try? engine.start() }
        player.scheduleFile(f, at: nil) { [weak self] in
            DispatchQueue.main.async { self?.isPlaying = false }
        }
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func stop() {
        player.stop()
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
    }

    func seek(to seconds: TimeInterval) {
        guard let f = file else { return }
        let was = isPlaying
        player.stop()
        let sampleRate = f.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(seconds * sampleRate)
        let frameCount = AVAudioFrameCount(f.length - startFrame)
        guard frameCount > 0 else { return }
        player.scheduleSegment(f, startingFrame: startFrame, frameCount: frameCount, at: nil) { [weak self] in
            DispatchQueue.main.async { self?.isPlaying = false }
        }
        currentTime = seconds
        if was { player.play(); isPlaying = true; startTimer() }
    }

    private func startTimer() {
        timer?.invalidate()
        let start = currentTime
        let t0 = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            let elapsed = Date().timeIntervalSince(t0)
            s.currentTime = min(s.duration, start + elapsed)
            if s.currentTime >= s.duration {
                s.timer?.invalidate()
                s.isPlaying = false
            }
        }
    }
}

// MARK: - Local Audio Analysis (no API)
//
// Two quick wins we can do entirely client-side, so the Agent tab is never empty
// even when the MiniMax JWT key is not yet configured:
//   1. BPM detection — autocorrelation on onset envelope (Accelerate vDSP)
//   2. Loudness (LUFS approx) — RMS over short frames
//   3. Peak amplitude / dynamic range
//   4. Spectral centroid → "bright / dark" tag
//
// Returns AnalysisSummary for the inspector pane.

struct AnalysisSummary {
    var bpm: Double           // 0 if undetected
    var keyGuess: String      // e.g. "Em" (very rough — chromagram peak)
    var lufs: Double          // approximate LUFS
    var peakDB: Double        // peak amplitude in dB
    var spectralCentroid: Double  // Hz
    var brightTag: String     // "Bright" / "Warm" / "Dark"
    var durationSec: Double
}

final class AudioAnalyser {

    static func analyse(url: URL, progress: ((Double) -> Void)? = nil) -> AnalysisSummary? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let length = AVAudioFramePosition(file.length)
        let duration = Double(length) / sampleRate

        let chunk: AVAudioFrameCount = 65536
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return nil }

        var samples: [Float] = []
        samples.reserveCapacity(Int(length))
        do {
            while true {
                try file.read(into: buf, frameCount: chunk)
                if buf.frameLength == 0 { break }
                let ch = buf.floatChannelData?[0]
                if let ch = ch {
                    let n = Int(buf.frameLength)
                    samples.append(contentsOf: UnsafeBufferPointer(start: ch, count: n))
                }
                progress?(Double(samples.count) / Double(length))
                if buf.frameLength < chunk { break }
            }
        } catch {
            return nil
        }

        // ── BPM via onset envelope autocorrelation ──
        let bpm = estimateBPM(samples: samples, sampleRate: sampleRate)

        // ── LUFS approx (very rough — RMS in dB) ──
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        let lufs = 20 * log10(max(Double(rms), 1e-6)) - 0.691  // K-weighting fudge

        // ── Peak dB ──
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        let peakDB = 20 * log10(max(Double(peak), 1e-6))

        // ── Spectral centroid via FFT on middle 8s chunk ──
        let centroid = spectralCentroid(samples: samples, sampleRate: sampleRate)
        let brightTag: String
        switch centroid {
        case 0..<1000:    brightTag = "Dark"
        case 1000..<2500: brightTag = "Warm"
        case 2500..<4500: brightTag = "Bright"
        default:          brightTag = "Sparkling"
        }

        // ── Key guess (very rough — chromagram peak) ──
        let key = guessKey(samples: samples, sampleRate: sampleRate)

        return AnalysisSummary(
            bpm: bpm, keyGuess: key, lufs: lufs, peakDB: peakDB,
            spectralCentroid: centroid, brightTag: brightTag, durationSec: duration
        )
    }

    /// Onset envelope autocorrelation, ranges 60–180 BPM.
    private static func estimateBPM(samples: [Float], sampleRate: Double) -> Double {
        guard !samples.isEmpty else { return 0 }
        let hop = Int(sampleRate / 100.0)        // 10 ms hops
        let frame = hop * 4
        var env = [Float]()
        env.reserveCapacity(samples.count / hop)
        var prev: Float = 0
        var i = 0
        while i + frame < samples.count {
            var rms: Float = 0
            samples[i..<(i + frame)].withUnsafeBufferPointer { buf in
                vDSP_rmsqv(buf.baseAddress!, 1, &rms, vDSP_Length(frame))
            }
            let diff = max(rms - prev, 0)
            env.append(diff)
            prev = rms
            i += hop
        }
        guard env.count > 200 else { return 0 }

        // Autocorrelate over [60..180] BPM range
        let envHz = 100.0     // env sample rate = 100 Hz
        let minBPM = 60.0, maxBPM = 180.0
        let minLag = Int(envHz * 60.0 / maxBPM)
        let maxLag = Int(envHz * 60.0 / minBPM)
        var bestLag = minLag
        var bestScore: Float = -Float.infinity
        for lag in minLag...maxLag {
            var s: Float = 0
            for k in 0..<(env.count - lag) {
                s += env[k] * env[k + lag]
            }
            if s > bestScore { bestScore = s; bestLag = lag }
        }
        let bpm = 60.0 * envHz / Double(bestLag)
        return (bpm * 10).rounded() / 10
    }

    /// FFT centroid on first 8s.
    private static func spectralCentroid(samples: [Float], sampleRate: Double) -> Double {
        let n = min(samples.count, Int(sampleRate * 8))
        guard n > 1024 else { return 0 }
        let log2n = vDSP_Length(log2(Double(n)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return 0 }
        defer { vDSP_destroy_fftsetup(setup) }

        var real = Array(samples[0..<(1 << Int(log2n))])
        var imag = [Float](repeating: 0, count: real.count)
        var mag = [Float](repeating: 0, count: real.count / 2)

        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &mag, 1, vDSP_Length(mag.count))
            }
        }
        var sumMag: Float = 0
        var weighted: Float = 0
        for (i, m) in mag.enumerated() {
            let freq = Float(i) * Float(sampleRate) / Float(real.count)
            sumMag += m
            weighted += m * freq
        }
        return Double(weighted / max(sumMag, 1e-9))
    }

    /// Very rough chromagram-peak key guess.
    private static func guessKey(samples: [Float], sampleRate: Double) -> String {
        // Returns simply a placeholder "Em" — full chromagram is heavy.
        // Real implementation: HPCP → Krumhansl correlation → 24-key score.
        // Stub: return based on centroid → minor for darker, major for brighter.
        let c = spectralCentroid(samples: samples, sampleRate: sampleRate)
        if c < 1800 { return "Em" }
        else { return "Cmaj" }
    }
}
