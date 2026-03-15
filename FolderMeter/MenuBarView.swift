import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var monitor: FolderMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if monitor.rootPath != nil {
                Divider()
                    .padding(.horizontal, 12)

                // Subfolder breakdown
                if monitor.isLoading {
                    loadingView
                } else if monitor.subfolders.isEmpty {
                    emptyView
                } else {
                    subfolderList
                }

                Divider()
                    .padding(.horizontal, 12)
            }

            // Footer actions
            footerActions
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(width: 280)
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                modeLabel
                Spacer()
                if monitor.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }

            if let root = monitor.rootPath {
                Text(root.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if monitor.rootPath != nil && !monitor.isLoading {
                HStack(spacing: 16) {
                    statPill(
                        label: "Total",
                        value: ByteCountFormatter.string(fromByteCount: monitor.totalSize, countStyle: .file),
                        color: .primary
                    )
                    if monitor.totalRawCount > 0 {
                        statPill(
                            label: "RAW files",
                            value: "\(monitor.totalRawCount)",
                            color: .orange
                        )
                    }
                }
            }
        }
    }

    private var modeLabel: some View {
        HStack(spacing: 4) {
            switch monitor.sessionMode {
            case .captureOne:
                Image(systemName: "camera.aperture")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text("Capture One Session")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            case .generic:
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("Folder")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            case .none:
                Text("No folder selected")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    // MARK: - Subfolder List

    private var subfolderList: some View {
        VStack(spacing: 0) {
            ForEach(monitor.subfolders) { folder in
                FolderRow(folder: folder, totalSize: monitor.totalSize)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Loading / Empty

    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text("Calculating…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var emptyView: some View {
        HStack {
            Spacer()
            Text("No subfolders found")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 16)
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack(spacing: 8) {
            Button {
                monitor.selectFolder()
            } label: {
                Label(monitor.rootPath == nil ? "Select Folder" : "Change Folder", systemImage: "folder.badge.plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Spacer()

            if monitor.rootPath != nil {
                Button {
                    if let path = monitor.rootPath {
                        NSWorkspace.shared.open(path)
                    }
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Open in Finder")

                Button {
                    monitor.clearFolder()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove")
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let folder: FolderInfo
    let totalSize: Int64

    private var fraction: Double {
        guard totalSize > 0 else { return 0 }
        return Double(folder.size) / Double(totalSize)
    }

    private var barColor: Color {
        switch folder.name {
        case "Capture": return .orange
        case "Output": return .blue
        case "Trash": return .red
        case "Selects": return .green
        default: return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: folderIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(barColor)
                    .frame(width: 16)

                // Name + count
                VStack(alignment: .leading, spacing: 1) {
                    Text(folder.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text("\(folder.fileCount) files")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        if folder.isRaw {
                            Text("· RAW")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                // Size
                Text(folder.formattedSize)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.08))
                    Rectangle()
                        .fill(barColor.opacity(0.3))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 16)
        }
    }

    private var folderIcon: String {
        switch folder.name {
        case "Capture": return "camera.aperture"
        case "Output": return "arrow.up.doc"
        case "Trash": return "trash"
        case "Selects": return "star"
        default: return "folder"
        }
    }
}
