// Shared between the FolderMeter app and the FolderMeterWidget extension —
// this file is a member of both targets.

import Foundation
import Security
import SwiftUI

// MARK: - Snapshot

/// What the app last measured, handed to the widget through the shared
/// app-group container. The app writes it after every scan; the widget only reads.
struct WidgetSnapshot: Codable {
    let folderName: String
    let isCaptureOne: Bool
    let totalSize: Int64
    let rawCount: Int
    let jpgCount: Int
    let tiffCount: Int
    let folders: [WidgetFolder]
    let updatedAt: Date

    var formattedSize: String { ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file) }
}

struct WidgetFolder: Codable, Hashable {
    let name: String
    let size: Int64
    let fileCount: Int
    let rawCount: Int
    let jpgCount: Int
    let tiffCount: Int

    var formattedSize: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }

    /// "312 RAW · 87 JPG", falling back to a plain file count.
    var detail: String {
        let parts = [(rawCount, "RAW"), (jpgCount, "JPG"), (tiffCount, "TIFF")]
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)" }
        return parts.isEmpty ? "\(fileCount) files" : parts.joined(separator: " · ")
    }
}

// MARK: - Storage

extension WidgetSnapshot {
    static let widgetKind = "FolderMeterWidget"

    // The app-group ID is read from our own entitlements instead of being
    // hardcoded, so it always matches the team that signed the build
    // ($(TeamIdentifierPrefix)com.fainimade.foldermeter). A mismatch between the
    // code and the entitlement is what silently broke the previous widget.
    private static let fileURL: URL? = {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil) as? [String],
              let group = groups.first,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { return nil }
        return container.appendingPathComponent("WidgetSnapshot.json")
    }()

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(self).write(to: url, options: .atomic)
        } catch {
            print("Failed to write widget snapshot: \(error)")
        }
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Folder styling

/// Colors and icons for the Capture One folder roles, used by both the menu and the widget.
enum FolderStyle {
    static func color(for name: String) -> Color {
        switch name {
        case "Capture": return .orange
        case "Output":  return .blue
        case "Trash":   return .red
        case "Selects": return .green
        default:        return .secondary
        }
    }

    static func icon(for name: String) -> String {
        switch name {
        case "Capture": return "camera.aperture"
        case "Output":  return "arrow.up.doc"
        case "Trash":   return "trash"
        case "Selects": return "star"
        default:        return "folder"
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
