//
//  AppDelegate.swift
//  Audio Tag
//
//  Created by Dawson Pham on 7/3/25.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let frameKey = "mainWindowFrame"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Grab the first (main) window
        if let window = NSApp.windows.first {
            // 2️⃣ Restore saved frame
            if let frameString = UserDefaults.standard.string(forKey: frameKey),
               let frame = NSRectFromString(frameString) as NSRect? {
                window.setFrame(frame, display: true)
            }

            // 3️⃣ Observe moves/resizes
            window.delegate = self
        }
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame(from: notification)
    }
    func windowDidMove(_ notification: Notification) {
        saveFrame(from: notification)
    }

    private func saveFrame(from notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: frameKey)
    }
}
