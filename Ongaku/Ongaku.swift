//
//  Ongaku.swift
//  Ongaku
//
//  Created by Spotlight Deveaux on 1/20/18.
//  Copyright © 2018 Spotlight Deveaux. All rights reserved.
//

import Combine
import os.log
import SwiftUI
import MacControlCenterUI

private let log: Logger = .init(subsystem: "io.github.spotlightishere.Ongaku", category: "main-app")

@main
struct Ongaku: App {
    @State var isMenuPresented: Bool = false
    let blurple: Color = Color(red: 0.34375, green: 0.39453125, blue: 0.9453125)
    let lastFmColor: Color = Color(red: 0.83203125, green: 0.06640625, blue: 0.02734375)
    
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
    @State var discord: Bool = true
    @StateObject var scrobbler: ScrobblerController

    var body: some Scene {
        // Designed to match the style of the default
        // Storyboard-based menu items.
        MenuBarExtra("Ongaku", image: "status_icon") {
            
            MacControlCenterMenu(isPresented: $isMenuPresented) {
                MenuHeader("Ongaku") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)
                        .foregroundColor(.secondary)
                }
                
                MenuSection("Presence")
                
                HStack {
                    MenuCircleToggle(
                        isOn: $discord,
                        controlSize: .prominent,
                        style: .init(
                            image: Image("discord"),
                            color: blurple
                        )
                    ) { Text("Discord") }
                    MenuCircleToggle(
                        isOn: $scrobbler.enabled,
                        controlSize: .prominent,
                        style: .init(
                            image: Image("last_fm"),
                            color: lastFmColor
                        )
                    ) { Text("Last.fm") } onClick: { toggle in
                        print(toggle)
                    }
                }
                .frame(height: 80)
                
                MenuDisclosureSection("Last.fm", initiallyExpanded: false) {
                    if let session = scrobbler.session {
                        MenuCommand {} label: {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(2)
                                Text("\(session.name)")
                                Spacer()
                            }
                        }
                        
                        MenuCommand {
                            do {
                                try scrobbler.clearSession()
                            } catch {
                                log.error("Error clearing session: \(error)")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(2)
                                Text("Logout")
                                Spacer()
                            }
                        }
                    } else {
                        MenuCommand {
                            Task(priority: .userInitiated) {
                                await scrobbler.fetchAndSaveSession()
                                scrobbler.enabled = true
                            }
                        } label: {
                            HStack {
                                Image("last_fm")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(2)
                                    .foregroundColor(lastFmColor)
                                Text("Login to Last.fm")
                                Spacer()
                            }
                        }
                    }
                }
                
                Divider()

                MenuCommand {
                    NSApplication.shared.orderFrontStandardAboutPanel()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Text("About")
                }

                Divider()

                MenuCommand("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }.menuBarExtraStyle(.window)
    }
}
