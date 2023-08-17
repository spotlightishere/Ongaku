//
//  ScrobbleController.swift
//  Ongaku
//
//  Created by Kot on 8/16/23.
//  Copyright © 2023 Spotlight Deveaux. All rights reserved.
//

import Foundation
import Combine
import CryptoKit
import AppKit
import Alamofire
import KeychainAccess
import os.log

private let log: Logger = .init(subsystem: "io.github.spotlightishere.Ongaku", category: "view-controller")

class ScrobblerController: ObservableObject {
	private let player: Player
	private var playerSink: AnyCancellable?
	@Published var enabled: Bool = true
	
	private var authToken: String?
	@Published var session: LastFMSession?
	private var latestScrobbledTrack: ScrobbleData?
	
	// What you gonna do, scrobble me to death?
	let baseUrl = URL(string: "https://ws.audioscrobbler.com/2.0")
	let authUrl = URL(string: "https://last.fm/api/auth")
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
			case .playing(let active):
				let data = ScrobbleData(artist: active.track.artist ?? "Unknown Artist", track: active.track.title, album: active.track.album, duration: Int(active.track.duration))
				updateNowPlaying(data: data)
				
				// Don't scrobble this track if it's the latest scrobbled track
				let isLastScrobbled = data == latestScrobbledTrack
				if !isLastScrobbled {
					if (active.position > active.track.duration / 2 || active.position > 4 * 60) {
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
	
	func updateNowPlaying(data: ScrobbleData) {
		if let session {
			let key = session.key
			let durationStr = if let duration = data.duration { String(duration) } else { "" }
			
			// TODO: maybe move to ScrobbleData class? and use json post body
			let url = buildUrl(method: "track.updateNowPlaying", extraQueryItems: [
				URLQueryItem(name: "artist", value: data.artist),
				URLQueryItem(name: "track", value: data.track),
				URLQueryItem(name: "album", value: data.album),
				URLQueryItem(name: "duration", value: durationStr),
				URLQueryItem(name: "sk", value: key)
			])!
			
			// TODO: use post body for above params
			AF.request(url, method: .post, headers: [.accept("application/json")]).validate().responseData { resp in
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
			let durationStr = if let duration = data.duration { String(duration) } else { "" }
			
			let url = buildUrl(method: "track.updateNowPlaying", extraQueryItems: [
				URLQueryItem(name: "artist", value: data.artist),
				URLQueryItem(name: "track", value: data.track),
				URLQueryItem(name: "album", value: data.album),
				URLQueryItem(name: "duration", value: durationStr),
				URLQueryItem(name: "sk", value: key)
			])!
			
			// TODO: use post body for above params
			AF.request(url, method: .post, headers: [.accept("application/json")]).validate().responseData { resp in
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
	
	private func updateStatus(method: String, artist: String, track: String, album: String?, duration: TimeInterval?, timestamp: NSDate? = nil) {
		if let session {
			let key = session.key
			let durationStr = if let duration { String(Int(duration.rounded())) } else { "" }
			
			let url = buildUrl(method: method, extraQueryItems: [
				URLQueryItem(name: "artist", value: artist),
				URLQueryItem(name: "track", value: track),
				URLQueryItem(name: "album", value: album),
				URLQueryItem(name: "duration", value: durationStr),
				URLQueryItem(name: "sk", value: key)
			])!
			
			// TODO: use post body for above params
			AF.request(url, method: .post, headers: [.accept("application/json")]).validate().responseData { resp in
				switch resp.result {
				case .success:
					log.debug("Sent Last.fm Now Playing for \(artist) - \(track)")
				case let .failure(error):
					log.error("Error updating Last.fm Now Playing: \(error)")
				}
			}
		}
	}
	
	private func buildUrl(method: String, extraQueryItems: [URLQueryItem] = []) -> URL? {
		var builder = URLComponents()
		builder.queryItems = [
			URLQueryItem(name: "method", value: method),
			URLQueryItem(name: "api_key", value: apiKey),
		]
		
		builder.queryItems?.append(contentsOf: extraQueryItems)
		
		let sig = URLQueryItem(name: "api_sig", value: signAPIMethod(queryItems: builder.queryItems!))
		builder.queryItems?.append(sig)
		
		// Format isn't included in the signature, add it last
		builder.queryItems?.append(URLQueryItem(name: "format", value: "json"))
		
		return builder.url(relativeTo: baseUrl)
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
			log.error("Failed to fetch Last.fm session, retrying later: \(error)")
		}
	}
	
	private func fetchSession() async throws -> LastFMSession? {
		if let token = authToken {
			let url = buildUrl(method: "auth.getSession", extraQueryItems: [URLQueryItem(name: "token", value: token)])!
			
			struct Response: Codable {
				let session: LastFMSession
			}
			
			let value = try await AF.request(url, headers: [.accept("application/json")]).validate().serializingDecodable(Response.self).value
			log.debug("Got Last.fm session for \(value.session.name).")
			return value.session
		}
		
		return nil
	}
	
    private func getAuthToken() async {
        let url = buildUrl(method: "auth.getToken")!
        
        struct Response: Codable {
            let token: String
        }
        
        authToken = nil
        do {
            let value = try await AF.request(url, headers: [.accept("application/json")]).validate().serializingDecodable(Response.self).value
            authToken = value.token
        } catch {
            log.error("Failed to fetch Last.fm request token: \(error)")
        }
    }
	
	private func requestUserAuth(token: String) {
		var builder = URLComponents()
		builder.queryItems = [
			URLQueryItem(name: "api_key", value: apiKey),
			URLQueryItem(name: "token", value: token)
		]
		
		if let url = builder.url(relativeTo: authUrl) {
			NSWorkspace.shared.open(url)
		} else {
			log.error("Could not create Last.fm authentication URL.")
		}
	}
	
	private func signAPIMethod(queryItems: [URLQueryItem]) -> String {
		let sorted = queryItems.sorted(by: { a, b in
			return b.name > a.name
		})
		
		let params = sorted.reduce("", { result, item in
			return result + item.name + (item.value ?? "")
		}) + sharedSecret
		
		let digest = Insecure.MD5.hash(data: params.data(using: .utf8)!)
		return digest.map {
			String(format: "%02hhx", $0)
		}.joined()
	}
}

