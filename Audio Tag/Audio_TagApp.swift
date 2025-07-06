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
            //FolderBrowserView()
        }
    }
}
