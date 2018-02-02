//
//  ViewController.swift
//  iTunesRPC
//
//  Created by Spotlight IsHere on 1/20/18.
//  Copyright © 2018 Spotlight IsHere. All rights reserved.
//

import Cocoa
import ScriptingBridge

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
    
    var presence : DiscordRichPresence = DiscordRichPresence()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // String -> NSString -> UnsafePointer<Int8> -> UnsafeMutablePointer<Int8>
        // I'm sorry.
        let appIdPointer = ("402370117901484042" as NSString).utf8String
        let appIdUnsafePointer: UnsafeMutablePointer<Int8> = UnsafeMutablePointer(mutating: appIdPointer!)
        
        // Show rich presence.
        Discord_Initialize(appIdUnsafePointer, nil, 1, nil)
        Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(updateEmbed), userInfo: nil, repeats: true)
    }
    
    func updateEmbed(sender: Any?) {
        var details : String
        var state : String
        presence.startTimestamp = 0
        presence.endTimestamp = 0
        
        
        let itunes: AnyObject = SBApplication(bundleIdentifier: "com.apple.iTunes")!
        let track = itunes.currentTrack
        if (track != nil) {
            // Something's doing something, player can't be nil.. right?
            let playerState = itunes.playerState!
            
            // Something's marked as playing, time to see..
            if (playerState == iTunesEPlS.iTunesEPlSPlaying) {
                let sureTrack = track!
                details = "\(sureTrack.name!)"
                state = "\(sureTrack.album!) - \(sureTrack.artist!)"
                
                // The following needs to be in milliseconds.
                let trackDuration = Double(round(sureTrack.duration!))
                let trackPosition = Double(round(itunes.playerPosition!))
                let currentTimestamp = Double(NSDate().timeIntervalSince1970)
                let trackRemaining = trackDuration - trackPosition
                
                // Go back (position amount)
                presence.startTimestamp = Int64(Double(currentTimestamp - trackPosition))
                // Add time remaining
                presence.endTimestamp = Int64(Double(currentTimestamp + trackRemaining))
            } else if (playerState == iTunesEPlS.iTunesEPlSPaused) {
                details = "Paused."
                state = "Holding your spot in the beat."
            } else {
                details = "Something unknown happened."
                state = "Maybe iTunes got some new playing states? :/"
            }
        } else {
            // We're in the stopped state.
            details = "Nothing's playing."
            state = "(why are you looking at my status anyway?)"
        }
        
        
        presence.details = (details as NSString).utf8String
        presence.state = (state as NSString).utf8String
        
        Discord_UpdatePresence(&presence)
        Discord_RunCallbacks()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
}

