# Universal SwiftUI utility — Xcode setup & pre-ship checklist

For a single app target that runs natively on iPhone, iPad, and Mac.

## Build settings (app target)

| Setting | Value | Why |
|---|---|---|
| `SDKROOT` | `auto` | resolve SDK per active destination |
| `SUPPORTED_PLATFORMS` | `iphoneos iphonesimulator macosx` | the platforms you ship (add `xros` only if you actually test it) |
| `TARGETED_DEVICE_FAMILY` | `1,2` | iPhone + iPad |
| `IPHONEOS_DEPLOYMENT_TARGET` | e.g. `17.0` | pick a concrete floor; iOS 17 unlocks `@Observable`, `ContentUnavailableView` |
| `MACOSX_DEPLOYMENT_TARGET` | e.g. `13.5` or `14.0` | 14.0 to match `@Observable` / `ContentUnavailableView` with iOS 17 |
| `SUPPORTS_MACCATALYST` | `NO` | native macOS; Catalyst adds iOS chrome with no upside for a simple utility |
| `PRODUCT_BUNDLE_IDENTIFIER` | one value, **identical in Debug and Release** | mismatch splits analytics, breaks upgrades, confuses `simctl`/`launch` |
| `PRODUCT_MODULE_NAME` | a clean identifier | so `@testable import CleanName` works even if the product name has spaces |
| `CODE_SIGN_ENTITLEMENTS` | path to an `.entitlements` with App Sandbox | required for Mac App Store |
| `INFOPLIST_KEY_LSApplicationCategoryType` | `public.app-category.music` | correct App Store / Launchpad category |

Test target: give it the same `SDKROOT = auto` and `SUPPORTED_PLATFORMS` so
tests run on either platform. Set `PRODUCT_MODULE_NAME` on the **app** target
(not the test target) to fix `@testable import`.

Command-line builds without a signing identity:

```
xcodebuild -project X.xcodeproj -scheme S -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Simulator device names and OS strings drift between Xcode versions — resolve a
concrete id first (`xcodebuild -scheme S -showdestinations` or
`xcrun simctl list devices available`) and pass `-destination 'id=<UDID>'`.

## Info.plist / fonts

- `UIAppFonts` registers bundled fonts on iOS only. On native macOS, register at
  launch: `CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)` from
  the `App` initialiser. Doing both is harmless.
- Drop iOS-only cruft you don't use (`UISupportsDocumentBrowser`,
  `CFBundleDocumentTypes`) — it does nothing on macOS and implies capabilities
  you don't have.
- Orientation / scene-manifest `INFOPLIST_KEY_*` entries are iOS-only and safely
  ignored on macOS.

## Scene / window (macOS)

```swift
WindowGroup { ContentView() }
    #if os(macOS)
    .defaultSize(width: 900, height: 640)
    .windowResizability(.contentMinSize)
    #endif
```

Consider `MenuBarExtra` as a second scene for a glanceable version.

## Platform-specific APIs — wrap, don't scatter

| Need | iOS | macOS |
|---|---|---|
| Clipboard | `UIPasteboard.general.string` | `NSPasteboard.general` `clearContents()` + `setString(_:forType:.string)` |
| Haptics | `UIImpactFeedbackGenerator` | none (skip) |
| Keyboard type | `.keyboardType(.decimalPad)` | not available — `#if os(iOS)` |
| Window background | `Color(uiColor: .systemBackground)` | `Color(nsColor: .windowBackgroundColor)` |

Put each behind a tiny `enum` or `View` extension with the `#if` inside it.

## Layout gotchas

- `@Environment(\.horizontalSizeClass)` is `nil` on macOS — branch on
  `== .compact`, treat `nil` as regular.
- `.presentationDetents`, `ShareLink`, `.background(_:in:)` need iOS 16 /
  macOS 13; `NavigationSplitView` behaves differently per platform — test both.

## Pre-ship checklist

- [ ] Builds clean for `platform=macOS` **and** an iOS Simulator destination.
- [ ] Unit tests pass; domain math covered; tap-tempo clock injected.
- [ ] No `inf` / `NaN` reachable in any label (try BPM = 0, empty, negative).
- [ ] Last-used values persist across relaunch (`@AppStorage`).
- [ ] iPhone: results reachable and readable in a sheet with detents.
- [ ] iPad / Mac: input + results side by side, content width-constrained.
- [ ] Dark mode: no white-on-white, no invisible text, brand colours legible.
- [ ] Dynamic Type XXL: nothing clips or truncates.
- [ ] VoiceOver: decorative images hidden; value rows read name + value + unit.
- [ ] Tap targets ≥ 44 pt.
- [ ] `.gitignore` covers `build/ DerivedData/ *.xcuserdata* .DS_Store *.app/ *.dmg`; none committed.
- [ ] One bundle id across configs; App Sandbox entitlement present; category set.
- [ ] App icon complete for all sizes; no duplicate "Icon 1.png" assets.
- [ ] At least one quick-access surface (widget / Control Center / MenuBarExtra / App Intent).
