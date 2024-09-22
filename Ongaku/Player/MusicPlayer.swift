//
//  MusicPlayer.swift
//  Ongaku
//
//  Created by Skip Rousseau on 4/30/22.
//  Copyright © 2022 Spotlight Deveaux. All rights reserved.
//

import Combine
import Foundation
import MusicKit
import os.log
import ScriptingBridge

// Adapted from:
// https://gist.github.com/pvieito/3aee709b97602bfc44961df575e2b696

@objc enum iTunesEPlS: NSInteger {
    case iTunesEPlSStopped = 0x6B50_5353
    case iTunesEPlSPlaying = 0x6B50_5350
    case iTunesEPlSPaused = 0x6B50_5370
    // Others omitted...
}

@objc protocol iTunesTrack {
    @objc optional var album: String { get }
    @objc optional var artist: String { get }
    @objc optional var duration: CDouble { get }
    @objc optional var name: String { get }
    @objc optional var playerState: iTunesEPlS { get }
}

@objc protocol iTunesApplication {
    @objc optional var currentTrack: iTunesTrack { get }
    @objc optional var playerPosition: CDouble { get }
}

private let musicBundleId = "com.apple.Music"

enum MusicPlayerError: Error {
    case scriptingBridgeFailure
}

private var log: Logger = .init(subsystem: "io.github.spotlightishere.Ongaku", category: "music-player")

private func fetchPlayerState() throws -> PlayerState {
    guard let music: AnyObject = SBApplication(bundleIdentifier: musicBundleId),
          let playerState = music.playerState,
          let track = music.currentTrack
    else {
        throw MusicPlayerError.scriptingBridgeFailure
    }

    guard playerState != .iTunesEPlSStopped else {
        return .stopped
    }

    guard let artist = track.artist,
          let album = track.album,
          let name = track.name,
          let durationSeconds = track.duration,
          let positionSeconds = music.playerPosition
    else {
        throw MusicPlayerError.scriptingBridgeFailure
    }

    let ongakuTrack = Track(
        title: name,
        album: album,
        artist: artist,
        duration: durationSeconds
    )

    log.info("Constructed track representation: \(String(describing: ongakuTrack))")

    let active = PlayerState.Active(track: ongakuTrack, position: positionSeconds)
    return playerState == .iTunesEPlSPaused ? .paused(active) : .playing(active)
}

class MusicPlayer: Player {
    var state: CurrentValueSubject<PlayerState, Never>

    fileprivate var sink: AnyCancellable?

    init() throws {
        let name: NSNotification.Name = .init(rawValue: "\(musicBundleId).playerInfo")

        state = try CurrentValueSubject(fetchPlayerState())
        sink = DistributedNotificationCenter.default.publisher(for: name)
            .sink { [weak self] notification in
                guard let self else { return }

                guard let userInfo = notification.userInfo else {
                    // log
                    return
                }

                // Music informs us that playback has stopped as it quits.
                // If we attempt to query it via AppleScript, it will re-open.
                // If applicable, trust its notification.
                if let notificationState = userInfo["Player State"] as? String {
                    if notificationState == "Stopped" {
                        state.send(.stopped)
                        return
                    }
                }

                guard var playerState = try? fetchPlayerState() else {
                    log.error("Failed to fetch player state upon receiving a notification, not sending a new player state.")
                    return
                }

                // The store URL of the active track is apparently only
                // available in DistributedNotificationCenter notifications, so
                // we must inject the store URL here. It doesn't seem to be
                // accessible through the scripting bridge, unfortunately.
                switch playerState {
                case let .playing(active), let .paused(active):
                    let storeUrl = notification.userInfo?["Store URL"] as? String
                    log.info("Current track's store URL: \(storeUrl ?? "<unknown>")")

                    // Copy the track, modifying its URL.
                    var track = active.track
                    track.url = storeUrl

                    let newActive = PlayerState.Active(track: track, position: active.position)
                    playerState = playerState.isPlaying ? .playing(newActive) : .paused(newActive)
                default:
                    break
                }

                log.info("Sending a new player state: \(String(describing: playerState))")
                state.send(playerState)
            }
    }

    func fetchArtwork(forTrack track: Track) async throws -> URL? {
        log.info("Requested to fetch artwork for track: \(String(describing: track))")

        guard let url = track.url else {
            return nil
        }

        let result = await MusicAuthorization.request()
        guard result == .authorized else {
            // It may be that the user denied.
            return nil
        }

        // Determine the song ID from our given itms url.
        // We expect a format similar to: itmss://itunes.com/album?p=1525065667&i=1525065832.
        guard let components = URLComponents(string: url) else {
            return nil
        }

        // We obtain query items and search for "i".
        guard let queryParam = components.queryItems?.filter({ $0.name == "i" }).first,
              let queryId = queryParam.value
        else {
            return nil
        }

        // Request the song for the given ID.
        var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(stringLiteral: queryId))
        request.limit = 1

        let response: MusicCatalogResourceResponse<Song> = try await request.response()

        // Seems we could not find the song.
        if response.items.isEmpty {
            return nil
        }

        guard let song = response.items.first,
              let artwork = song.artwork?.url(width: 512, height: 512)
        else {
            return nil
        }
        return artwork
    }

    deinit {
        if let sink {
            sink.cancel()
        }
    }
}
