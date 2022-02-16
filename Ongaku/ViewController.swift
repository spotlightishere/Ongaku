//
//  ViewController.swift
//  Ongaku
//
//  Created by Spotlight Deveaux on 1/20/18.
//  Copyright © 2018 Spotlight Deveaux. All rights reserved.
//

import Cocoa
import Foundation
import MusicKit
import ScriptingBridge
import SwordRPC

// Adapted from
// https://gist.github.com/pvieito/3aee709b97602bfc44961df575e2b696
@objc enum iTunesEPlS: NSInteger {
    case iTunesEPlSStopped = 0x6B50_5353
    case iTunesEPlSPlaying = 0x6B50_5350
    case iTunesEPlSPaused = 0x6B50_5370
    // others omitted
}

@objc protocol iTunesTrack {
    @objc optional var album: String { get }
    @objc optional var artist: String { get }
    @objc optional var duration: CDouble { get }
    @objc optional var name: String { get }
    @objc optional var playerState: iTunesEPlS { get }
    @objc optional var storeURL: String { get }
}

@objc protocol iTunesApplication {
    @objc optional var currentTrack: iTunesTrack { get }
    @objc optional var playerPosition: CDouble { get }
}

class ViewController: NSViewController {
    // This is the Ongaku app ID.
    // You're welcome to change as you want.
    let rpc = SwordRPC(appId: "402370117901484042")

    let appName = "com.apple.Music"
    var assetName = "big_sur_logo"

    override func viewDidLoad() {
        super.viewDidLoad()

        // Callback for when RPC connects.
        rpc.onConnect { _ in
            print("Connected to Discord.")

            DispatchQueue.main.async {
                // Bye window :)
                self.view.window?.close()
            }

            // Populate information initially.
            // We cannot obtain a store URL initially.
            Task(priority: .userInitiated) {
                await self.updateEmbed(storeUrl: nil)
            }
        }

        // iTunes/Music send out a NSNotification upon various state changes.
        // We should update the embed on these events.
        DistributedNotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "\(appName).playerInfo"), object: nil, queue: nil, using: { provided in
            Task(priority: .userInitiated) {
                // We use provided only to obtain the store URL.
                let storeUrl: String? = provided.userInfo?["Store URL"] as? String ?? nil
                await self.updateEmbed(storeUrl: storeUrl)
            }
        })

        rpc.connect()
    }

    func updateEmbed(storeUrl: String?) async {
        var presence = RichPresence()

        // By default, show a lack of state.
        presence.details = "Stopped"
        presence.state = "Nothing is currently playing"
        presence.assets.largeImage = assetName
        presence.assets.largeText = "There's nothing here!"
        presence.assets.smallImage = "stop"
        presence.assets.smallText = "Currently stopped"

        let itunes: AnyObject = SBApplication(bundleIdentifier: appName)!
        let track = itunes.currentTrack
        if track != nil {
            // Something's doing something, player can't be nil.. right?
            let playerState = itunes.playerState!

            // Something's marked as playing, time to see..
            let sureTrack = track!

            presence.state = "\(sureTrack.artist!) \u{2014} \(sureTrack.album!)"
            presence.assets.largeText = "\(sureTrack.name!)"
            presence.assets.largeImage = assetName

            switch playerState {
            case .iTunesEPlSPlaying:
                presence.details = "\(sureTrack.name!)"
                presence.assets.smallImage = "play"
                presence.assets.smallText = "Playing"

                // Determine if this song is available on the iTunes Store.
                // It's okay if it is not - we default to the Music icon.
                if storeUrl != nil {
                    let artworkURL = await obtainAlbumArt(url: storeUrl!)
                    if artworkURL != nil {
                        presence.assets.largeImage = artworkURL!
                    }
                }

                // The following needs to be in milliseconds.
                let trackDuration = Double(round(sureTrack.duration!))
                let trackPosition = Double(round(itunes.playerPosition!))
                let currentTimestamp = Date()
                let trackSecondsRemaining = trackDuration - trackPosition

                let startTimestamp = currentTimestamp - trackPosition
                let endTimestamp = currentTimestamp + trackSecondsRemaining

                // Go back (position amount)
                presence.timestamps.start = Date(timeIntervalSince1970: startTimestamp.timeIntervalSince1970 * 1000)

                // Add time remaining
                presence.timestamps.end = Date(timeIntervalSince1970: endTimestamp.timeIntervalSince1970 * 1000)
            case .iTunesEPlSPaused:
                presence.details = "Paused: \(sureTrack.name!)"
                presence.assets.smallImage = "pause"
                presence.assets.smallText = "Paused"
            default:
                break
            }
        }

        rpc.setPresence(presence)
    }

    func obtainAlbumArt(url: String) async -> String? {
        let result = await MusicAuthorization.request()
        guard result == .authorized else {
            // It may be that the user denied.
            return nil
        }

        // Determine the song ID from our given itms url.
        // We expect a format similar to itmss://itunes.com/album?p=1525065667&i=1525065832.
        guard let songUrl = URLComponents(string: url) else {
            return nil
        }

        // We obtain query items and search for "i".
        guard let queryParam = songUrl.queryItems?.filter({ $0.name == "i" }).first else {
            return nil
        }
        guard let queryId = queryParam.value else {
            return nil
        }

        // Request the song for the given ID.
        var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(stringLiteral: queryId))
        request.limit = 1

        // Attempt the request.
        var response: MusicCatalogResourceResponse<Song>
        do {
            response = try await request.response()
        } catch let e {
            // Don't even bother catching the error.
            print(e)
            return nil
        }

        // Seems we could not find the song.
        if response.items.isEmpty {
            return nil
        }

        let song = response.items.first!
        let artwork = song.artwork?.url(width: 512, height: 512)
        if artwork == nil {
            return nil
        } else {
            return artwork?.absoluteString
        }
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

extension String {
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return self[range]
    }
}
