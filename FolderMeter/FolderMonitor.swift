import Foundation
import AppKit

// MARK: - Models

struct FolderInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: URL
    let size: Int64
    let fileCount: Int
    let rawCount: Int
    let jpgCount: Int
    let tiffCount: Int
    let subfolderCount: Int
    let isRaw: Bool
    var formattedSize: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
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

// MARK: - File scanning (runs off main thread, no actor isolation)

private let kRaw: Set<String> = ["raw","cr2","cr3","nef","arw","orf","rw2","dng","raf","3fr","fff","iiq","mrw","nrw","pef","rwl","sr2","srf","x3f","erf"]
private let kJpg: Set<String> = ["jpg","jpeg"]
private let kTiff: Set<String> = ["tiff","tif"]
private let kC1System: Set<String> = ["CaptureOne"]

private func detectMode(root: URL) -> SessionMode {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else { return .generic(root: root) }
    let dirs = contents.filter { url in var d: ObjCBool = false; fm.fileExists(atPath: url.path, isDirectory: &d); return d.boolValue }
    func find(_ kw: String) -> URL? { dirs.first { $0.lastPathComponent.localizedCaseInsensitiveContains(kw) } }
    let cap = find("Capture"), out = find("Output"), tra = find("Trash"), sel = find("Selects")
    guard cap != nil, out != nil, tra != nil, sel != nil else { return .generic(root: root) }
    let known = Set([cap, out, tra, sel].compactMap { $0?.lastPathComponent })
    return .captureOne(session: CaptureOneSession(root: root, captureFolder: cap, outputFolder: out, trashFolder: tra, selectsFolder: sel, otherFolders: dirs.filter { !known.contains($0.lastPathComponent) }))
}

private struct ScanResult {
    let totalSize: Int64
    let rawCount: Int
    let jpgCount: Int
    let tiffCount: Int
    let folders: [FolderInfo]
}

private func scan(mode: SessionMode) -> ScanResult {
    switch mode {
    case .captureOne(let s): return scanC1(s)
    case .generic(let r): return scanGeneric(r)
    case .none: return ScanResult(totalSize: 0, rawCount: 0, jpgCount: 0, tiffCount: 0, folders: [])
    }
}

private func scanC1(_ s: CaptureOneSession) -> ScanResult {
    var total: Int64 = 0; var raw = 0; var jpg = 0; var tiff = 0; var folders: [FolderInfo] = []
    for (url, name, isRaw) in [(s.captureFolder,"Capture",true),(s.outputFolder,"Output",false),(s.trashFolder,"Trash",false),(s.selectsFolder,"Selects",false)] as [(URL?,String,Bool)] {
        guard let url else { continue }
        let st = stats(url)
        total += st.size
        if isRaw { raw += st.rawCount }
        jpg += st.jpgCount
        tiff += st.tiffCount
        folders.append(FolderInfo(name: name, path: url, size: st.size, fileCount: st.count, rawCount: st.rawCount, jpgCount: st.jpgCount, tiffCount: st.tiffCount, subfolderCount: st.subFolders, isRaw: isRaw))
    }
    for url in s.otherFolders {
        let st = stats(url); total += st.size; raw += st.rawCount; jpg += st.jpgCount; tiff += st.tiffCount
        folders.append(FolderInfo(name: url.lastPathComponent, path: url, size: st.size, fileCount: st.count, rawCount: st.rawCount, jpgCount: st.jpgCount, tiffCount: st.tiffCount, subfolderCount: st.subFolders, isRaw: false))
    }
    return ScanResult(totalSize: total, rawCount: raw, jpgCount: jpg, tiffCount: tiff, folders: folders)
}

private func scanGeneric(_ root: URL) -> ScanResult {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else { return ScanResult(totalSize: 0, rawCount: 0, jpgCount: 0, tiffCount: 0, folders: []) }
    var total: Int64 = 0; var raw = 0; var jpg = 0; var tiff = 0; var folders: [FolderInfo] = []
    let rootSt = stats(root, topLevelOnly: true); total += rootSt.size; raw += rootSt.rawCount; jpg += rootSt.jpgCount; tiff += rootSt.tiffCount
    for url in contents {
        var d: ObjCBool = false; fm.fileExists(atPath: url.path, isDirectory: &d); guard d.boolValue else { continue }
        let st = stats(url); total += st.size; raw += st.rawCount; jpg += st.jpgCount; tiff += st.tiffCount
        folders.append(FolderInfo(name: url.lastPathComponent, path: url, size: st.size, fileCount: st.count, rawCount: st.rawCount, jpgCount: st.jpgCount, tiffCount: st.tiffCount, subfolderCount: st.subFolders, isRaw: st.rawCount > 0))
    }
    if rootSt.count > 0 { folders.insert(FolderInfo(name: "Root Files", path: root, size: rootSt.size, fileCount: rootSt.count, rawCount: rootSt.rawCount, jpgCount: rootSt.jpgCount, tiffCount: rootSt.tiffCount, subfolderCount: 0, isRaw: rootSt.rawCount > 0), at: 0) }
    return ScanResult(totalSize: total, rawCount: raw, jpgCount: jpg, tiffCount: tiff, folders: folders.sorted { $0.size > $1.size })
}

private struct FolderStats { var size: Int64 = 0; var count = 0; var rawCount = 0; var jpgCount = 0; var tiffCount = 0; var subFolders = 0 }

private func stats(_ url: URL, topLevelOnly: Bool = false) -> FolderStats {
    let fm = FileManager.default
    var result = FolderStats()
    let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
    if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) {
        result.subFolders = contents.filter { u in var d: ObjCBool = false; fm.fileExists(atPath: u.path, isDirectory: &d); return d.boolValue && !kC1System.contains(u.lastPathComponent) }.count
    }
    if topLevelOnly {
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles) else { return result }
        for f in contents {
            guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true else { continue }
            result.size += Int64(v.fileSize ?? 0); result.count += 1
            let ext = f.pathExtension.lowercased()
            if kRaw.contains(ext) { result.rawCount += 1 }
            if kJpg.contains(ext) { result.jpgCount += 1 }
            if kTiff.contains(ext) { result.tiffCount += 1 }
        }
        return result
    }
    // Size pass — include everything
    if let e = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles) {
        for case let f as URL in e {
            guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true else { continue }
            result.size += Int64(v.fileSize ?? 0)
        }
    }
    // Count pass — exclude CaptureOne
    if let e = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles) {
        for case let f as URL in e {
            if kC1System.contains(f.lastPathComponent) { e.skipDescendants(); continue }
            guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true else { continue }
            result.count += 1
            let ext = f.pathExtension.lowercased()
            if kRaw.contains(ext) { result.rawCount += 1 }
            if kJpg.contains(ext) { result.jpgCount += 1 }
            if kTiff.contains(ext) { result.tiffCount += 1 }
        }
    }
    return result
}

// MARK: - FolderMonitor

@MainActor
class FolderMonitor: ObservableObject {

    enum UpdateState: Equatable {
        case idle, checking, upToDate, error
        case available(version: String, url: URL)
    }

    @Published var sessionMode: SessionMode = .none
    @Published var totalSize: Int64 = 0
    @Published var totalRawCount: Int = 0
    @Published var totalJpgCount: Int = 0
    @Published var totalTiffCount: Int = 0
    @Published var subfolders: [FolderInfo] = []
    @Published var isLoading: Bool = false
    @Published var updateState: UpdateState = .idle
    @Published private(set) var rootPath: URL?

    private var watchSources: [DispatchSourceFileSystemObject] = []
    private let watchQueue = DispatchQueue(label: "com.foldermeter.watcher", qos: .background)
    private var debounceItem: DispatchWorkItem?

    init() {
        if let bookmarkData = UserDefaults.standard.data(forKey: "watchedFolderBookmark") {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if url.startAccessingSecurityScopedResource() {
                    rootPath = url
                    if isStale { Self.saveBookmark(for: url) }
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        } else if let saved = UserDefaults.standard.string(forKey: "watchedFolderPath") {
            let url = URL(fileURLWithPath: saved)
            if FileManager.default.fileExists(atPath: url.path) { rootPath = url }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, let root = self.rootPath else { return }
            self.startScan(root: root)
            self.startWatching(root: root)
        }
    }

    static func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: "watchedFolderBookmark")
            UserDefaults.standard.set(url.path, forKey: "watchedFolderPath")
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }

    // MARK: - Public

    func selectFolder() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.title = "Choose a folder to monitor"
            panel.prompt = "Monitor"
            panel.center()
            panel.begin { [weak self] response in
                NSApp.setActivationPolicy(.accessory)
                NSApp.activate(ignoringOtherApps: true)
                guard let self, response == .OK, let url = panel.url else {
                    NSApp.setActivationPolicy(.accessory)
                    return
                }
                _ = url.startAccessingSecurityScopedResource()
                Self.saveBookmark(for: url)
                self.setRoot(url)
            }
        }
    }

    func clearFolder() {
        stopWatching()
        rootPath?.stopAccessingSecurityScopedResource()
        UserDefaults.standard.removeObject(forKey: "watchedFolderBookmark")
        UserDefaults.standard.removeObject(forKey: "watchedFolderPath")
        rootPath = nil
        sessionMode = .none
        totalSize = 0; totalRawCount = 0; totalJpgCount = 0; totalTiffCount = 0
        subfolders = []
    }

    func forceRefresh() {
        guard let root = rootPath else { return }
        startScan(root: root)
    }

    func checkForUpdates() {
        updateState = .checking
        Task {
            do {
                let url = URL(string: "https://api.github.com/repos/titleunknown/FolderMeter/releases/latest")!
                var req = URLRequest(url: url)
                req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, _) = try await URLSession.shared.data(for: req)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String,
                      let htmlUrl = json["html_url"] as? String,
                      let releaseUrl = URL(string: htmlUrl) else { updateState = .error; return }
                let remote = tag.trimmingCharacters(in: .init(charactersIn: "v"))
                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
                if remote.compare(current, options: .numeric) == .orderedDescending {
                    updateState = .available(version: tag, url: releaseUrl)
                } else {
                    updateState = .upToDate
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if case .upToDate = updateState { updateState = .idle }
                }
            } catch {
                updateState = .error
                print("Update check failed: \(error)")
            }
        }
    }

    // MARK: - Private

    private func setRoot(_ url: URL) {
        stopWatching()
        rootPath = url
        startScan(root: url)
        startWatching(root: url)
    }

    private func startScan(root: URL) {
        isLoading = true
        let r = root
        Task.detached(priority: .userInitiated) { [weak self] in
            let mode = detectMode(root: r)
            let result = scan(mode: mode)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.sessionMode = mode
                self.totalSize = result.totalSize
                self.totalRawCount = result.rawCount
                self.totalJpgCount = result.jpgCount
                self.totalTiffCount = result.tiffCount
                self.subfolders = result.folders
                self.isLoading = false
                self.writeWidgetData()
            }
        }
    }

    private func writeWidgetData() {
        guard let root = rootPath else { return }
        let widgetFolders = subfolders.map { f in
            WidgetFolderInfo(
                name: f.name,
                size: f.size,
                rawCount: f.rawCount,
                jpgCount: f.jpgCount,
                tiffCount: f.tiffCount,
                fileCount: f.fileCount
            )
        }
        let isC1: Bool
        if case .captureOne = sessionMode { isC1 = true } else { isC1 = false }
        let data = FolderWidgetData(
            folderName: root.lastPathComponent,
            totalSize: totalSize,
            rawCount: totalRawCount,
            jpgCount: totalJpgCount,
            tiffCount: totalTiffCount,
            isCaptureOneSession: isC1,
            folders: widgetFolders,
            updatedAt: Date()
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults(suiteName: "group.com.fainimade.foldermeter")?.set(encoded, forKey: "widgetData")
        }
    }

    private func startWatching(root: URL) {
        var dirs: [URL] = [root]
        if let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) {
            for case let url as URL in e {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { dirs.append(url) }
            }
        }
        dirs.forEach { watchDir($0) }
    }

    private func watchDir(_ url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write,.rename,.delete,.extend,.link], queue: watchQueue)
        src.setEventHandler { [weak self] in self?.scheduleRefresh() }
        src.setCancelHandler { close(fd) }
        watchSources.append(src)
        src.resume()
    }

    private func scheduleRefresh() {
        debounceItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let root = self.rootPath else { return }
                self.startScan(root: root)
            }
        }
        debounceItem = work
        watchQueue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func stopWatching() {
        debounceItem?.cancel(); debounceItem = nil
        watchSources.forEach { $0.cancel() }
        watchSources.removeAll()
    }
}
