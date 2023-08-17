//
//  Ongaku.swift
//  Ongaku
//
//  Created by Spotlight Deveaux on 1/20/18.
//  Copyright © 2018 Spotlight Deveaux. All rights reserved.
//

import SwiftUI
import Combine
import os.log

private let log: Logger = .init(subsystem: "io.github.spotlightishere.Ongaku", category: "main-app")

@main
struct Ongaku: App {
    init() {
        do {
            player = try MusicPlayer()
        } catch {
            log.error("Failed to construct MusicPlayer: \(error.localizedDescription)")
            fatalError("Can't start -- failed to create MusicPlayer. \(error)")
        }

        rpc = RPCController(player: player)

        let scrobbler = ScrobblerController(player: player)
        _scrobbler = StateObject(wrappedValue: scrobbler)
    }

    let player: Player
    var playerSink: AnyCancellable?
    let rpc: RPCController
    @StateObject var scrobbler: ScrobblerController

    var body: some Scene {
        // Designed to match the style of the default
        // Storyboard-based menu items.
        MenuBarExtra("Ongaku", image: "status_icon") {
            Button("About Ongaku") {
                NSApplication.shared.orderFrontStandardAboutPanel()
            }

            Divider()

            if let session = scrobbler.session {
                Text("Logged in as \(session.name)")

                Toggle(isOn: $scrobbler.enabled) {
                    if scrobbler.enabled { Text("Scrobbling") } else { Text("Not scrobbling") }
                }.keyboardShortcut("s", modifiers: [.command])

                Button("Logout") {
                    do {
                        try scrobbler.clearSession()
                    } catch {
                        log.error("Error clearing session: \(error)")
                    }
                }.keyboardShortcut("l", modifiers: [.command])
            } else {
                Button("Login to Last.fm") {
                    Task(priority: .userInitiated) {
                        await scrobbler.fetchAndSaveSession()
                        scrobbler.enabled = true
                    }
                }.keyboardShortcut("l", modifiers: [.command])
            }

            Divider()

            Button("Quit Ongaku") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q", modifiers: [.command])
        }.menuBarExtraStyle(.menu)
    }
}
