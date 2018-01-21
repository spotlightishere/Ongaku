//
//  ViewController.swift
//  AppleMusicRPC
//
//  Created by Spotlight IsHere on 1/20/18.
//  Copyright © 2018 Spotlight IsHere. All rights reserved.
//

import Cocoa
import ScriptingBridge

// Adapted from
// https://gist.github.com/pvieito/3aee709b97602bfc44961df575e2b696
@objc protocol iTunesTrack {
    @objc optional var album: NSString {get}
    @objc optional var artist: NSString {get}
    @objc optional var duration: CDouble {get}
    @objc optional var name: NSString {get}
}

@objc protocol iTunesApplication {
    @objc optional var currentTrack: iTunesTrack {get}
    @objc optional var playerPosition: CDouble {get}
}

class ViewController: NSViewController {
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // String -> NSString -> UnsafePointer<Int8> -> UnsafeMutablePointer<Int8>
        // I'm sorry.
        let appIdPointer = ("402370117901484042" as NSString).utf8String
        let appIdUnsafePointer: UnsafeMutablePointer<Int8> = UnsafeMutablePointer(mutating: appIdPointer!)
        
        // Show rich presence.
        Discord_Initialize(appIdUnsafePointer, nil, 1, nil)
        var presence : DiscordRichPresence = DiscordRichPresence()
        var details : String
        var state : String
        
        
        let itunes: AnyObject = SBApplication(bundleIdentifier: "com.apple.iTunes")!
        let track = itunes.currentTrack
        if (track != nil) {
            let sureTrack = track!
            details = "\(sureTrack.name!) - \(sureTrack.artist!)"
            state = "\(sureTrack.album!)"
            
            // The following needs to be in milliseconds.
//            let duration = Int(round(sureTrack.duration!))
//            let currentPosition = Int(round(itunes.playerPosition!))
//            let currentTimestamp = Int(NSDate().timeIntervalSince1970)
//            let current = duration - currentPosition
//            
//            presence.startTimestamp = Int64(currentTimestamp - current)
//            presence.endTimestamp = Int64(currentTimestamp + (duration - current))
        } else {
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

