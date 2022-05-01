//
//  Track.swift
//  Ongaku
//
//  Created by Skip Rousseau on 4/30/22.
//  Copyright © 2022 Spotlight Deveaux. All rights reserved.
//

import Foundation

struct Track {
    /// The title of the track.
    let title: String

    /// The name of the album the track is contained within.
    let album: String?

    /// The name of the artist of the track.
    let artist: String?

    /// The duration of the track in seconds.
    let duration: TimeInterval

    /// The URL of this track.
    var url: String?
}
