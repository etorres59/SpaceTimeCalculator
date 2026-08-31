# Space & Time

A small SwiftUI app that turns a tempo (BPM) into note-synced **delay and
reverb times** for every subdivision — whole notes down to 64th notes, in
straight, dotted, and triplet feels. Includes a tap-tempo helper.

## Features

- Live results as you type a BPM — no "calculate" round-trip on iPad/Mac.
- Values in **milliseconds**, **Hz** (for LFO / tremolo / filter sync), or
  **samples** at a selectable sample rate (44.1–192 kHz).
- Tap tempo with a monotonic clock, outlier rejection, ×2 / ÷2 and fine nudges.
- Tap any value to copy it; Copy All / Share the whole table as text.
- Remembers your last tempo. Adapts between iPhone (sheet) and iPad/Mac
  (side-by-side) layouts. Dark mode and Dynamic Type aware.

## The maths

```
quarter note (ms) = 60000 / BPM
note (ms)         = quarter note (ms) x beats(base) x factor(modifier)
```

where `beats` is 4 for a whole note, 1 for a quarter, ¼ for a sixteenth, and
`factor` is 1 (straight), 1.5 (dotted), or 2/3 (triplet).
`Hz = 1000 / ms`, `samples = ms / 1000 x sampleRate`.

## Build

Open `Space & TIme (V1).xcodeproj` in Xcode 15 or later and run the
`ReverbDelayCalculator` scheme.

From the command line (macOS):

```bash
xcodebuild -project "Space & TIme (V1).xcodeproj" -scheme ReverbDelayCalculator -destination 'platform=macOS' build
```

```bash
xcodebuild -project "Space & TIme (V1).xcodeproj" -scheme ReverbDelayCalculator -destination 'platform=macOS' test
```

## Project layout

| File | Purpose |
| --- | --- |
| `ReverbDelayCalculator/ReverbDelayCalculatorApp.swift` | `@main` entry point |
| `ReverbDelayCalculator/Model.swift` | `NoteDuration`, `TimeCalculator`, `TapTempoCalculator` |
| `ReverbDelayCalculator/DesignSystem.swift` | colours, font registration, clipboard |
| `ReverbDelayCalculator/Components.swift` | results list + tap-tempo sheet |
| `ReverbDelayCalculator/ContentView.swift` | adaptive top-level layout |
