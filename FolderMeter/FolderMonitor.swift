import Foundation
import Combine
import AppKit

// MARK: - Data Models

struct FolderInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: URL
    let size: Int64
    let fileCount: Int
    let rawCount: Int
    let jpgCount: Int
    let subfolderCount: Int  // direct subfolders, excluding CaptureOne system dirs
    let isRaw: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum SessionMode {
    case captureOne(session: CaptureOneSession)
    case generic(root: URL)
    case none
}

struct CaptureOneSession {
    let root: URL
    let captureFolder: URL?
    let outputFolder: URL?
    let trashFolder: URL?
    let selectsFolder: URL?
    let otherFolders: [URL]
}

// MARK: - Static helpers (no actor isolation needed)

private let kRawExtensions: Set<String> = [
    "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng",
    "raf", "3fr", "fff", "iiq", "mrw", "nrw", "pef", "rwl",
    "sr2", "srf", "x3f", "erf"
]

private let kJpgExtensions: Set<String> = ["jpg", "jpeg"]

private let kC1FolderNames: Set<String> = [
    "Capture", "Output", "Trash", "Selects", "Cache"
]

// Folders created by Capture One software itself — excluded from counts
private let kC1SystemDirs: Set<String> = ["CaptureOne"]

private func computeDetectMode(root: URL) -> SessionMode {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: .skipsHiddenFiles
    ) else { return .generic(root: root) }

    let subDirNames = Set(contents.compactMap { url -> String? in
        var isDir: ObjCBool = false
        fm.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue ? url.lastPathComponent : nil
    })

    let hasCapture = subDirNames.contains("Capture")
    let hasOutput  = subDirNames.contains("Output")
    let hasTrash   = subDirNames.contains("Trash")
    let isC1 = hasCapture || (hasOutput && hasTrash)

    if isC1 {
        let session = CaptureOneSession(
            root: root,
            captureFolder: hasCapture ? root.appendingPathComponent("Capture") : nil,
            outputFolder:  hasOutput  ? root.appendingPathComponent("Output")  : nil,
            trashFolder:   hasTrash   ? root.appendingPathComponent("Trash")   : nil,
            selectsFolder: subDirNames.contains("Selects") ? root.appendingPathComponent("Selects") : nil,
            otherFolders: contents.filter {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: $0.path, isDirectory: &isDir)
                return isDir.boolValue && !kC1FolderNames.contains($0.lastPathComponent)
            }
        )
        return .captureOne(session: session)
    }

    return .generic(root: root)
}

private func computeStats(mode: SessionMode) -> (total: Int64, rawCount: Int, jpgCount: Int, folders: [FolderInfo]) {
    switch mode {
    case .captureOne(let session): return computeC1Stats(session: session)
    case .generic(let root):       return computeGenericStats(root: root)
    case .none:                    return (0, 0, 0, [])
    }
}

private func computeC1Stats(session: CaptureOneSession) -> (Int64, Int, Int, [FolderInfo]) {
    var folders: [FolderInfo] = []
    var totalSize: Int64 = 0
    var totalRaw = 0
    var totalJpg = 0

    let named: [(URL?, String, Bool)] = [
        (session.captureFolder, "Capture", true),
        (session.outputFolder,  "Output",  false),
        (session.trashFolder,   "Trash",   false),
        (session.selectsFolder, "Selects", false),
    ]

    for (url, name, isRaw) in named {
        guard let url else { continue }
        let s = folderStats(url: url)
        totalSize += s.size
        if isRaw { totalRaw += s.rawCount }
        totalJpg += s.jpgCount
        folders.append(FolderInfo(
            name: name, path: url,
            size: s.size, fileCount: s.count,
            rawCount: s.rawCount, jpgCount: s.jpgCount,
            subfolderCount: s.subfolderCount, isRaw: isRaw
        ))
    }

    for url in session.otherFolders {
        let s = folderStats(url: url)
        totalSize += s.size
        totalRaw  += s.rawCount
        totalJpg  += s.jpgCount
        folders.append(FolderInfo(
            name: url.lastPathComponent, path: url,
            size: s.size, fileCount: s.count,
            rawCount: s.rawCount, jpgCount: s.jpgCount,
            subfolderCount: s.subfolderCount, isRaw: false
        ))
    }

    return (totalSize, totalRaw, totalJpg, folders)
}

private func computeGenericStats(root: URL) -> (Int64, Int, Int, [FolderInfo]) {
    let fm = FileManager.default
    var folders: [FolderInfo] = []
    var totalSize: Int64 = 0
    var totalRaw = 0
    var totalJpg = 0

    guard let contents = try? fm.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: .skipsHiddenFiles
    ) else { return (0, 0, 0, []) }

    let rootStats = folderStats(url: root, topLevelOnly: true)
    totalSize += rootStats.size
    totalRaw  += rootStats.rawCount
    totalJpg  += rootStats.jpgCount

    for url in contents {
        var isDir: ObjCBool = false
        fm.fileExists(atPath: url.path, isDirectory: &isDir)
        guard isDir.boolValue else { continue }
        let s = folderStats(url: url)
        totalSize += s.size
        totalRaw  += s.rawCount
        totalJpg  += s.jpgCount
        folders.append(FolderInfo(
            name: url.lastPathComponent, path: url,
            size: s.size, fileCount: s.count,
            rawCount: s.rawCount, jpgCount: s.jpgCount,
            subfolderCount: s.subfolderCount, isRaw: s.rawCount > 0
        ))
    }

    if rootStats.count > 0 {
        folders.insert(FolderInfo(
            name: "Root Files", path: root,
            size: rootStats.size, fileCount: rootStats.count,
            rawCount: rootStats.rawCount, jpgCount: rootStats.jpgCount,
            subfolderCount: 0, isRaw: rootStats.rawCount > 0
        ), at: 0)
    }

    return (totalSize, totalRaw, totalJpg, folders.sorted { $0.size > $1.size })
}

private func folderStats(url: URL, topLevelOnly: Bool = false) -> (size: Int64, count: Int, rawCount: Int, jpgCount: Int, subfolderCount: Int) {
    let fm = FileManager.default
    var size: Int64 = 0
    var count = 0
    var rawCount = 0
    var jpgCount = 0

    // Count direct subfolders, skipping CaptureOne system dirs
    let subfolderCount: Int = {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return 0 }
        return contents.filter {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: $0.path, isDirectory: &isDir)
            return isDir.boolValue && !kC1SystemDirs.contains($0.lastPathComponent)
        }.count
    }()

    let fileKeys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]

    if topLevelOnly {
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(fileKeys), options: .skipsHiddenFiles) else {
            return (0, 0, 0, 0, subfolderCount)
        }
        for f in contents {
            guard let v = try? f.resourceValues(forKeys: fileKeys), v.isRegularFile == true else { continue }
            size += Int64(v.fileSize ?? 0)
            count += 1
            let ext = f.pathExtension.lowercased()
            if kRawExtensions.contains(ext) { rawCount += 1 }
            if kJpgExtensions.contains(ext) { jpgCount += 1 }
        }
        return (size, count, rawCount, jpgCount, subfolderCount)
    }

    // Recursive enumeration — skip CaptureOne system dirs entirely
    let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(fileKeys), options: .skipsHiddenFiles)
    guard let enumerator else {
        return (0, 0, 0, 0, subfolderCount)
    }
    for case let f as URL in enumerator {
        // Skip the CaptureOne dir and all its contents
        if kC1SystemDirs.contains(f.lastPathComponent) {
            enumerator.skipDescendants()
            continue
        }
        guard let v = try? f.resourceValues(forKeys: fileKeys), v.isRegularFile == true else { continue }
        size += Int64(v.fileSize ?? 0)
        count += 1
        let ext = f.pathExtension.lowercased()
        if kRawExtensions.contains(ext) { rawCount += 1 }
        if kJpgExtensions.contains(ext) { jpgCount += 1 }
    }
    return (size, count, rawCount, jpgCount, subfolderCount)
}

// MARK: - FolderMonitor

@MainActor
class FolderMonitor: ObservableObject {
    @Published var sessionMode: SessionMode = .none
    @Published var totalSize: Int64 = 0
    @Published var totalRawCount: Int = 0
    @Published var totalJpgCount: Int = 0
    @Published var subfolders: [FolderInfo] = []
    @Published var isLoading: Bool = false
    @Published var rootPath: URL? {
        didSet { onRootPathChanged() }
    }

    private var watchSources: [DispatchSourceFileSystemObject] = []
    private let watchQueue = DispatchQueue(label: "com.foldermeter.watcher", qos: .background)
    private var debounceWorkItem: DispatchWorkItem?

    init() {
        loadSavedPath()
    }

    // MARK: - Persistence

    private func loadSavedPath() {
        if let saved = UserDefaults.standard.string(forKey: "watchedFolderPath") {
            let url = URL(fileURLWithPath: saved)
            if FileManager.default.fileExists(atPath: url.path) {
                rootPath = url
            }
        }
    }

    // MARK: - Folder Selection

    func selectFolder() {
        // Hide the MenuBarExtra window without closing it (closing kills the app)
        NSApp.keyWindow?.orderOut(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)

            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.title = "Choose a folder to monitor"
            panel.prompt = "Monitor"
            panel.center()
            panel.makeKeyAndOrderFront(nil)

            panel.begin { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                UserDefaults.standard.set(url.path, forKey: "watchedFolderPath")
                Task { @MainActor in
                    self?.rootPath = url
                }
            }
        }
    }

    func clearFolder() {
        stopWatching()
        UserDefaults.standard.removeObject(forKey: "watchedFolderPath")
        rootPath = nil
        sessionMode = .none
        totalSize = 0
        totalRawCount = 0
        totalJpgCount = 0
        subfolders = []
    }

    func forceRefresh() {
        guard let root = rootPath else { return }
        refresh(root: root)
    }

    // MARK: - Path Changed

    private func onRootPathChanged() {
        stopWatching()
        guard let root = rootPath else { return }
        refresh(root: root)
        startWatching(root: root)
    }

    // MARK: - Refresh

    private func refresh(root: URL) {
        isLoading = true
        let capturedRoot = root
        Task.detached(priority: .userInitiated) { [weak self] in
            let mode = computeDetectMode(root: capturedRoot)
            let (total, rawCount, jpgCount, folders) = computeStats(mode: mode)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.sessionMode = mode
                self.totalSize = total
                self.totalRawCount = rawCount
                self.totalJpgCount = jpgCount
                self.subfolders = folders
                self.isLoading = false
            }
        }
    }

    // MARK: - File System Watching

    private func startWatching(root: URL) {
        var dirs: [URL] = [root]
        if let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) {
            for case let url as URL in enumerator {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    dirs.append(url)
                }
            }
        }
        for dir in dirs { watchDirectory(dir) }
    }

    private func watchDirectory(_ url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend, .link],
            queue: watchQueue
        )
        source.setEventHandler { [weak self] in self?.scheduleRefresh() }
        source.setCancelHandler { close(fd) }
        watchSources.append(source)
        source.resume()
    }

    private func scheduleRefresh() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let root = self.rootPath else { return }
                self.refresh(root: root)
            }
        }
        debounceWorkItem = work
        watchQueue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func stopWatching() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        watchSources.forEach { $0.cancel() }
        watchSources.removeAll()
    }
}
