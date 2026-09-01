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

    /// Producer-style fraction, e.g. "1/16".
    var fractionLabel: String {
        switch self {
        case .whole: return "1/1"
        case .half: return "1/2"
        case .quarter: return "1/4"
        case .eighth: return "1/8"
        case .sixteenth: return "1/16"
        case .thirtySecond: return "1/32"
        case .sixtyFourth: return "1/64"
        }
    }

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

    /// `grouped`, keeping only the chosen feels and note values no shorter than `shortest`.
    /// Empty sections are dropped.
    static func grouped(feels: Set<NoteModifier>,
                        shortest: NoteBase) -> [(base: NoteBase, durations: [NoteDuration])] {
        NoteBase.allCases
            .filter { $0.beats >= shortest.beats }
            .map { base in
                (base, all.filter { $0.base == base && feels.contains($0.modifier) })
            }
            .filter { !$0.durations.isEmpty }
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

    /// `bpm` shifted by `delta`, rounded to 0.1 and clamped to the valid range.
    static func nudge(_ bpm: Double, by delta: Double) -> Double {
        let shifted = ((bpm + delta) * 10).rounded() / 10
        return min(validRange.upperBound, max(validRange.lowerBound, shifted))
    }

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

    /// Plain-text table of the visible subdivisions, for Copy All / share.
    func exportText(unit: TimeUnit,
                    sampleRate: SampleRate,
                    feels: Set<NoteModifier> = Set(NoteModifier.allCases),
                    shortest: NoteBase = .sixtyFourth,
                    msDecimals: Int = 1) -> String {
        guard isValidBPM else { return "Enter a valid tempo first." }
        var lines = ["Space & Time — \(Int(bpm)) BPM (\(unit.label)\(unit == .samples ? " @ \(sampleRate.label)" : ""))"]
        for group in NoteDuration.grouped(feels: feels, shortest: shortest) {
            lines.append("")
            lines.append(group.base.sectionTitle)
            for note in group.durations {
                lines.append("  \(note.displayName): \(formatted(note, unit: unit, sampleRate: sampleRate, msDecimals: msDecimals))")
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Reverse lookup (time -> note)

/// One subdivision measured against a target time the user dialled in by ear.
struct NoteMatch: Identifiable {
    let note: NoteDuration
    /// This subdivision's length at the current tempo.
    let ms: Double
    /// `ms - target` — signed, so the sign tells you which way you're off.
    let deltaMs: Double
    /// The tempo that would make this subdivision land exactly on the target.
    let bpmForExact: Double

    var id: String { note.id }
}

extension TimeCalculator {
    /// Subdivisions closest to `targetMs` at the current tempo, nearest first.
    func matches(toMs targetMs: Double, limit: Int = 6) -> [NoteMatch] {
        guard isValidBPM, targetMs > 0 else { return [] }
        return NoteDuration.all
            .map { note in
                let ms = note.milliseconds(bpm: bpm)
                // note.ms is k / bpm for a constant k, so the exact-fit tempo scales inversely.
                let exact = ms > 0 ? bpm * ms / targetMs : 0
                return NoteMatch(note: note, ms: ms, deltaMs: ms - targetMs, bpmForExact: exact)
            }
            .sorted { abs($0.deltaMs) < abs($1.deltaMs) }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Reverb helper

/// How long the reverb tail rings, expressed in quarter-note beats so it scales with tempo.
enum ReverbDecayLength: String, CaseIterable, Identifiable {
    case oneBeat = "1 beat"
    case halfNote = "1/2 note"
    case dottedHalf = "Dotted 1/2"
    case oneBar = "1 bar"
    case barAndHalf = "1.5 bars"
    case twoBars = "2 bars"
    case threeBars = "3 bars"
    case fourBars = "4 bars"

    var id: String { rawValue }

    /// Assumes 4/4; a "bar" is 4 quarter-note beats.
    var beats: Double {
        switch self {
        case .oneBeat: return 1
        case .halfNote: return 2
        case .dottedHalf: return 3
        case .oneBar: return 4
        case .barAndHalf: return 6
        case .twoBars: return 8
        case .threeBars: return 12
        case .fourBars: return 16
        }
    }
}

/// A named reverb "space" — a sensible starting pre-delay and decay length that
/// the user can then adjust. Mirrors how producers reach for a room/plate/hall
/// and dial from there.
enum ReverbSpace: String, CaseIterable, Identifiable {
    case ambience = "Ambience"
    case room = "Room"
    case plate = "Plate"
    case hall = "Hall"
    case cathedral = "Cathedral"

    var id: String { rawValue }

    var preDelay: NoteBase {
        switch self {
        case .ambience: return .sixtyFourth
        case .room: return .thirtySecond
        case .plate: return .thirtySecond
        case .hall: return .sixteenth
        case .cathedral: return .sixteenth
        }
    }

    var decay: ReverbDecayLength {
        switch self {
        case .ambience: return .oneBeat
        case .room: return .halfNote
        case .plate: return .oneBar
        case .hall: return .twoBars
        case .cathedral: return .threeBars
        }
    }
}

/// Tempo-synced reverb suggestion: pre-delay before the tail, decay length of
/// the tail, and the total so it resolves before the next musical landmark.
final class ReverbCalculator: ObservableObject {
    /// Pre-delay is only offered for eighth-note and shorter — longer values smear the transient.
    static let preDelayChoices: [NoteBase] = NoteBase.allCases.filter { $0.beats <= 0.5 }

    @Published var space: ReverbSpace = .plate
    @Published var preDelay: NoteBase = .thirtySecond
    @Published var decay: ReverbDecayLength = .oneBar

    /// Snap pre-delay and decay to a preset; the user can still tweak afterwards.
    func apply(_ space: ReverbSpace) {
        self.space = space
        preDelay = space.preDelay
        decay = space.decay
    }

    private func quarterMs(_ bpm: Double) -> Double { bpm > 0 ? 60_000.0 / bpm : 0 }

    func preDelayMs(bpm: Double) -> Double { quarterMs(bpm) * preDelay.beats }
    func decayMs(bpm: Double) -> Double { quarterMs(bpm) * decay.beats }
    func totalMs(bpm: Double) -> Double { preDelayMs(bpm: bpm) + decayMs(bpm: bpm) }

    func exportText(bpm: Double) -> String {
        guard TimeCalculator.validRange.contains(bpm) else { return "Enter a valid tempo first." }
        return """
        Space & Time — reverb @ \(Int(bpm)) BPM (\(space.rawValue))
          Pre-delay (\(preDelay.fractionLabel)): \(String(format: "%.1f ms", preDelayMs(bpm: bpm)))
          Decay (\(decay.rawValue)): \(String(format: "%.0f ms", decayMs(bpm: bpm)))
          Total: \(String(format: "%.0f ms", totalMs(bpm: bpm)))
        """
    }
}

// MARK: - Tap tempo

/// Averages the interval between taps to estimate a tempo.
///
/// Uses a monotonic clock, a rolling window, median-based outlier rejection,
/// and auto-resets a stale sequence.
final class TapTempoCalculator: ObservableObject {
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
            return "Tap along with the tempo."
        }
        return "Keep tapping…"
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
