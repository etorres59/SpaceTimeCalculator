---
name: swiftui-audio-utility
description: >-
  Professional patterns, architecture, and platform techniques for building
  SwiftUI utility apps for musicians and audio engineers — tempo / delay /
  reverb calculators, BPM and note-value converters, tuners, metronomes, gain
  and sample-rate tools, and similar single-purpose "producer tools." Use this
  whenever the task involves creating, extending, refactoring, or reviewing a
  small SwiftUI app that does audio-adjacent math and needs to run well on
  iPhone, iPad, and Mac — even if the request only mentions one platform, only
  mentions "a calculator" or "a converter," or doesn't say SwiftUI by name.
  Covers domain modelling, cross-platform project setup, adaptive layout,
  accessibility, tap-tempo, unit conversion, persistence, testing, and the
  quick-access surfaces (widgets, MenuBarExtra, App Intents) that make a utility
  feel finished.
---

# SwiftUI audio-utility apps

These apps look trivial and are easy to get 80% right and 20% wrong. The wrong
20% is always the same: a divide-by-zero that renders `inf`, fixed font sizes
that break Dynamic Type, a layout that works on an iPhone and looks abandoned on
an iPad, magic-index array code that can crash, tap tempo built on wall-clock
time, and no widget or menu-bar entry so nobody reaches for it mid-session.

This skill is the checklist and the reasoning behind it. Apply the parts that
fit; don't bolt on features the app doesn't need.

## Where to start on any task

1. **Model first, view later.** Write the calculation as plain functions on
   plain types with no SwiftUI import. If you can't unit-test the math without
   launching a view, the architecture is wrong.
2. **Decide the platforms now.** These apps should almost always be universal
   (iPhone + iPad + Mac). Set the project up for that from the first commit —
   retrofitting is the annoying path. See
   `references/xcode-multiplatform-setup.md`.
3. **Sketch both layouts.** Compact (iPhone) and regular (iPad/Mac) are
   different designs, not the same design stretched.

## Architecture

Keep three layers and don't blur them:

- **Domain** — value types and pure functions. `struct NoteDuration`, an
  `enum` of note bases with a `beats` value, a function
  `milliseconds(bpm:) -> Double`. No `import SwiftUI`, no formatting, no
  clamping to UI ranges. This is what you test.
- **Store** — a small `ObservableObject` (or `@Observable` when the deployment
  target is iOS 17 / macOS 14+) that holds live state (`bpm`, selected unit)
  and exposes validity and formatted strings. One per screen is plenty.
- **Views** — observe the store directly. Resist inventing a `ViewModel` layer
  for a screen with three controls; SwiftUI's `struct` views already are the
  view-model. Add that layer only when genuine view logic accumulates.

`@StateObject` for the object that owns a store; `@ObservedObject` or an
`@Environment` value when a child just borrows it. Passing the same store both
ways causes double-initialisation bugs.

**Make time and randomness injectable.** Anything that reads a clock takes a
`now: () -> TimeInterval = { ... }` in its initialiser. Tests pass a fake clock
and assert exact numbers instead of sleeping.

## Cross-platform without the mess

One app target, `SDKROOT = auto`, `SUPPORTED_PLATFORMS` listing
`iphoneos iphonesimulator macosx`, `TARGETED_DEVICE_FAMILY = "1,2"`. Prefer
**native macOS** over Mac Catalyst when the UI is simple forms and lists —
Catalyst brings iOS idioms and the `UIAppFonts` / font-loading quirk for no
benefit here. Details and the full checklist:
`references/xcode-multiplatform-setup.md`.

Isolate every platform-specific API behind a one-function helper so call sites
stay clean and `#if` noise lives in exactly one place:

```swift
enum Clipboard {
    static func copy(_ s: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = s
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #endif
    }
}
```

Same pattern for haptics (`UIImpactFeedbackGenerator`, iOS only), keyboard type
(`.keyboardType` is a no-op you must `#if os(iOS)` around), and colours:

- Backgrounds: `Color(uiColor: .systemBackground)` /
  `Color(nsColor: .windowBackgroundColor)` — never a hardcoded white, which
  breaks dark mode.
- Keep brand accent colours as fixed `Color(red:green:blue:)`, but use them for
  accents (headings, buttons), not full-bleed backgrounds, and verify white
  text on them clears WCAG AA (contrast ≥ 4.5:1).

**`horizontalSizeClass` can be `nil` on macOS.** Treat `== .compact` as compact
and everything else (regular *or* nil) as the wide layout.

**Bundled fonts:** the `UIAppFonts` Info.plist key is ignored on native macOS.
Register at launch so every platform gets the face:

```swift
CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
```

Always give `.custom(_:size:)` a `relativeTo:` style so the custom face still
scales with Dynamic Type, and rely on a system fallback if registration fails.

## Adaptive layout

- **Compact (iPhone):** single column. Heavy output (a 20-row table) belongs in
  a `.sheet` with `.presentationDetents([.medium, .large])`, reached by an
  explicit button.
- **Regular (iPad / Mac):** input and output side by side, output always
  visible and updating live. No sheet, often no button.
- Constrain the input column with `.frame(maxWidth: ~420)` and centre it —
  full-width text fields on a 13" iPad look broken.
- On macOS set `.defaultSize(width:height:)` and
  `.windowResizability(.contentMinSize)` on the `WindowGroup`.
- **Compute live.** Recalculate on `.onChange(of:)` of the inputs (guarded by a
  validity check). A "Calculate" button that gates a pure, instant function is
  friction; keep it only as the compact-width trigger to *present* results.

## Input and correctness

- Validate to a sensible domain range (a BPM field: ~20–999). Disable the
  action and show one quiet inline hint when out of range.
- **Guard every division.** `60000 / bpm` with `bpm == 0` yields `inf`, which
  then formats as `"inf ms"`. Return `0` or `nil` from the domain function and
  render an em dash.
- Never let `NaN` / `inf` reach a `Text`. If a formatter can produce them,
  intercept first.
- Back numeric fields with a `String` you parse, not an inline
  `NumberFormatter()` (which is re-created every render and accepts junk).
  Replace `,` with `.` before parsing so European decimals work.

## State and persistence

- `@AppStorage` for preferences and the last-used values (last BPM, last unit,
  sample rate). Users expect the tool to reopen where they left it.
- `@SceneStorage` when per-window state matters (iPad/Mac multi-window).
- Don't reset fields in `.onAppear` — views re-appear constantly (returning
  from a sheet) and it wipes user input.

## Accessibility — and it's a market differentiator

Nearly every competing producer utility fails VoiceOver and Dynamic Type. Doing
it right is cheap and reviewers notice.

- Every `.custom` font gets `relativeTo:`. Test at accessibility XXL — nothing
  should clip.
- Table rows: `.accessibilityElement(children: .combine)` with a label that
  reads the name and the value with its unit ("dotted eighth note, 375
  milliseconds"), plus `.accessibilityHint("Double tap to copy")` if tappable.
- Decorative images (logos, note glyphs): `.accessibilityHidden(true)`.
- Tap targets ≥ 44×44 pt; a tap-tempo pad should be much larger.

## Output, units, and sharing

- **Tap any value to copy it**, with a visible confirmation (swap the icon to a
  checkmark for ~1s). Add "Copy all" and a `ShareLink` that exports a plain-text
  table.
- Use `.monospacedDigit()` on numeric columns so they don't jitter.
- Decimals per unit: ms → 1, Hz → 2, samples → 0. Make it a setting if users
  ask.
- Offer the conversions the domain naturally supports. For timing tools that's
  **ms, Hz** (period → frequency, for LFO / tremolo / filter sync), and
  **samples** at a selectable sample rate (44.1 / 48 / 88.2 / 96 / 192 kHz).
  The formulas live in `references/audio-timing.md`.

## Tap tempo (and any "tap to capture a rhythm")

Get this right once and reuse it:

- **Monotonic clock only** — `ProcessInfo.processInfo.systemUptime` or
  `CACurrentMediaTime()`. `Date()` jumps when the system clock changes and
  ruins a measurement.
- Average a **rolling window** of the last ~6–8 inter-tap intervals, not all of
  them, so the estimate tracks tempo drift.
- **Reject outliers:** ignore an interval that deviates > ~40% from the running
  median of the window (fat-finger protection).
- **Auto-reset** if the gap since the last tap exceeds ~2 s — the user
  abandoned the sequence.
- Publish a tap count so the UI can show "3 / 8".
- Provide ×2 / ÷2 (half/double-time correction) and fine ±1 / ±0.1 nudges.

## Testing

- Unit-test the domain: known values (quarter @ 120 BPM = 500 ms), each
  modifier (dotted = ×1.5, triplet = ×2/3), unit conversions, and the
  validity boundaries (19/20/999/1000).
- Tap tempo: feed a fake clock a steady interval and assert the BPM within
  ±0.5; assert one injected outlier is rejected; assert the stale-gap reset.
- Assert a zero/negative input produces a finite number, never `inf`.
- Keep tests synchronous and clock-injected — no `sleep`, no flakiness.
- Verify **both** `platform=macOS` and an iOS Simulator destination build in CI.

## Quick-access surfaces (what makes it a tool, not a demo)

A calculator nobody can reach mid-session doesn't get used. Add the ones that
fit:

- **WidgetKit** home / lock-screen widget showing a couple of subdivisions for
  a saved tempo; a **Control Center** control (iOS 18+) for one-tap access.
- **`MenuBarExtra`** on macOS — a BPM field and copy buttons without leaving the
  DAW.
- **App Intents / Shortcuts / Siri** — "eighth note at 128 BPM" as an intent
  makes the app scriptable and Spotlight-visible.
- Hardware keyboard on iPad/Mac: `⌘C` to copy the focused value, arrow keys to
  nudge, space to tap tempo.

## Distribution hygiene

- `.gitignore` build products from day one: `build/`, `DerivedData/`,
  `*.xcuserdata*`, `.DS_Store`, `*.app/`, `*.dmg`. Never commit a built `.app`
  or a `.dmg`.
- One `PRODUCT_BUNDLE_IDENTIFIER` across Debug and Release. Mismatched ids
  (`com.you.App` vs `com.you.App-2`) split analytics and break upgrades.
- Add an App Sandbox `.entitlements` (no extra capabilities needed for a
  calculator) so the Mac build is App Store-eligible.
- Set `INFOPLIST_KEY_LSApplicationCategoryType` (e.g.
  `public.app-category.music`).

## Anti-patterns to flag in review

- `import SwiftUI` inside a file that only does math.
- `array[3..<6]` / `array.prefix(3)` slicing a results array by hand — model the
  groups instead so it can't go out of range.
- `Text("\(value) ms")` with no guard against `inf` / `NaN`.
- `.font(.system(size: 17))` or `.font(.custom(..., size: 20))` with no
  `relativeTo:`.
- A hardcoded `Color.white` / `Color.black` background.
- Wall-clock `Date()` in tap tempo or any interval measurement.
- `.onAppear { field = "" }`.
- Everything in one `VStack { ... Spacer() }` with no `maxWidth`, so the iPad
  build is a column of controls in a sea of grey.
- A single 400-line `ContentView.swift` holding the app entry, every subview,
  the models, and a colour palette.

## Reference files

- `references/audio-timing.md` — the timing / tempo / reverb maths: the
  `60000 / BPM` derivation, dotted and triplet factors, ms↔Hz↔samples,
  pre-delay and decay estimation, note-value tables.
- `references/xcode-multiplatform-setup.md` — exact build settings, Info.plist
  keys, font registration, and a pre-ship checklist for a universal SwiftUI
  utility.
