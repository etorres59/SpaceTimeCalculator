//
//  Model.swift
//  Space & Time
//
//  Domain model + calculators. Replaces the tuple-array / magic-index
//  approach that lived in the old ReverbDelayCalculatorApp.swift.
//

import Foundation
import Combine

// MARK: - Note values

/// A base note value, measured in quarter-note beats.
enum NoteBase: String, CaseIterable, Identifiable {
    case whole = "Whole"
    case half = "Half"
    case quarter = "Quarter"
    case eighth = "Eighth"
    case sixteenth = "Sixteenth"
    case thirtySecond = "Thirty-second"
    case sixtyFourth = "Sixty-fourth"

    var id: String { rawValue }

    /// Length in quarter-note beats (a quarter note == 1 beat).
    var beats: Double {
        switch self {
        case .whole: return 4
        case .half: return 2
        case .quarter: return 1
        case .eighth: return 1.0 / 2
        case .sixteenth: return 1.0 / 4
        case .thirtySecond: return 1.0 / 8
        case .sixtyFourth: return 1.0 / 16
        }
    }

    /// Section heading, e.g. "Quarter Notes".
    var sectionTitle: String { "\(rawValue) Notes" }
}

/// Straight / dotted / triplet feel.
enum NoteModifier: String, CaseIterable, Identifiable {
    case straight = "Straight"
    case dotted = "Dotted"
    case triplet = "Triplet"

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .straight: return 1
        case .dotted: return 1.5
        case .triplet: return 2.0 / 3.0
        }
    }
}

/// One note subdivision (base + modifier) and the maths to turn a tempo into a time.
struct NoteDuration: Identifiable {
    let base: NoteBase
    let modifier: NoteModifier

    var id: String { "\(base.rawValue)-\(modifier.rawValue)" }

    var displayName: String {
        switch modifier {
        case .straight: return "\(base.rawValue) Note"
        case .dotted: return "Dotted \(base.rawValue) Note"
        case .triplet: return "Triplet \(base.rawValue) Note"
        }
    }

    /// Milliseconds for one note of this length at `bpm`.
    func milliseconds(bpm: Double) -> Double {
        guard bpm > 0 else { return 0 }
        return (60_000.0 / bpm) * base.beats * modifier.factor
    }

    /// Frequency whose period equals this note length (useful for LFOs / tremolo / filter sync).
    func hertz(bpm: Double) -> Double {
        let ms = milliseconds(bpm: bpm)
        guard ms > 0 else { return 0 }
        return 1_000.0 / ms
    }

    /// Delay length in samples at a given sample rate.
    func samples(bpm: Double, sampleRate: Double) -> Double {
        milliseconds(bpm: bpm) / 1_000.0 * sampleRate
    }

    /// Every subdivision, ordered whole → 64th, straight → dotted → triplet.
    static let all: [NoteDuration] = NoteBase.allCases.flatMap { base in
        NoteModifier.allCases.map { NoteDuration(base: base, modifier: $0) }
    }

    /// `all`, bucketed by base value with order preserved, for the sectioned results view.
    static let grouped: [(base: NoteBase, durations: [NoteDuration])] =
        NoteBase.allCases.map { base in
            (base, all.filter { $0.base == base })
        }
}

// MARK: - Units

enum TimeUnit: String, CaseIterable, Identifiable {
    case milliseconds = "ms"
    case hertz = "Hz"
    case samples = "smp"

    var id: String { rawValue }
    var label: String { rawValue }
}

enum SampleRate: Double, CaseIterable, Identifiable {
    case sr44100 = 44_100
    case sr48000 = 48_000
    case sr88200 = 88_200
    case sr96000 = 96_000
    case sr192000 = 192_000

    var id: Double { rawValue }
    var label: String {
        let khz = rawValue / 1_000
        return khz.rounded() == khz ? "\(Int(khz)) kHz" : String(format: "%.1f kHz", khz)
    }
}

// MARK: - Tempo calculator

/// Holds the current tempo, validates it, and formats note durations for display.
final class TimeCalculator: ObservableObject {
    static let validRange: ClosedRange<Double> = 20...999

    @Published var bpm: Double

    init(bpm: Double = 120) {
        self.bpm = bpm
    }

    var isValidBPM: Bool { Self.validRange.contains(bpm) }

    var validationMessage: String? {
        isValidBPM ? nil : "Enter a tempo between \(Int(Self.validRange.lowerBound)) and \(Int(Self.validRange.upperBound)) BPM."
    }

    /// Formats a single note duration in the requested unit.
    func formatted(_ note: NoteDuration,
                   unit: TimeUnit,
                   sampleRate: SampleRate,
                   msDecimals: Int = 1) -> String {
        guard isValidBPM else { return "—" }
        switch unit {
        case .milliseconds:
            return String(format: "%.\(msDecimals)f ms", note.milliseconds(bpm: bpm))
        case .hertz:
            return String(format: "%.2f Hz", note.hertz(bpm: bpm))
        case .samples:
            return String(format: "%.0f smp", note.samples(bpm: bpm, sampleRate: sampleRate.rawValue))
        }
    }

    /// Plain-text table of every subdivision, for Copy All / share.
    func exportText(unit: TimeUnit, sampleRate: SampleRate) -> String {
        guard isValidBPM else { return "Enter a valid tempo first." }
        var lines = ["Space & Time — \(Int(bpm)) BPM (\(unit.label)\(unit == .samples ? " @ \(sampleRate.label)" : ""))"]
        for group in NoteDuration.grouped {
            lines.append("")
            lines.append(group.base.sectionTitle)
            for note in group.durations {
                lines.append("  \(note.displayName): \(formatted(note, unit: unit, sampleRate: sampleRate))")
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Tap tempo

/// Averages the interval between taps to estimate a tempo.
///
/// Uses a monotonic clock, a rolling window, median-based outlier rejection,
/// and auto-resets a stale sequence.
final class TapTempoCalculator: ObservableObject {
    /// Taps needed before a BPM is shown (== `windowSize` intervals + 1).
    static let requiredTaps = 8
    /// Longest gap between taps before the sequence is considered abandoned.
    private static let staleGap: TimeInterval = 2.0
    /// Fastest accepted tap (guards against double-triggers). ~6000 BPM.
    private static let minInterval: TimeInterval = 0.010
    private static let windowSize = 7

    @Published private(set) var calculatedBPM: Double?
    @Published private(set) var tapCount = 0

    private var lastTimestamp: TimeInterval?
    private var intervals: [TimeInterval] = []

    /// Monotonic time source, injectable for tests.
    private let now: () -> TimeInterval

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
    }

    var instructions: String {
        if let bpm = calculatedBPM {
            return "\(Int(bpm.rounded())) BPM — keep tapping to refine, or Restart."
        }
        if tapCount == 0 {
            return "Tap the button \(Self.requiredTaps) times in time."
        }
        return "Keep tapping…  \(tapCount) / \(Self.requiredTaps)"
    }

    func registerTap() {
        let t = now()
        defer { lastTimestamp = t }

        guard let last = lastTimestamp else {
            tapCount = 1
            return
        }

        let delta = t - last
        if delta > Self.staleGap {          // abandoned sequence — start over
            reset()
            lastTimestamp = t
            tapCount = 1
            return
        }
        guard delta >= Self.minInterval else { return }   // ignore accidental double-tap

        appendInterval(delta)
        tapCount += 1
        recalculate()
    }

    func reset() {
        intervals.removeAll()
        lastTimestamp = nil
        tapCount = 0
        calculatedBPM = nil
    }

    /// Manual corrections applied to the current estimate.
    func halve() { if let b = calculatedBPM { calculatedBPM = max(TimeCalculator.validRange.lowerBound, b / 2) } }
    func double() { if let b = calculatedBPM { calculatedBPM = min(TimeCalculator.validRange.upperBound, b * 2) } }
    func nudge(_ amount: Double) {
        if let b = calculatedBPM {
            calculatedBPM = min(TimeCalculator.validRange.upperBound,
                                max(TimeCalculator.validRange.lowerBound, b + amount))
        }
    }

    private func appendInterval(_ delta: TimeInterval) {
        // Reject a tap that is wildly off the established rhythm.
        if intervals.count >= 3 {
            let median = intervals.sorted()[intervals.count / 2]
            if abs(delta - median) > median * 0.4 { return }
        }
        intervals.append(delta)
        if intervals.count > Self.windowSize {
            intervals.removeFirst(intervals.count - Self.windowSize)
        }
    }

    private func recalculate() {
        guard intervals.count >= 2 else { return }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        guard average > 0 else { return }
        let bpm = 60.0 / average
        calculatedBPM = min(TimeCalculator.validRange.upperBound,
                            max(TimeCalculator.validRange.lowerBound, bpm))
    }
}
