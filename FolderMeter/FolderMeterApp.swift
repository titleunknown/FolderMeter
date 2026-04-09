import SwiftUI
import AppKit

@main
struct FolderMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var folderMonitor = FolderMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(folderMonitor)
        } label: {
            MenuBarLabel()
                .environmentObject(folderMonitor)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
