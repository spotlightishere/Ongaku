//
//  ViewController.swift
//  Ongaku
//
//  Created by Spotlight Deveaux on 1/20/18.
//  Copyright © 2018 Spotlight Deveaux. All rights reserved.
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
    // This is the Ongaku app ID.
    // You're welcome to change as you want.
    let rpc = SwordRPC(appId: "402370117901484042")
    
    // The app's named Music.
    // While com.apple.iTunes.playerInfo is sent as well,
    // it's best to update now and plan for the future.
    var appName = "com.apple.Music"
    var assetName = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(macOS 11.0, *) {
            assetName = "big_sur_logo"
        } else if #available(macOS 10.15, *){
            assetName = "music_logo"
        } else {
            appName = "com.apple.iTunes"
            assetName = "itunes_logo"
        }
        
        // Callback for when RPC connects.
        rpc.onConnect { (_) in
            print("Connected to Discord.")
            
            DispatchQueue.main.async {
                // Bye window :)
                self.view.window?.close()
            }
            
            // Populate information initially.
            self.updateEmbed()
        }
        
        // iTunes/Music send out a NSNotification upon various state changes.
        // We should update the embed on these events.
        DistributedNotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "\(self.appName).playerInfo"), object: nil, queue: nil, using: { _ in
            self.updateEmbed()
        })
        
        rpc.connect()
    }
    
    func updateEmbed() {
        var presence = RichPresence()
        
        let itunes: AnyObject = SBApplication(bundleIdentifier: appName)!
        let track = itunes.currentTrack
        if (track != nil) {
            // Something's doing something, player can't be nil.. right?
            let playerState = itunes.playerState!
            
            // Something's marked as playing, time to see..
            let sureTrack = track!
            
            // Always set image.
            presence.assets.largeImage = assetName
            
            switch (playerState) {
            case .iTunesEPlSPlaying:
                presence.details = "\(sureTrack.name!)"
                presence.state = "\(sureTrack.album!) - \(sureTrack.artist!)"
                
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
                break
            case .iTunesEPlSPaused:
                presence.details = "Paused - \(sureTrack.name!)"
                presence.state = "\(sureTrack.album!) - \(sureTrack.artist!)"
                break
            default:
                presence.details = "Stopped"
                presence.state = "Nothing is currently playing"
                break
            }
        } else {
            // We're in the stopped state.
            presence.details = "Stopped"
            presence.state = "Nothing is currently playing"
        }
        rpc.setPresence(presence)
        
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
}
