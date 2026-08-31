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
    init() {
        BrandFont.registerIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 640)
        .windowResizability(.contentMinSize)
        #endif
    }
}
