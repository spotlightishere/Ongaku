//
//  AppDelegate.swift
//  Ongaku
//
//  Created by Spotlight Deveaux on 1/20/18.
//  Copyright © 2018 Spotlight Deveaux. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var menu: NSMenu?
    @IBOutlet weak var firstMenuItem: NSMenuItem?
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.image = NSImage(named: "status_icon")
        if let menu = menu {
            statusItem.menu = menu
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}
