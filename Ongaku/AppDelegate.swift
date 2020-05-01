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
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.image = NSImage(named: "status_icon")
        statusItem.action = #selector(quitApp)
    }

    @objc func quitApp(sender: Any?) {
        NSApplication.shared.terminate(sender)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}
