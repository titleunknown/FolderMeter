import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var monitor: FolderMonitor

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .imageScale(.small)

            if monitor.rootPath != nil {
                Text(sizeLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    // Reserve space so the menu bar item doesn't reflow as the
                    // size string grows/shrinks; grows past this only for very
                    // large values, which is rare.
                    .frame(minWidth: 56, alignment: .leading)
                    .animation(.default, value: monitor.totalSize)
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
        case .generic:    return "folder"
        case .none:       return "folder.badge.questionmark"
        }
    }

    // Keep the last known size on screen while a refresh runs in the background —
    // only show a placeholder for the very first scan, when there's no value yet.
    private var sizeLabel: String {
        if monitor.isLoading && monitor.totalSize == 0 {
            return "…"
        }
        return ByteCountFormatter.string(fromByteCount: monitor.totalSize, countStyle: .file)
    }
}
