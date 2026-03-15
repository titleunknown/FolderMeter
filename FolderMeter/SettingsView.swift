import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var monitor: FolderMonitor

    var body: some View {
        Form {
            Section("Watched Folder") {
                if let path = monitor.rootPath {
                    LabeledContent("Path") {
                        Text(path.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    Button("Change Folder…") { monitor.selectFolder() }
                    Button("Clear", role: .destructive) { monitor.clearFolder() }
                } else {
                    Text("No folder selected")
                        .foregroundStyle(.secondary)
                    Button("Select Folder…") { monitor.selectFolder() }
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Mode") {
                    switch monitor.sessionMode {
                    case .captureOne: Text("Capture One Session").foregroundStyle(.orange)
                    case .generic: Text("Generic Folder")
                    case .none: Text("—").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 260)
    }
}
