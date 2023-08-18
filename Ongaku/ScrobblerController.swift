//
//  ScrobblerController.swift
//  Ongaku
//
//  Created by Kot on 8/16/23.
//  Copyright © 2023 Spotlight Deveaux. All rights reserved.
//

import Alamofire
import AppKit
import Combine
import CryptoKit
import Foundation
import KeychainAccess
import os.log

private let log: Logger = .init(subsystem: "io.github.spotlightishere.Ongaku", category: "view-controller")

class ScrobblerController: ObservableObject {
    private let player: Player
    private var playerSink: AnyCancellable?
    @Published var enabled: Bool = true

    private var authToken: String?
    // How many times we've tried to create a session with the current authToken
    private var authTokenAttempts: Int = 0
    // Maximum number of authentication attempts
    private let authTokenMaxAttempts: Int = 5

    @Published var session: LastFMSession?
    private var latestScrobbledTrack: ScrobbleData?

    // What you gonna do, scrobble me to death?
    let baseUrl = URL(string: "https://ws.audioscrobbler.com/2.0")!
    let authUrl = URL(string: "https://last.fm/api/auth")!
    private let apiKey = "50ad35bfe1bb89b96f0c6e23c724dd5e"
    private let sharedSecret = "d2673496334bffaf9d5a1fac6bd29887"

    init(player: Player) {
        self.player = player
        playerSink = player.state.sink { state in
            Task(priority: .userInitiated) {
                await self.updateScrobbler(playerState: state)
            }
        }

        _ = loadSessionFromKeychain()
    }

    func updateScrobbler(playerState state: PlayerState) async {
        if session == nil && authToken != nil {
            log.debug("Attempting to authorize Last.fm session")
            await fetchAndSaveSession()
        } else {
            if !enabled {
                log.debug("Scrobbler is disabled, skipping update")
                return
            }

            switch state {
            case let .playing(active):
                let data = ScrobbleData(artist: active.track.artist ?? "Unknown Artist", track: active.track.title, album: active.track.album, duration: Int(active.track.duration))
                sendNowPlaying(data: data)

                // Don't scrobble this track if it's the latest scrobbled track
                let isLastScrobbled = data == latestScrobbledTrack
                if !isLastScrobbled {
                    if active.position > active.track.duration / 2 || active.position > 4 * 60 {
                        let ts = Date().timeIntervalSince1970 - active.position
                        sendScrobble(data: data, timestamp: Int(ts))
                    }
                } else {
                    log.debug("Not scrobbling \(data.artist) - \(data.track) as it was already scrobbled")
                }
            default: break
            }
        }
    }

    private func sendRequest(method: String, extraParams: [String: String] = [:], httpMethod: HTTPMethod) -> DataRequest {
        var params: [String: String] = [
            "method": method,
            "api_key": apiKey,
            "format": "json",
        ]

        params.merge(extraParams) { _, new in
            new
        }

        params["api_sig"] = signAPIMethod(params: params)

        var builder = URLComponents()
        builder.queryItems = params.map { param in
            URLQueryItem(name: param.key, value: param.value)
        }

        let url = builder.url(relativeTo: baseUrl)!
        let headers: HTTPHeaders = [.accept("application/json")]
        let req = AF.request(url, method: httpMethod, headers: headers)
            .validate()
            .responseData { data in
                if let statusCode = data.response?.statusCode {
                    if statusCode == 401 {
                        log.debug("Received 401 status code from Last.fm, resetting session.")
                        do {
                            try self.clearSession()
                        } catch {
                            log.info("Error clearing Last.fm session: \(error)")
                        }
                    }
                }
            }
        return req
    }

    func sendNowPlaying(data: ScrobbleData) {
        if let session {
            let key = session.key
            var dict = data.dict.compactMapValues { $0 }
            dict["sk"] = key

            sendRequest(method: "track.updateNowPlaying", extraParams: dict, httpMethod: .post).responseData { resp in
                switch resp.result {
                case .success:
                    log.debug("Sent Last.fm Now Playing for \(data.artist) - \(data.track)")
                case let .failure(error):
                    log.error("Error updating Last.fm Now Playing: \(error)")
                }
            }
        }
    }

    func sendScrobble(data: ScrobbleData, timestamp: Int) {
        if let session {
            let key = session.key
            var dict = data.dict.compactMapValues { $0 }
            dict["sk"] = key
            dict["timestamp"] = String(timestamp)

            sendRequest(method: "track.scrobble", extraParams: dict, httpMethod: .post).responseData { resp in
                switch resp.result {
                case .success:
                    log.debug("Sent Last.fm scrobble for \(data.artist) - \(data.track)")
                    self.latestScrobbledTrack = data
                case let .failure(error):
                    log.error("Error updating Last.fm scrobble: \(error)")
                }
            }
        }
    }

    private func getKeychain() -> Keychain {
        return Keychain(service: "io.github.spotlightishere.Ongaku.lastfm")
            .label("last.fm (Ongaku)")
            .accessibility(.afterFirstUnlock)
    }

    private func loadSessionFromKeychain() -> Bool {
        let keychain = getKeychain()
        let sessionKeychain = keychain["session"]
        if let sessionKeychain {
            do {
                session = try JSONDecoder().decode(LastFMSession.self, from: sessionKeychain.data(using: .utf8)!)
                if session != nil {
                    log.debug("Got Last.fm session for \(self.session!.name) from keychain")
                    return true
                }
            } catch {
                log.error("Error decoding Last.fm session from keychain: \(error)")
                session = nil
            }
        } else {
            log.debug("Last.fm session token not found on keychain.")
        }

        return false
    }

    func clearSession() throws {
        log.debug("Clearing session and removing Last.fm session from keychain.")
        session = nil
        authToken = nil
        Task {
            try getKeychain().remove("session")
        }
    }

    // Fetch and save a session, requesting user auth if necessary.
    func fetchAndSaveSession() async {
        if loadSessionFromKeychain() {
            return
        }

        // Always request user auth when we don't have a token.
        let shouldRequestAuth = authToken == nil

        if shouldRequestAuth {
            await getAuthToken()
            log.debug("Reauthorizing Last.fm.")
            requestUserAuth(token: authToken!)
            do {
                try await Task.sleep(until: .now + .seconds(5), clock: .continuous)
            } catch {}
        }

        do {
            let sessionTemp = try await fetchSession()
            DispatchQueue.main.async {
                self.session = sessionTemp

                DispatchQueue.global().async {
                    if let session = self.session {
                        do {
                            let sessionJson = try JSONEncoder().encode(session)
                            let keychain = self.getKeychain()
                            try keychain.set(String(data: sessionJson, encoding: .utf8)!, key: "session")
                            log.info("Stored Last.fm session to keychain.")
                        } catch {
                            log.error("Error storing Last.fm session to keychain: \(error)")
                        }
                    }
                }
            }
        } catch {
            log.error("Failed to fetch Last.fm session, \(self.authTokenAttempts)/\(self.authTokenMaxAttempts) attempts: \(error)")
        }
    }

    // Fetches an auth session
    private func fetchSession() async throws -> LastFMSession? {
        if let token = authToken {
            authTokenAttempts += 1

            struct Response: Codable {
                let session: LastFMSession
            }

            do {
                let req = sendRequest(method: "auth.getSession", extraParams: ["token": token], httpMethod: .get)
                let value = try await req.serializingDecodable(Response.self).value
                log.debug("Got Last.fm session for \(value.session.name).")
                return value.session
            } catch {
                if authTokenAttempts >= authTokenMaxAttempts {
                    log.info("Maximum authentication attempts reached, resetting auth token.")
                    authToken = nil
                    authTokenAttempts = 0
                }

                throw error
            }
        }

        return nil
    }

    private func getAuthToken() async {
        struct Response: Codable {
            let token: String
        }

        authToken = nil
        do {
            let req = sendRequest(method: "auth.getToken", httpMethod: .get)
            let value = try await req.serializingDecodable(Response.self).value
            authToken = value.token
        } catch {
            log.error("Failed to fetch Last.fm request token: \(error)")
        }
    }

    private func requestUserAuth(token: String) {
        var builder = URLComponents()
        builder.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "token", value: token),
        ]

        if let url = builder.url(relativeTo: authUrl) {
            NSWorkspace.shared.open(url)
        } else {
            log.error("Could not create Last.fm authentication URL.")
        }
    }

    private func signAPIMethod(params: [String: String]) -> String {
        let filtered = params.filter { param in
            param.key != "format" // Format param isn't included in the signature
        }

        let sorted = filtered.sorted(by: { a, b in
            b.key > a.key
        })

        let paramStr = sorted.reduce("") { result, item in
            result + item.key + item.value
        } + sharedSecret

        let digest = Insecure.MD5.hash(data: paramStr.data(using: .utf8)!)
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}
