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
            } else if monitor.rootPath != nil {
                Text(sizeLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            } else {
                Text("No folder")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
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
