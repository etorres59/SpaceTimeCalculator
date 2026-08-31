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
