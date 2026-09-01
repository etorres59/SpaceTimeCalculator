//
//  ReverbDelayCalculatorTests.swift
//  Space & Time
//

import XCTest
@testable import ReverbDelayCalculator

final class NoteDurationTests: XCTestCase {

    func testQuarterNoteMilliseconds() {
        let quarter = NoteDuration(base: .quarter, modifier: .straight)
        XCTAssertEqual(quarter.milliseconds(bpm: 120), 500, accuracy: 0.0001)
        XCTAssertEqual(quarter.milliseconds(bpm: 60), 1000, accuracy: 0.0001)
    }

    func testWholeAndModifiers() {
        XCTAssertEqual(NoteDuration(base: .whole, modifier: .straight).milliseconds(bpm: 120), 2000, accuracy: 0.0001)
        XCTAssertEqual(NoteDuration(base: .quarter, modifier: .dotted).milliseconds(bpm: 120), 750, accuracy: 0.0001)
        XCTAssertEqual(NoteDuration(base: .eighth, modifier: .triplet).milliseconds(bpm: 120), 166.6667, accuracy: 0.001)
    }

    func testHertzIsInversePeriod() {
        let quarter = NoteDuration(base: .quarter, modifier: .straight)
        XCTAssertEqual(quarter.hertz(bpm: 120), 2.0, accuracy: 0.0001)   // 500 ms period
    }

    func testSamplesAtSampleRate() {
        let quarter = NoteDuration(base: .quarter, modifier: .straight)
        XCTAssertEqual(quarter.samples(bpm: 120, sampleRate: 48_000), 24_000, accuracy: 0.0001)
    }

    func testZeroBPMDoesNotProduceInfinity() {
        let quarter = NoteDuration(base: .quarter, modifier: .straight)
        XCTAssertEqual(quarter.milliseconds(bpm: 0), 0)
        XCTAssertEqual(quarter.hertz(bpm: 0), 0)
        XCTAssertFalse(quarter.milliseconds(bpm: 0).isInfinite)
    }

    func testGroupedCoversEverySubdivisionOnce() {
        XCTAssertEqual(NoteDuration.all.count, NoteBase.allCases.count * NoteModifier.allCases.count)
        XCTAssertEqual(NoteDuration.grouped.reduce(0) { $0 + $1.durations.count }, NoteDuration.all.count)
    }
}

final class TimeCalculatorTests: XCTestCase {

    func testNudgeRoundsAndClamps() {
        XCTAssertEqual(TimeCalculator.nudge(120, by: 1), 121, accuracy: 0.0001)
        XCTAssertEqual(TimeCalculator.nudge(120, by: 0.1), 120.1, accuracy: 0.0001)
        XCTAssertEqual(TimeCalculator.nudge(120.04, by: 0), 120, accuracy: 0.0001)   // rounds to 0.1
        XCTAssertEqual(TimeCalculator.nudge(995, by: 10), 999, accuracy: 0.0001)     // clamps high
        XCTAssertEqual(TimeCalculator.nudge(22, by: -10), 20, accuracy: 0.0001)      // clamps low
    }

    func testValidRangeBoundaries() {
        let calc = TimeCalculator()
        calc.bpm = 19;  XCTAssertFalse(calc.isValidBPM)
        calc.bpm = 20;  XCTAssertTrue(calc.isValidBPM)
        calc.bpm = 999; XCTAssertTrue(calc.isValidBPM)
        calc.bpm = 1000; XCTAssertFalse(calc.isValidBPM)
    }

    func testFormattedRespectsUnit() {
        let calc = TimeCalculator(bpm: 120)
        let quarter = NoteDuration(base: .quarter, modifier: .straight)
        XCTAssertEqual(calc.formatted(quarter, unit: .milliseconds, sampleRate: .sr48000), "500.0 ms")
        XCTAssertEqual(calc.formatted(quarter, unit: .hertz, sampleRate: .sr48000), "2.00 Hz")
        XCTAssertEqual(calc.formatted(quarter, unit: .samples, sampleRate: .sr48000), "24000 smp")
    }

    func testFormattedHonoursDecimalSetting() {
        let calc = TimeCalculator(bpm: 120)
        let triplet = NoteDuration(base: .eighth, modifier: .triplet)   // 166.666… ms
        XCTAssertEqual(calc.formatted(triplet, unit: .milliseconds, sampleRate: .sr48000, msDecimals: 0), "167 ms")
        XCTAssertEqual(calc.formatted(triplet, unit: .milliseconds, sampleRate: .sr48000, msDecimals: 2), "166.67 ms")
        let text = calc.exportText(unit: .milliseconds, sampleRate: .sr48000, msDecimals: 0)
        XCTAssertTrue(text.contains("Quarter Note: 500 ms"))
    }

    func testFormattedWithInvalidBPM() {
        let calc = TimeCalculator(bpm: 0)
        let quarter = NoteDuration(base: .quarter, modifier: .straight)
        XCTAssertEqual(calc.formatted(quarter, unit: .milliseconds, sampleRate: .sr48000), "—")
    }

    func testExportTextContainsHeaderAndRows() {
        let calc = TimeCalculator(bpm: 128)
        let text = calc.exportText(unit: .milliseconds, sampleRate: .sr48000)
        XCTAssertTrue(text.contains("128 BPM"))
        XCTAssertTrue(text.contains("Quarter Notes"))
        XCTAssertTrue(text.contains("Dotted Eighth Note"))
    }
}

final class SubdivisionFilterTests: XCTestCase {

    func testAllFeelsFullRangeMatchesUnfiltered() {
        let filtered = NoteDuration.grouped(feels: Set(NoteModifier.allCases), shortest: .sixtyFourth)
        XCTAssertEqual(filtered.map(\.base), NoteDuration.grouped.map(\.base))
        XCTAssertEqual(filtered.reduce(0) { $0 + $1.durations.count }, NoteDuration.all.count)
    }

    func testStraightOnlyDownToEighth() {
        let groups = NoteDuration.grouped(feels: [.straight], shortest: .eighth)
        XCTAssertEqual(groups.map(\.base), [.whole, .half, .quarter, .eighth])
        XCTAssertTrue(groups.allSatisfy { $0.durations.count == 1 && $0.durations[0].modifier == .straight })
    }

    func testDottedAndTripletDownToQuarter() {
        let groups = NoteDuration.grouped(feels: [.dotted, .triplet], shortest: .quarter)
        XCTAssertEqual(groups.map(\.base), [.whole, .half, .quarter])
        XCTAssertEqual(groups.reduce(0) { $0 + $1.durations.count }, 6)
        XCTAssertFalse(groups.flatMap(\.durations).contains { $0.modifier == .straight })
    }

    func testNoFeelsYieldsNothing() {
        XCTAssertTrue(NoteDuration.grouped(feels: [], shortest: .sixtyFourth).isEmpty)
    }

    func testExportTextHonoursFilter() {
        let text = TimeCalculator(bpm: 120).exportText(
            unit: .milliseconds, sampleRate: .sr48000, feels: [.triplet], shortest: .quarter)
        XCTAssertTrue(text.contains("Triplet Quarter Note"))
        XCTAssertFalse(text.contains("Eighth"))
        XCTAssertFalse(text.contains("Dotted"))
    }
}

final class TempoHistoryTests: XCTestCase {

    private func makeStore() -> (TempoHistory, UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (TempoHistory(defaults: defaults), defaults, suite)
    }

    override func tearDown() {
        super.tearDown()
    }

    func testRecentsDedupeCapAndOrder() {
        let (h, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        for bpm in [100.0, 110, 120, 130, 140, 150, 160, 170, 180] { h.record(bpm) }
        XCTAssertEqual(h.recents.count, TempoHistory.maxRecents)
        XCTAssertEqual(h.recents.first, 180)          // most recent first
        h.record(120)                                 // re-use an older value
        XCTAssertEqual(h.recents.first, 120)
        XCTAssertEqual(h.recents.filter { $0 == 120 }.count, 1)
    }

    func testRoundingDedupe() {
        let (h, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        h.record(120.04)
        h.record(120.0)
        XCTAssertEqual(h.recents, [120.0])
    }

    func testInvalidTempoIgnored() {
        let (h, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        h.record(0)
        h.record(5000)
        XCTAssertTrue(h.recents.isEmpty)
    }

    func testFavoriteAddIsFavoriteRemoveRename() {
        let (h, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        h.addFavorite(128, name: "Verse")
        XCTAssertTrue(h.isFavorite(128))
        XCTAssertTrue(h.isFavorite(127.98))          // rounding match
        XCTAssertEqual(h.favorites.first?.name, "Verse")
        h.addFavorite(128, name: "dup")              // no duplicate
        XCTAssertEqual(h.favorites.count, 1)
        h.rename(h.favorites[0].id, to: "Chorus")
        XCTAssertEqual(h.favorites.first?.name, "Chorus")
        h.removeFavorite(bpm: 128)
        XCTAssertFalse(h.isFavorite(128))
    }

    func testPersistenceRoundTrip() {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        do {
            let h = TempoHistory(defaults: defaults)
            h.record(140)
            h.addFavorite(90, name: "Half-time")
        }
        let reloaded = TempoHistory(defaults: defaults)
        XCTAssertEqual(reloaded.recents, [140])
        XCTAssertEqual(reloaded.favorites.first?.name, "Half-time")
    }
}

final class NoteMatchTests: XCTestCase {

    func testExactHitReportsZeroDeltaAndSameBPM() {
        let calc = TimeCalculator(bpm: 120)
        let best = calc.matches(toMs: 500).first!            // quarter note == 500 ms
        XCTAssertEqual(best.note.displayName, "Quarter Note")
        XCTAssertEqual(best.deltaMs, 0, accuracy: 0.0001)
        XCTAssertEqual(best.bpmForExact, 120, accuracy: 0.0001)
    }

    func testNearMissKeepsNearestAndSolvesForTempo() {
        let calc = TimeCalculator(bpm: 120)
        let best = calc.matches(toMs: 510).first!
        XCTAssertEqual(best.note.displayName, "Quarter Note")
        XCTAssertEqual(best.deltaMs, -10, accuracy: 0.0001)  // 500 - 510
        XCTAssertEqual(best.bpmForExact, 120.0 * 500 / 510, accuracy: 0.0001)  // ~117.6
    }

    func testDottedEighthMatch() {
        let calc = TimeCalculator(bpm: 120)
        let best = calc.matches(toMs: 375).first!
        XCTAssertEqual(best.note.displayName, "Dotted Eighth Note")
        XCTAssertEqual(best.deltaMs, 0, accuracy: 0.0001)
    }

    func testResultsAreSortedByAbsoluteDeltaAndLimited() {
        let calc = TimeCalculator(bpm: 128)
        let results = calc.matches(toMs: 300, limit: 6)
        XCTAssertEqual(results.count, 6)
        let deltas = results.map { abs($0.deltaMs) }
        XCTAssertEqual(deltas, deltas.sorted())
    }

    func testGuards() {
        XCTAssertTrue(TimeCalculator(bpm: 0).matches(toMs: 300).isEmpty)
        XCTAssertTrue(TimeCalculator(bpm: 120).matches(toMs: 0).isEmpty)
    }
}

final class ReverbCalculatorTests: XCTestCase {

    func testDefaultPlatePresetAt120() {
        let r = ReverbCalculator()          // defaults to .plate
        XCTAssertEqual(r.preDelayMs(bpm: 120), 62.5, accuracy: 0.001)   // 1/32 note
        XCTAssertEqual(r.decayMs(bpm: 120), 2000, accuracy: 0.001)      // 1 bar
        XCTAssertEqual(r.totalMs(bpm: 120), 2062.5, accuracy: 0.001)
    }

    func testApplyPresetSetsPreDelayAndDecay() {
        let r = ReverbCalculator()
        r.apply(.hall)
        XCTAssertEqual(r.space, .hall)
        XCTAssertEqual(r.preDelay, .sixteenth)
        XCTAssertEqual(r.decay, .twoBars)
        XCTAssertEqual(r.preDelayMs(bpm: 120), 125, accuracy: 0.001)
        XCTAssertEqual(r.decayMs(bpm: 120), 4000, accuracy: 0.001)
    }

    func testPreDelayChoicesAreEighthOrShorter() {
        XCTAssertEqual(ReverbCalculator.preDelayChoices,
                       [.eighth, .sixteenth, .thirtySecond, .sixtyFourth])
    }

    func testUserOverrideKeepsCustomValues() {
        let r = ReverbCalculator()
        r.apply(.room)
        r.preDelay = .sixtyFourth
        r.decay = .fourBars
        XCTAssertEqual(r.preDelayMs(bpm: 120), 500 * NoteBase.sixtyFourth.beats, accuracy: 0.001)
        XCTAssertEqual(r.decayMs(bpm: 120), 500 * ReverbDecayLength.fourBars.beats, accuracy: 0.001)
    }

    func testInvalidBPMExportGuards() {
        XCTAssertEqual(ReverbCalculator().exportText(bpm: 0), "Enter a valid tempo first.")
    }
}

final class TapTempoCalculatorTests: XCTestCase {

    /// Advances a fake clock; each `tick(_:)` moves time forward by `seconds`.
    private final class FakeClock {
        var t: TimeInterval = 1_000
        func read() -> TimeInterval { t }
        func advance(_ seconds: TimeInterval) { t += seconds }
    }

    func testSteadyTappingEstimatesTempo() {
        let clock = FakeClock()
        let tap = TapTempoCalculator(now: clock.read)
        // 120 BPM == 0.5 s between taps.
        tap.registerTap()
        for _ in 0..<7 {
            clock.advance(0.5)
            tap.registerTap()
        }
        XCTAssertNotNil(tap.calculatedBPM)
        XCTAssertEqual(tap.calculatedBPM!, 120, accuracy: 0.5)
    }

    func testOutlierTapIsRejected() {
        let clock = FakeClock()
        let tap = TapTempoCalculator(now: clock.read)
        tap.registerTap()
        for _ in 0..<5 { clock.advance(0.5); tap.registerTap() }
        let before = tap.calculatedBPM!
        clock.advance(0.9)          // a fat-fingered slow tap, within the stale window
        tap.registerTap()
        XCTAssertEqual(tap.calculatedBPM!, before, accuracy: 1.0)
    }

    func testStaleSequenceResets() {
        let clock = FakeClock()
        let tap = TapTempoCalculator(now: clock.read)
        tap.registerTap()
        clock.advance(0.5); tap.registerTap()
        clock.advance(0.5); tap.registerTap()
        XCTAssertEqual(tap.tapCount, 3)
        clock.advance(5)            // long gap → abandon
        tap.registerTap()
        XCTAssertEqual(tap.tapCount, 1)
        XCTAssertNil(tap.calculatedBPM)
    }

    func testDoubleAndHalve() {
        let clock = FakeClock()
        let tap = TapTempoCalculator(now: clock.read)
        tap.registerTap()
        for _ in 0..<7 { clock.advance(0.5); tap.registerTap() }
        let base = tap.calculatedBPM!
        tap.double()
        XCTAssertEqual(tap.calculatedBPM!, min(999, base * 2), accuracy: 0.001)
        tap.halve(); tap.halve()
        XCTAssertEqual(tap.calculatedBPM!, max(20, base / 2), accuracy: 0.001)
    }
}
