//
//  ViewController.swift
//  iTunesRPC
//
//  Created by Spotlight IsHere on 1/20/18.
//  Copyright © 2018 Spotlight IsHere. All rights reserved.
//

import Cocoa
import ScriptingBridge
import SwordRPC
import Foundation

// Adapted from
// https://gist.github.com/pvieito/3aee709b97602bfc44961df575e2b696
@objc enum iTunesEPlS: NSInteger {
    case iTunesEPlSStopped = 0x6b505353
    case iTunesEPlSPlaying = 0x6b505350
    case iTunesEPlSPaused = 0x6b505370
    // others omitted
}

@objc protocol iTunesTrack {
    @objc optional var album: NSString {get}
    @objc optional var artist: NSString {get}
    @objc optional var duration: CDouble {get}
    @objc optional var name: NSString {get}
    @objc optional var playerState: iTunesEPlS {get}
}

@objc protocol iTunesApplication {
    @objc optional var currentTrack: iTunesTrack {get}
    @objc optional var playerPosition: CDouble {get}
}

class ViewController: NSViewController {
    
    // This is the iTunesRPC app ID.
    // You're welcome to change as you want.
    let rpc = SwordRPC(appId: "402370117901484042")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Callback for when RPC connects.
        rpc.onConnect { (rpc) in
            // Close window immediately.
            self.view.window?.close()
            Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(self.updateEmbed), userInfo: nil, repeats: true)
            
            var presence = RichPresence()
            presence.details = "Loading."
            presence.state = "Getting details from iTunes..."
            
            rpc.setPresence(presence)
        }
        rpc.connect()
    }
    
    func updateEmbed(sender: Any?) {
        var presence = RichPresence()
        
        let itunes: AnyObject = SBApplication(bundleIdentifier: "com.apple.iTunes")!
        let track = itunes.currentTrack
        if (track != nil) {
            // Something's doing something, player can't be nil.. right?
            let playerState = itunes.playerState!
            
            // Something's marked as playing, time to see..
            if (playerState == iTunesEPlS.iTunesEPlSPlaying) {
                let sureTrack = track!
                presence.details = "\(sureTrack.name!)"
                presence.state = "\(sureTrack.album!) - \(sureTrack.artist!)"
                
                // The following needs to be in milliseconds.
                let trackDuration = Double(round(sureTrack.duration!))
                let trackPosition = Double(round(itunes.playerPosition!))
                let currentTimestamp = Date()
                let trackRemaining = trackDuration - trackPosition
                
                // Go back (position amount)
                presence.timestamps.start = currentTimestamp - trackPosition
                // Add time remaining
                presence.timestamps.end = currentTimestamp + trackRemaining
            } else if (playerState == iTunesEPlS.iTunesEPlSPaused) {
                presence.details = "Paused."
                presence.state = "Holding your spot in the beat."
            } else if (playerState == iTunesEPlS.iTunesEPlSStopped) {
                presence.details = "iTunes is stopped."
                presence.state = "Nothing's happening."
            } else {
                presence.details = "iTunes is most likely closed."
                presence.state = "If so, please quit this app. If not, please file a bug."
            }
        } else {
            // We're in the stopped state.
            presence.details = "Nothing's playing."
            presence.state = "(why are you looking at my status anyway?)"
        }
        
        rpc.setPresence(presence)
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
}

