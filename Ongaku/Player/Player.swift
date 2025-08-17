//
//  Player.swift
//  Ongaku
//
//  Created by Skip Rousseau on 4/30/22.
//  Copyright © 2022 Spotlight Deveaux. All rights reserved.
//

import Combine
import Foundation

protocol Player {
    /// A Combine subject that publishes the current player state.
    var state: CurrentValueSubject<PlayerState, Never> { get }

    /// Fetches a URL to the artwork of a track.
    func fetchArtwork(forTrack track: Track) async throws -> URL?
    
    /// The URL of this track on the website.
    var webUrl: URL? { get }
    
    /// The artist's website URL.
    var artistUrl: URL? { get }
}
