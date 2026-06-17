import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var monitor: FolderMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section 1: mode label + folder name (full width, its own area)
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, monitor.rootPath != nil ? 10 : 14)

            // Section 2: dedicated stats area (TOTAL + file-type counts)
            if monitor.rootPath != nil {
                if !monitor.isLoading {
                    statsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                Divider().padding(.horizontal, 12)

                if monitor.isLoading {
                    loadingView
                } else if monitor.subfolders.isEmpty {
                    emptyView
                } else {
                    subfolderList
                }

                Divider().padding(.horizontal, 12)
            }

            footerActions
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            // About
            Divider().padding(.horizontal, 12)
            aboutSection
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .frame(width: 300)
        .background(.regularMaterial)
        .onAppear {
            monitor.forceRefresh()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        // Mode label + session/folder name — its own full-width section so the
        // name has room to breathe and never competes with the counts.
        VStack(alignment: .leading, spacing: 4) {
            modeLabel
            if let root = monitor.rootPath {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([root])
                } label: {
                    Text(root.lastPathComponent)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .help("\(root.lastPathComponent)\n\(root.path(percentEncoded: false))\n\nReveal in Finder")
                .accessibilityLabel("Open folder: \(root.lastPathComponent)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        // Dedicated counts area: TOTAL on the left, file-type counts on the
        // right. Counts keep their natural width (no truncation) and, because
        // they no longer share a row with the folder name, there's plenty of
        // horizontal room.
        // TOTAL on its own row above the file-type counts, both right-justified.
        // Stacking them gives the counts the full width, so higher counts and a
        // third (TIFF) column have room without crowding.
        VStack(alignment: .trailing, spacing: 6) {
            OdometerLabel(
                value: ByteCountFormatter.string(fromByteCount: monitor.totalSize, countStyle: .file),
                label: "TOTAL",
                color: .primary,
                size: 20
            )

            HStack(spacing: 10) {
                if monitor.totalRawCount > 0 {
                    OdometerLabel(value: "\(monitor.totalRawCount)", label: "RAW", color: .orange, size: 15)
                }
                if monitor.totalRawCount > 0 && monitor.totalJpgCount > 0 {
                    statDivider
                }
                if monitor.totalJpgCount > 0 {
                    OdometerLabel(value: "\(monitor.totalJpgCount)", label: "JPG", color: .blue, size: 15)
                }
                if (monitor.totalRawCount > 0 || monitor.totalJpgCount > 0) && monitor.totalTiffCount > 0 {
                    statDivider
                }
                if monitor.totalTiffCount > 0 {
                    OdometerLabel(value: "\(monitor.totalTiffCount)", label: "TIFF", color: .purple, size: 15)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .frame(width: 1, height: 24)
    }

    private var modeLabel: some View {
        HStack(spacing: 4) {
            switch monitor.sessionMode {
            case .captureOne:
                Image(systemName: "camera.aperture").font(.system(size: 10)).foregroundStyle(.orange)
                Text("Capture One Session").font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
            case .generic:
                Image(systemName: "folder").font(.system(size: 10)).foregroundStyle(.secondary)
                Text("Folder").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            case .none:
                Text("No folder selected").font(.system(size: 10)).foregroundStyle(.secondary)
            }
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
                Text("Calculating…").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var emptyView: some View {
        HStack {
            Spacer()
            Text("No subfolders found").font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 16)
    }

    // MARK: - About

    private var aboutSection: some View {
        HStack(alignment: .center, spacing: 8) {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: brand
            HStack(spacing: 0) {
                Text("FolderMeter")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(" · by ")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Button {
                    NSWorkspace.shared.open(URL(string: "https://www.fainimade.com")!)
                } label: {
                    Text("FAINI MADE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .underline()
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .accessibilityLabel("Visit Faini Made website")
            }

            // Row 2: version + update state
            HStack(spacing: 5) {
                Text("v\(monitor.currentVersion)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.quaternary)

                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)

                switch monitor.updateState {
                case .idle:
                    Button("Check for updates") { monitor.checkForUpdates() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Check for updates")

                case .checking:
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                        Text("Checking…")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                case .upToDate:
                    Text("Up to date ✓")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)

                case .available(let version, let url):
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text("\(version) available →")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.orange)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    .accessibilityLabel("Download version \(version)")

                case .error:
                    Text("Check failed")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }

                Spacer()
            }
        }

            Spacer(minLength: 8)

            // Quit lives here now, in the bottom-right of the about area.
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Quit FolderMeter")
        }
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
            .foregroundStyle(.secondary)
            .accessibilityLabel(monitor.rootPath == nil ? "Select folder to monitor" : "Change monitored folder")

            Spacer()

            if monitor.rootPath != nil {
                Button { monitor.forceRefresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Refresh")
                .accessibilityLabel("Refresh folder size calculation")

                Button { monitor.clearFolder() } label: {
                    Image(systemName: "xmark.circle").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove")
                .accessibilityLabel("Remove monitored folder")
            }
        }
    }
}

// MARK: - Odometer Label

struct OdometerLabel: View {
    let value: String
    let label: String
    let color: Color
    let size: CGFloat
    var alignment: HorizontalAlignment = .trailing

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Text(value)
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
        }
        // Never truncate the counts — keep them at their natural width so the
        // stats area scales to fit the numbers instead of clipping them to "84…".
        .fixedSize(horizontal: true, vertical: false)
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
        case "Output":  return .blue
        case "Trash":   return .red
        case "Selects": return .green
        default:        return .secondary
        }
    }

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([folder.path])
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: folderIcon)
                        .font(.system(size: 11))
                        .foregroundStyle(barColor)
                        .frame(width: 16)
                        .accessibilityLabel("Folder type: \(folder.name)")

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(folder.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .accessibilityLabel("Folder name: \(folder.name)")
                            if folder.name == "Capture" && folder.rawCount > 0 {
                                Text("\(folder.rawCount) RAW")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                                    .accessibilityLabel("\(folder.rawCount) RAW files")
                            }
                        }

                        HStack(spacing: 6) {
                            if folder.subfolderCount > 0 {
                                Text("\(folder.subfolderCount) \(folder.subfolderCount == 1 ? "folder" : "folders")")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("\(folder.subfolderCount) subfolders")
                            }
                            if folder.subfolderCount > 0 && (folder.rawCount > 0 || folder.jpgCount > 0 || folder.tiffCount > 0) {
                                Text("·").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            if folder.rawCount > 0 {
                                Text("\(folder.rawCount) RAW")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("\(folder.rawCount) RAW files")
                            }
                            if folder.rawCount > 0 && folder.jpgCount > 0 {
                                Text("·").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            if folder.jpgCount > 0 {
                                Text("\(folder.jpgCount) JPG")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("\(folder.jpgCount) JPG files")
                            }
                            if folder.tiffCount > 0 {
                                Text("\(folder.tiffCount) TIFF")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("\(folder.tiffCount) TIFF files")
                            }
                            if folder.subfolderCount == 0 && folder.rawCount == 0 && folder.jpgCount == 0 && folder.tiffCount == 0 {
                                Text("\(folder.fileCount) files")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("\(folder.fileCount) files")
                            }
                        }
                    }

                    Spacer()

                    Text(folder.formattedSize)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Folder size: \(folder.formattedSize)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.secondary.opacity(0.08))
                        Rectangle().fill(barColor.opacity(0.3)).frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 2)
                .padding(.horizontal, 16)
            }
        }
        .buttonStyle(.plain)
        .help("Reveal in Finder")
        .accessibilityLabel("Open folder: \(folder.name)")
    }

    private var folderIcon: String {
        switch folder.name {
        case "Capture": return "camera.aperture"
        case "Output":  return "arrow.up.doc"
        case "Trash":   return "trash"
        case "Selects": return "star"
        default:        return "folder"
        }
    }
}
