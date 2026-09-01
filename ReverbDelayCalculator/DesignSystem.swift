//
//  DesignSystem.swift
//  Space & Time
//
//  Cross-platform colour palette, font registration, and clipboard access.
//

import SwiftUI
import CoreText

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Colours

extension Color {
    /// Brand accent (headings, highlights). Hex #A63B8A.
    static let brandPink = Color(red: 166 / 255, green: 59 / 255, blue: 138 / 255)
    /// Brand secondary (secondary buttons). Hex #7A73C4 — a little deeper than the
    /// old #9992D8 so white text clears WCAG AA in both colour schemes.
    static let brandPurple = Color(red: 122 / 255, green: 115 / 255, blue: 196 / 255)

    /// Window / page background that follows light & dark mode.
    static var surface: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.white
        #endif
    }

    /// Slightly raised background for cards / result rows.
    static var surfaceSecondary: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .underPageBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
}

// MARK: - Fonts

enum BrandFont {
    static let name = "NaNHoloGigawide-Ultra"

    /// Registers the bundled display face so it also works on native macOS,
    /// where the `UIAppFonts` Info.plist key is ignored.
    static func registerIfNeeded() {
        guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// Display font that still scales with Dynamic Type via `relativeTo:`.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom(name, size: size, relativeTo: style)
    }
}

// MARK: - Appearance

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Clipboard

enum Clipboard {
    static func copy(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}
