//
//  Ongaku.swift
//  Ongaku
//
//  Created by Spotlight Deveaux on 1/20/18.
//  Copyright © 2018 Spotlight Deveaux. All rights reserved.
//

import SwiftUI

@main
struct Ongaku: App {
    let manager = RPCController()

    var body: some Scene {
        // Designed to match the style of the default
        // Storyboard-based menu items.
        MenuBarExtra("Ongaku", image: "status_icon") {
            Button("About Ongaku") {
                NSApplication.shared.orderFrontStandardAboutPanel()
            }

            Divider()

            Button("Quit Ongaku") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q", modifiers: [.command])
        }.menuBarExtraStyle(.menu)
    }
}
