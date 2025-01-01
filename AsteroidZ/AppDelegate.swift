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
        NSApp.presentationOptions = [.autoHideMenuBar, .fullScreen, .hideDock]
        if let window = NSApplication.shared.windows.first {
            // Ensure window is at front and key window
            window.toggleFullScreen(nil)
            window.makeKeyAndOrderFront(nil)
            window.styleMask = .fullScreen

        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    
}
