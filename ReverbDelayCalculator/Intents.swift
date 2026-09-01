//
//  Intents.swift
//  Space & Time
//
//  App Intents so "eighth note at 128 BPM" works from Shortcuts, Spotlight,
//  and Siri without opening the app.
//

import AppIntents
import Foundation

// MARK: - Enum bridges

extension NoteBase: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Note value" }
    public static var caseDisplayRepresentations: [NoteBase: DisplayRepresentation] {
        [.whole: "Whole", .half: "Half", .quarter: "Quarter", .eighth: "Eighth",
         .sixteenth: "Sixteenth", .thirtySecond: "Thirty-second", .sixtyFourth: "Sixty-fourth"]
    }
}

extension NoteModifier: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Feel" }
    public static var caseDisplayRepresentations: [NoteModifier: DisplayRepresentation] {
        [.straight: "Straight", .dotted: "Dotted", .triplet: "Triplet"]
    }
}

extension TimeUnit: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Unit" }
    public static var caseDisplayRepresentations: [TimeUnit: DisplayRepresentation] {
        [.milliseconds: "Milliseconds", .hertz: "Hertz", .samples: "Samples"]
    }
}

// MARK: - Intent

enum SpaceTimeIntentError: Error, CustomLocalizedStringResourceConvertible {
    case invalidTempo

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidTempo: return "Tempo must be between 20 and 999 BPM."
        }
    }
}

struct NoteDelayIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Note Delay Time"
    static var description = IntentDescription(
        "Delay, LFO, or sample time for a note value at a given tempo.")

    @Parameter(title: "Tempo (BPM)", inclusiveRange: (20, 999))
    var bpm: Double

    @Parameter(title: "Note", default: .quarter)
    var note: NoteBase

    @Parameter(title: "Feel", default: .straight)
    var feel: NoteModifier

    @Parameter(title: "Unit", default: .milliseconds)
    var unit: TimeUnit

    @Parameter(title: "Sample rate", default: 48_000)
    var sampleRate: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Time for a \(\.$feel) \(\.$note) note at \(\.$bpm) BPM in \(\.$unit)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        guard (20.0...999.0).contains(bpm) else { throw SpaceTimeIntentError.invalidTempo }

        let duration = NoteDuration(base: note, modifier: feel)
        let value: Double
        let spoken: String
        switch unit {
        case .milliseconds:
            value = duration.milliseconds(bpm: bpm)
            spoken = String(format: "%.1f milliseconds", value)
        case .hertz:
            value = duration.hertz(bpm: bpm)
            spoken = String(format: "%.2f hertz", value)
        case .samples:
            value = duration.samples(bpm: bpm, sampleRate: Double(sampleRate))
            spoken = String(format: "%.0f samples", value)
        }
        return .result(value: value,
                       dialog: "\(duration.displayName) at \(Int(bpm)) BPM is \(spoken).")
    }
}

struct SpaceTimeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NoteDelayIntent(),
            phrases: [
                "Get a delay time in \(.applicationName)",
                "\(.applicationName) note time",
            ],
            shortTitle: "Get Note Delay Time",
            systemImageName: "metronome")
    }
}
