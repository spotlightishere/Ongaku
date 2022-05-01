//
//  PlayerState.swift
//  Ongaku
//
//  Created by Skip Rousseau on 4/30/22.
//  Copyright © 2022 Spotlight Deveaux. All rights reserved.
//

import Foundation

enum PlayerState {
    struct Active {
        var track: Track
        let position: TimeInterval
    }

    /// Indicates that the player was playing a track, but has been paused by
    /// the user.
    case paused(Active)

    /// Indicates that the player is actively playing a track.
    case playing(Active)

    /// Indicates that the player is not playing anything.
    case stopped
}
