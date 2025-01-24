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
        if let window = NSApplication.shared.windows.first {
            // Set window size using setFrame
            let newFrame = NSRect(x: window.frame.origin.x,
                                y: window.frame.origin.y,
                                width: 1920 / 2,
                                height: 1080 / 2)
            window.setFrame(newFrame, display: true)
            
            window.toggleFullScreen(nil)
            
            // Set fullscreen directly
            if !window.styleMask.contains(.fullScreen) {
                window.collectionBehavior = [.fullScreenPrimary]
                window.setFrame(window.screen?.frame ?? newFrame, display: true)
                window.styleMask.insert(.fullScreen)
            }
            
            window.makeKeyAndOrderFront(nil)
            
            // Add slight delay to check fullscreen state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if window.styleMask.contains(.fullScreen) {
                    NSCursor.hide()
                }
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    
}
