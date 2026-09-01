//
//  ReverbDelayCalculatorApp.swift
//  Space & Time
//
//  App entry point. Domain types now live in Model.swift; shared UI helpers
//  in DesignSystem.swift and Components.swift.
//

import SwiftUI

@main
struct ReverbDelayCalculatorApp: App {
    /// Shared so the main window, the macOS menu bar, and Settings all see the same list.
    @StateObject private var history = TempoHistory()

    init() {
        BrandFont.registerIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(history)
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 640)
        .windowResizability(.contentMinSize)
        #endif

        #if os(macOS)
        MenuBarExtra("Space & Time", systemImage: "metronome") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(history: history)
        }
        #endif
    }
}
