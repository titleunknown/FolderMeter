// SharedModels.swift
//
// ⚠️  TARGET MEMBERSHIP: set this file to belong to BOTH targets:
//     • FolderMeter  (main app)
//     • FolderMeterWidget  (widget extension)

import Foundation
import SwiftUI

// MARK: - Per-folder data for widget

struct WidgetFolderInfo: Codable {
    let name: String
    let size: Int64
    let rawCount: Int
    let jpgCount: Int
    let tiffCount: Int
    let fileCount: Int

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var barColor: WidgetFolderColor {
        switch name {
        case "Capture": return .orange
        case "Output":  return .blue
        case "Trash":   return .red
        case "Selects": return .green
        default:        return .secondary
        }
    }

    var icon: String {
        switch name {
        case "Capture": return "camera.aperture"
        case "Output":  return "arrow.up.doc"
        case "Trash":   return "trash"
        case "Selects": return "star"
        default:        return "folder"
        }
    }
}

// Color can't be Codable so we use an enum
enum WidgetFolderColor: String, Codable {
    case orange, blue, red, green, secondary

    var swiftUIColor: Color {
        switch self {
        case .orange:    return .orange
        case .blue:      return .blue
        case .red:       return .red
        case .green:     return .green
        case .secondary: return .secondary
        }
    }
}

// MARK: - Top-level widget data

struct FolderWidgetData: Codable {
    let folderName: String
    let totalSize: Int64
    let rawCount: Int
    let jpgCount: Int
    let tiffCount: Int
    let isCaptureOneSession: Bool
    let folders: [WidgetFolderInfo]
    let updatedAt: Date

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    static var placeholder: Self {
        FolderWidgetData(
            folderName: "My Session",
            totalSize: 42_000_000_000,
            rawCount: 312,
            jpgCount: 87,
            tiffCount: 0,
            isCaptureOneSession: true,
            folders: [
                WidgetFolderInfo(name: "Capture", size: 28_000_000_000, rawCount: 312, jpgCount: 0,  tiffCount: 0, fileCount: 312),
                WidgetFolderInfo(name: "Output",  size: 9_000_000_000,  rawCount: 0,   jpgCount: 87, tiffCount: 0, fileCount: 87),
                WidgetFolderInfo(name: "Selects", size: 3_000_000_000,  rawCount: 0,   jpgCount: 24, tiffCount: 0, fileCount: 24),
                WidgetFolderInfo(name: "Trash",   size: 2_000_000_000,  rawCount: 0,   jpgCount: 0,  tiffCount: 0, fileCount: 0),
            ],
            updatedAt: Date()
        )
    }
}
