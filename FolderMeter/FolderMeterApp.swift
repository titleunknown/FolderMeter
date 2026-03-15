import SwiftUI

@main
struct FolderMeterApp: App {
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

        Settings {
            SettingsView()
                .environmentObject(folderMonitor)
        }
    }
}
