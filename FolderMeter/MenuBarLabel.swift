import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var monitor: FolderMonitor

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .imageScale(.small)
            if monitor.isLoading {
                Text("…")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .accessibilityLabel("Calculating folder size")
            } else if monitor.rootPath != nil {
                Text(sizeLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .accessibilityLabel("Total folder size: \(sizeLabel)")
            } else {
                Text("No folder")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("No folder selected")
            }
        }
    }

    private var iconName: String {
        switch monitor.sessionMode {
        case .captureOne: return "camera.aperture"
        case .generic: return "folder"
        case .none: return "folder.badge.questionmark"
        }
    }

    private var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: monitor.totalSize, countStyle: .file)
    }
}
