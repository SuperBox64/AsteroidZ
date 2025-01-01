//
//  AppDelegate.swift
//  AsteroidZ
//
//  Created by SuperBox64m on 12/31/24.
//


import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Make window fullscreen at launch
        NSCursor.hide()
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
            
            // Ensure window is at front and key window
            window.makeKeyAndOrderFront(nil)
            window.styleMask = .fullScreen
            // Optional: Hide menu bar in fullscreen
            //let presentation = NSApplication.shared.presentationOptions
            NSApplication.shared.presentationOptions = [.autoHideMenuBar, .fullScreen, .hideDock]
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    
}
