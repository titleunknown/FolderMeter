import WidgetKit
import SwiftUI

// MARK: - Timeline

struct FolderMeterEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct FolderMeterProvider: TimelineProvider {
    func placeholder(in context: Context) -> FolderMeterEntry {
        FolderMeterEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (FolderMeterEntry) -> Void) {
        // The widget gallery shows sample data until a folder has been scanned.
        let snapshot = WidgetSnapshot.load() ?? (context.isPreview ? .sample : nil)
        completion(FolderMeterEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FolderMeterEntry>) -> Void) {
        let entry = FolderMeterEntry(date: .now, snapshot: WidgetSnapshot.load())
        // The app asks WidgetKit to reload whenever a scan finishes; this is only a fallback.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

// MARK: - Widget

@main
struct FolderMeterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.widgetKind, provider: FolderMeterProvider()) { entry in
            FolderMeterWidgetView(entry: entry)
        }
        .configurationDisplayName("FolderMeter")
        .description("Your monitored folder's size and file counts at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct FolderMeterWidgetView: View {
    let entry: FolderMeterEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemMedium: MediumView(snapshot: snapshot)
                case .systemLarge:  LargeView(snapshot: snapshot)
                default:            SmallView(snapshot: snapshot)
                }
            } else {
                NoFolderView()
            }
        }
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }
}

// MARK: - Sizes

private struct SmallView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(snapshot: snapshot)
            Spacer(minLength: 6)
            Totals(snapshot: snapshot)
            Spacer(minLength: 6)
            UpdatedLabel(date: snapshot.updatedAt)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MediumView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            SmallView(snapshot: snapshot)
                .frame(width: 130)

            Divider()

            FittingFolderList(folders: snapshot.folders, totalSize: snapshot.totalSize, maxRows: 4, showsDetail: false)
        }
    }
}

private struct LargeView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Header(snapshot: snapshot)
                Spacer(minLength: 8)
                OdometerLabel(value: snapshot.formattedSize, label: "TOTAL", color: .primary, size: 22)
            }

            HStack {
                Counts(snapshot: snapshot)
                Spacer()
            }

            Divider()

            FittingFolderList(folders: snapshot.folders, totalSize: snapshot.totalSize, maxRows: 6, showsDetail: true)

            UpdatedLabel(date: snapshot.updatedAt)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct NoFolderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("Open FolderMeter\nand choose a folder")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Components

private struct Header: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: snapshot.isCaptureOne ? "camera.aperture" : "folder")
                Text(snapshot.isCaptureOne ? "Capture One" : "Folder")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(snapshot.isCaptureOne ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))

            Text(snapshot.folderName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct Totals: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            OdometerLabel(value: snapshot.formattedSize, label: "TOTAL", color: .primary, size: 20, alignment: .leading)
            Counts(snapshot: snapshot)
        }
    }
}

private struct Counts: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 10) {
            if snapshot.rawCount > 0 {
                OdometerLabel(value: "\(snapshot.rawCount)", label: "RAW", color: .orange, size: 13, alignment: .leading)
            }
            if snapshot.jpgCount > 0 {
                OdometerLabel(value: "\(snapshot.jpgCount)", label: "JPG", color: .blue, size: 13, alignment: .leading)
            }
            if snapshot.tiffCount > 0 {
                OdometerLabel(value: "\(snapshot.tiffCount)", label: "TIFF", color: .purple, size: 13, alignment: .leading)
            }
        }
    }
}

private struct UpdatedLabel: View {
    let date: Date

    var body: some View {
        Text("Updated \(date, style: .relative) ago")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }
}

/// Shows as many folder rows as fit the space left over (up to `maxRows`);
/// the rest collapse into "+N more" rather than pushing the header off the widget.
private struct FittingFolderList: View {
    let folders: [WidgetFolder]
    let totalSize: Int64
    let maxRows: Int
    let showsDetail: Bool

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach((1...maxRows).reversed(), id: \.self) { limit in
                FolderList(folders: folders, totalSize: totalSize, limit: limit, showsDetail: showsDetail)
            }
        }
        // The only flexible child of its stack, so it's offered all the leftover height.
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct FolderList: View {
    let folders: [WidgetFolder]
    let totalSize: Int64
    let limit: Int
    let showsDetail: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: showsDetail ? 9 : 7) {
            ForEach(folders.prefix(limit), id: \.self) { folder in
                FolderBar(folder: folder, totalSize: totalSize, showsDetail: showsDetail)
            }
            if folders.count > limit {
                Text("+\(folders.count - limit) more")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct FolderBar: View {
    let folder: WidgetFolder
    let totalSize: Int64
    let showsDetail: Bool

    private var fraction: Double {
        guard totalSize > 0 else { return 0 }
        return Double(folder.size) / Double(totalSize)
    }

    var body: some View {
        let color = FolderStyle.color(for: folder.name)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: FolderStyle.icon(for: folder.name))
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text(folder.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    if showsDetail {
                        Text(folder.detail)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Text(folder.formattedSize)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule().fill(color.opacity(0.55)).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 3)
        }
    }
}

// MARK: - Sample data

extension WidgetSnapshot {
    static let sample = WidgetSnapshot(
        folderName: "Smith Wedding",
        isCaptureOne: true,
        totalSize: 42_000_000_000,
        rawCount: 1_312,
        jpgCount: 287,
        tiffCount: 0,
        folders: [
            WidgetFolder(name: "Capture", size: 28_000_000_000, fileCount: 1_312, rawCount: 1_312, jpgCount: 0, tiffCount: 0),
            WidgetFolder(name: "Output", size: 9_000_000_000, fileCount: 287, rawCount: 0, jpgCount: 287, tiffCount: 0),
            WidgetFolder(name: "Selects", size: 3_000_000_000, fileCount: 64, rawCount: 0, jpgCount: 0, tiffCount: 0),
            WidgetFolder(name: "Trash", size: 2_000_000_000, fileCount: 41, rawCount: 0, jpgCount: 0, tiffCount: 0),
        ],
        updatedAt: .now
    )
}

#Preview(as: .systemMedium) {
    FolderMeterWidget()
} timeline: {
    FolderMeterEntry(date: .now, snapshot: .sample)
    FolderMeterEntry(date: .now, snapshot: nil)
}
