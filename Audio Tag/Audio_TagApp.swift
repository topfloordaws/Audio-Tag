//
//  Audio_TagApp.swift
//  Audio Tag
//
//  Created by Dawson Pham on 6/24/25.
//

import SwiftUI

@main
struct Audio_TagApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Replaces the default "New" menu item with Open Folder and Refresh
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenFolderMenuAction"), object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
                
                Button("Refresh") {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFolderMenuAction"), object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            
            // Includes standard View menu commands like Toggle Sidebar/Fullscreen
            SidebarCommands()
        }
    }
}
