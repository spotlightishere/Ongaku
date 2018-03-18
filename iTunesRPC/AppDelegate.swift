//
//  AppDelegate.swift
//  iTunesRPC
//
//  Created by Spotlight IsHere on 1/20/18.
//  Copyright © 2018 Spotlight IsHere. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.image = NSImage(named: NSImage.Name(rawValue: "status_icon"))
        statusItem.action = #selector(quitApp)
    }

    @objc func quitApp(sender: Any?) {
        NSApplication.shared.terminate(sender)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}
