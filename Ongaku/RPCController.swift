//
//  RPCController.swift
//  Ongaku
//
//  Created by Spotlight Deveaux on 1/20/18.
//  Copyright © 2018 Spotlight Deveaux. All rights reserved.
//

import Cocoa
import Combine
import Foundation
import os.log
import SwordRPC

private let log: Logger = .init(subsystem: "io.github.spotlightishere.Ongaku", category: "view-controller")

class RPCController: SwordRPCDelegate, ObservableObject {
    // This is the Ongaku app ID.
    // You're welcome to change as you want.
    let rpc = SwordRPC(appId: "402370117901484042")

    var assetName = "big_sur_logo"

    var player: Player
    var playerSink: AnyCancellable?
    @Published var enabled: Bool = true

    init(player: Player) {
        self.player = player
        rpc.delegate = self

        playerSink = player.state.sink { state in
            Task(priority: .userInitiated) {
                await self.updateRichPresence(playerState: state)
            }
        }

        rpc.connect()
    }

    func rpcDidConnect(_ _: SwordRPC) {
        log.notice("Connected to Discord RPC.")

        // Populate information initially.
        // We cannot obtain a store URL initially.
        Task(priority: .userInitiated) {
            await self.updateRichPresence(playerState: self.player.state.value)
        }
    }

    func updateRichPresence(playerState state: PlayerState) async {
        if !enabled { return }

        var presence = RichPresence()

        func updateActive(_ active: PlayerState.Active, paused: Bool = false) async {
            log.info("Player is active, populating rich presence state accordingly")

            let track = active.track
            presence.type = .listening
            presence.details = track.title
            presence.state = "\(track.artist ?? "Unknown") \u{2014} \(track.album ?? "Unknown")"

            presence.assets.largeImage = assetName
            presence.assets.largeText = track.title
            presence.assets.smallImage = paused ? "pause" : "play"
            presence.assets.smallText = paused ? "Paused" : "Playing"

            if track.url != nil {
                log.debug("Attempting to fetch artwork.")
                do {
                    if let artworkUrl = try await player.fetchArtwork(forTrack: track) {
                        presence.assets.largeImage = artworkUrl.absoluteString
                    }
                } catch {
                    log.error("Failed to obtain artwork for track \(String(describing: track)): \(String(describing: error))")
                }
            } else {
                log.debug("Track has no URL; not going to try to fetch artwork.")
            }

            if !paused {
                let now = Date()
                let startTimestamp = now - active.position
                let endTimestamp = now + (track.duration - active.position)

                log.debug("Claimed track duration: \(track.duration), claimed active position: \(active.position)")
                log.debug("Start timestamp: \(startTimestamp); end timestamp: \(endTimestamp)")

                // Time that the track was started
                presence.timestamps.start = Date(timeIntervalSince1970: startTimestamp.timeIntervalSince1970)

                // Time that the track ends
                presence.timestamps.end = Date(timeIntervalSince1970: endTimestamp.timeIntervalSince1970)
            }
        }

        switch state {
        case .stopped:
            presence.details = "Stopped"
            presence.state = "Nothing is currently playing"

            presence.assets.largeImage = assetName
            presence.assets.largeText = "There's nothing here!"
            presence.assets.smallImage = "stop"
            presence.assets.smallText = "Currently stopped"

        // If the player is active (i.e. has a track and position), then update
        // the rich presence accordingly.
        case let .playing(active):
            await updateActive(active, paused: false)

        case let .paused(active):
            await updateActive(active, paused: true)
        }

        log.info("Sending presence: \(String(describing: presence))")

        rpc.setPresence(presence)
    }
}

extension String {
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return self[range]
    }
}
