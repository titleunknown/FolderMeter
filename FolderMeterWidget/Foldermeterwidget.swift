// FolderMeterWidget.swift
// Target membership: FolderMeterWidget only

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct FolderMeterEntry: TimelineEntry {
    let date: Date
    let data: FolderWidgetData?
}

// MARK: - Provider

struct FolderMeterProvider: TimelineProvider {
    func placeholder(in context: Context) -> FolderMeterEntry {
        FolderMeterEntry(date: Date(), data: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (FolderMeterEntry) -> Void) {
        // Always return placeholder for snapshot so widget appears in gallery
        completion(FolderMeterEntry(date: Date(), data: .placeholder))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FolderMeterEntry>) -> Void) {
        let entry = FolderMeterEntry(date: Date(), data: loadData())
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    private func loadData() -> FolderWidgetData? {
        guard let defaults = UserDefaults(suiteName: "group.com.fainimade.foldermeter"),
              let data = defaults.data(forKey: "widgetData"),
              let decoded = try? JSONDecoder().decode(FolderWidgetData.self, from: data)
        else { return nil }
        return decoded
    }
}

// MARK: - Entry View

struct FolderMeterWidgetEntryView: View {
    let entry: FolderMeterEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let data = entry.data ?? .placeholder
        switch family {
        case .systemSmall:  SmallWidgetView(data: data)
        case .systemMedium: MediumWidgetView(data: data)
        default:            SmallWidgetView(data: data)
        }
    }
}

// MARK: - Small widget

struct SmallWidgetView: View {
    let data: FolderWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Mode label
            HStack(spacing: 4) {
                Image(systemName: data.isCaptureOneSession ? "camera.aperture" : "folder")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(data.isCaptureOneSession ? .orange : .secondary)
                Text(data.isCaptureOneSession ? "C1 Session" : "Folder")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Session name
            Text(data.folderName)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Total size
            Text(data.formattedSize)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            // File type counts
            HStack(spacing: 6) {
                if data.rawCount > 0 {
                    fileChip("\(data.rawCount)", label: "RAW", color: .orange)
                }
                if data.jpgCount > 0 {
                    fileChip("\(data.jpgCount)", label: "JPG", color: .blue)
                }
                if data.tiffCount > 0 {
                    fileChip("\(data.tiffCount)", label: "TIF", color: .purple)
                }
            }

            // Timestamp
            Text("Updated \(data.updatedAt, style: .relative) ago")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private func fileChip(_ value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
    }
}

// MARK: - Medium widget

struct MediumWidgetView: View {
    let data: FolderWidgetData

    var body: some View {
        HStack(spacing: 0) {

            // Left column — header + totals
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: data.isCaptureOneSession ? "camera.aperture" : "folder")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(data.isCaptureOneSession ? .orange : .secondary)
                    Text(data.isCaptureOneSession ? "Capture One" : "Folder")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(data.folderName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Total size odometer
                VStack(alignment: .leading, spacing: 1) {
                    Text("TOTAL")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    Text(data.formattedSize)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }

                // RAW / JPG / TIFF counts
                HStack(spacing: 8) {
                    if data.rawCount > 0 {
                        odometerChip("\(data.rawCount)", label: "RAW", color: .orange)
                    }
                    if data.jpgCount > 0 {
                        odometerChip("\(data.jpgCount)", label: "JPG", color: .blue)
                    }
                    if data.tiffCount > 0 {
                        odometerChip("\(data.tiffCount)", label: "TIFF", color: .purple)
                    }
                }

                Text("Updated \(data.updatedAt, style: .relative) ago")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)

            Divider().padding(.vertical, 10)

            // Right column — per-folder breakdown
            VStack(alignment: .leading, spacing: 0) {
                ForEach(data.folders.prefix(4), id: \.name) { folder in
                    folderRow(folder: folder, totalSize: data.totalSize)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
        }
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private func odometerChip(_ value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func folderRow(folder: WidgetFolderInfo, totalSize: Int64) -> some View {
        let fraction = totalSize > 0 ? Double(folder.size) / Double(totalSize) : 0
        let color = folder.barColor.swiftUIColor

        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: folder.icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                    .frame(width: 12)

                VStack(alignment: .leading, spacing: 1) {
                    Text(folder.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary)
                    // Show RAW count for Capture, JPG for Output/Selects
                    Group {
                        if folder.rawCount > 0 {
                            Text("\(folder.rawCount) RAW")
                                .foregroundStyle(.orange)
                        } else if folder.jpgCount > 0 {
                            Text("\(folder.jpgCount) JPG")
                                .foregroundStyle(.secondary)
                        } else if folder.tiffCount > 0 {
                            Text("\(folder.tiffCount) TIFF")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(folder.formattedSize)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 8))
                }

                Spacer()

                Text(folder.formattedSize)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 3)

            // Size bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.secondary.opacity(0.08))
                    Rectangle().fill(color.opacity(0.35))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 2)
        }
    }
}

// MARK: - No data view

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Open FolderMeter\nto get started")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }
}

// MARK: - Widget declaration

@main
struct FolderMeterWidget: Widget {
    let kind: String = "FolderMeterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FolderMeterProvider()) { entry in
            FolderMeterWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FolderMeter")
        .description("Monitor your session folder size at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
