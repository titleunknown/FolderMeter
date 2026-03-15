import Foundation
import Combine

// MARK: - Data Models

struct FolderInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: URL
    let size: Int64
    let fileCount: Int
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

// MARK: - FolderMonitor

@MainActor
class FolderMonitor: ObservableObject {
    @Published var sessionMode: SessionMode = .none
    @Published var totalSize: Int64 = 0
    @Published var totalRawCount: Int = 0
    @Published var subfolders: [FolderInfo] = []
    @Published var isLoading: Bool = false
    @Published var rootPath: URL? {
        didSet { onRootPathChanged() }
    }

    private var watchSource: DispatchSourceFileSystemObject?
    private var watchDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "com.foldermeter.watcher", qos: .background)

    // RAW file extensions
    private let rawExtensions: Set<String> = [
        "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng",
        "raf", "3fr", "fff", "iiq", "mrw", "nrw", "pef", "rwl",
        "sr2", "srf", "x3f", "erf"
    ]

    // Capture One known subfolder names
    private let c1FolderNames: Set<String> = [
        "Capture", "Output", "Trash", "Selects", "Cache"
    ]

    init() {
        loadSavedPath()
    }

    // MARK: - Path Persistence

    private func loadSavedPath() {
        if let savedPath = UserDefaults.standard.string(forKey: "watchedFolderPath") {
            let url = URL(fileURLWithPath: savedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                rootPath = url
            }
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose a folder to monitor"
        panel.prompt = "Monitor"

        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: "watchedFolderPath")
            rootPath = url
        }
    }

    func clearFolder() {
        stopWatching()
        UserDefaults.standard.removeObject(forKey: "watchedFolderPath")
        rootPath = nil
        sessionMode = .none
        totalSize = 0
        totalRawCount = 0
        subfolders = []
    }

    // MARK: - Path Changed

    private func onRootPathChanged() {
        stopWatching()
        guard let root = rootPath else { return }
        detectModeAndRefresh(root: root)
        startWatching(root: root)
    }

    // MARK: - Mode Detection

    private func detectModeAndRefresh(root: URL) {
        isLoading = true
        queue.async { [weak self] in
            guard let self else { return }
            let mode = self.detectMode(root: root)
            let (total, rawCount, folders) = self.calculateStats(mode: mode)

            Task { @MainActor in
                self.sessionMode = mode
                self.totalSize = total
                self.totalRawCount = rawCount
                self.subfolders = folders
                self.isLoading = false
            }
        }
    }

    private func detectMode(root: URL) -> SessionMode {
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

        // Detect C1 session: must have at least "Capture" or both "Output" + "Trash"
        let hasCapture = subDirNames.contains("Capture")
        let hasOutput = subDirNames.contains("Output")
        let hasTrash = subDirNames.contains("Trash")

        let isC1 = hasCapture || (hasOutput && hasTrash)

        if isC1 {
            let c1Session = CaptureOneSession(
                root: root,
                captureFolder: hasCapture ? root.appendingPathComponent("Capture") : nil,
                outputFolder: hasOutput ? root.appendingPathComponent("Output") : nil,
                trashFolder: hasTrash ? root.appendingPathComponent("Trash") : nil,
                selectsFolder: subDirNames.contains("Selects") ? root.appendingPathComponent("Selects") : nil,
                otherFolders: contents.filter {
                    var isDir: ObjCBool = false
                    fm.fileExists(atPath: $0.path, isDirectory: &isDir)
                    return isDir.boolValue && !c1FolderNames.contains($0.lastPathComponent)
                }
            )
            return .captureOne(session: c1Session)
        }

        return .generic(root: root)
    }

    // MARK: - Stats Calculation

    private func calculateStats(mode: SessionMode) -> (Int64, Int, [FolderInfo]) {
        switch mode {
        case .captureOne(let session):
            return calculateC1Stats(session: session)
        case .generic(let root):
            return calculateGenericStats(root: root)
        case .none:
            return (0, 0, [])
        }
    }

    private func calculateC1Stats(session: CaptureOneSession) -> (Int64, Int, [FolderInfo]) {
        var allFolders: [FolderInfo] = []
        var totalSize: Int64 = 0
        var totalRaw: Int = 0

        let namedFolders: [(URL?, String, Bool)] = [
            (session.captureFolder, "Capture", true),
            (session.outputFolder, "Output", false),
            (session.trashFolder, "Trash", false),
            (session.selectsFolder, "Selects", false),
        ]

        for (url, name, isRaw) in namedFolders {
            guard let url else { continue }
            let (size, count, rawCount) = folderStats(url: url)
            totalSize += size
            if isRaw { totalRaw += rawCount }
            allFolders.append(FolderInfo(name: name, path: url, size: size, fileCount: count, isRaw: isRaw))
        }

        for url in session.otherFolders {
            let (size, count, rawCount) = folderStats(url: url)
            totalSize += size
            totalRaw += rawCount
            allFolders.append(FolderInfo(name: url.lastPathComponent, path: url, size: size, fileCount: count, isRaw: false))
        }

        return (totalSize, totalRaw, allFolders)
    }

    private func calculateGenericStats(root: URL) -> (Int64, Int, [FolderInfo]) {
        let fm = FileManager.default
        var allFolders: [FolderInfo] = []
        var totalSize: Int64 = 0
        var totalRaw: Int = 0

        guard let contents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return (0, 0, []) }

        // Top-level files in root
        let (rootSize, rootCount, rootRaw) = folderStats(url: root, topLevelOnly: true)
        totalSize += rootSize
        totalRaw += rootRaw

        for url in contents {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
                let (size, count, rawCount) = folderStats(url: url)
                totalSize += size
                totalRaw += rawCount
                allFolders.append(FolderInfo(name: url.lastPathComponent, path: url, size: size, fileCount: count, isRaw: rawCount > 0))
            }
        }

        if rootCount > 0 {
            allFolders.insert(FolderInfo(name: "Root Files", path: root, size: rootSize, fileCount: rootCount, isRaw: rootRaw > 0), at: 0)
        }

        return (totalSize, totalRaw, allFolders.sorted { $0.size > $1.size })
    }

    private func folderStats(url: URL, topLevelOnly: Bool = false) -> (size: Int64, count: Int, rawCount: Int) {
        let fm = FileManager.default
        var totalSize: Int64 = 0
        var totalCount = 0
        var rawCount = 0

        if topLevelOnly {
            guard let contents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: .skipsHiddenFiles
            ) else { return (0, 0, 0) }

            for fileURL in contents {
                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      values.isRegularFile == true else { continue }
                totalSize += Int64(values.fileSize ?? 0)
                totalCount += 1
                if rawExtensions.contains(fileURL.pathExtension.lowercased()) { rawCount += 1 }
            }
            return (totalSize, totalCount, rawCount)
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, 0, 0) }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            totalSize += Int64(values.fileSize ?? 0)
            totalCount += 1
            if rawExtensions.contains(fileURL.pathExtension.lowercased()) { rawCount += 1 }
        }

        return (totalSize, totalCount, rawCount)
    }

    // MARK: - File System Watching

    private func startWatching(root: URL) {
        let fd = open(root.path, O_EVTONLY)
        guard fd >= 0 else { return }

        watchDescriptor = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard let root = self.rootPath else { return }
                self.detectModeAndRefresh(root: root)
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.watchDescriptor, fd >= 0 {
                close(fd)
                self?.watchDescriptor = -1
            }
        }

        watchSource = source
        source.resume()
    }

    private func stopWatching() {
        watchSource?.cancel()
        watchSource = nil
    }
}
