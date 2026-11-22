import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Manages the FC 26 game installation, build folder detection, and launch
@MainActor
final class GameManager: ObservableObject {
    static let shared = GameManager()

    @Published var buildFolderURL: URL? {
        didSet {
            if let url = buildFolderURL {
                do {
                    let bookmark = try url.bookmarkData()
                    UserDefaults.standard.set(bookmark, forKey: "FC26BuildFolderBookmark")
                } catch {
                    print("Failed to create bookmark: \(error)")
                }
                validateBuildFolder()
            } else {
                UserDefaults.standard.removeObject(forKey: "FC26BuildFolderBookmark")
                buildStatus = .notSelected
            }
        }
    }

    @Published var buildStatus: BuildStatus = .notSelected
    @Published var validationErrors: [String] = []
    @Published var detectedAppPath: URL?

    // Required paths for building
    @Published var patchedPath: URL?
    @Published var romfsPath: URL?
    @Published var mslPath: URL?
    @Published var tablesPath: URL?
    @Published var fontPath: URL?
    @Published var iconPath: URL?
    @Published var dmhostPath: URL?
    @Published var settingsPath: URL?
    @Published var aocPath: URL?
    @Published var psoPath: URL?

    private init() {
        restoreBookmark()
    }

    enum BuildStatus: Equatable {
        case notSelected
        case validating
        case valid
        case invalid(errors: [String])
    }

    func restoreBookmark() {
        if let bookmarkData = UserDefaults.standard.data(forKey: "FC26BuildFolderBookmark") {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if !isStale && FileManager.default.fileExists(atPath: url.path) {
                    buildFolderURL = url
                }
            } catch {
                print("Failed to restore bookmark: \(error)")
            }
        }
    }

    func selectBuildFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select FC 26 Build Folder"
        panel.message = "Choose the '01004FF021942000_build' folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Build Folder"
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("NSP GAMES/FC 26")

        if panel.runModal() == .OK, let url = panel.url {
            buildFolderURL = url
        }
    }

    func validateBuildFolder() {
        guard let buildFolder = buildFolderURL else {
            buildStatus = .notSelected
            return
        }

        buildStatus = .validating
        validationErrors = []

        // Check required paths
        let patched = buildFolder.appendingPathComponent("patched_v1179648")
        let romfs = buildFolder.appendingPathComponent("extract/v1179648/RomFS.img")
        let msl = buildFolder.appendingPathComponent("shader/pkg")
        let tables = buildFolder.appendingPathComponent("app") // launcher.json is here
        let font = buildFolder.appendingPathComponent("font/nintendo_ext.ttf")
        let icon = buildFolder.appendingPathComponent("extract/v1179648/icon.jpg")
        let dmhost = buildFolder.appendingPathComponent("tools/dmhost")
        let settings = buildFolder.appendingPathComponent("app/launcher.json")

        var errors: [String] = []

        if !FileManager.default.fileExists(atPath: patched.path) {
            errors.append("Patched modules not found: \(patched.path)")
        }
        if !FileManager.default.fileExists(atPath: romfs.path) {
            errors.append("RomFS not found: \(romfs.path)")
        }
        if !FileManager.default.fileExists(atPath: msl.path) {
            errors.append("Shader libraries not found: \(msl.path)")
        }
        if !FileManager.default.fileExists(atPath: tables.path) {
            errors.append("Game profile not found: \(tables.path)")
        }
        if !FileManager.default.fileExists(atPath: font.path) {
            errors.append("Font not found: \(font.path)")
        }
        if !FileManager.default.fileExists(atPath: icon.path) {
            errors.append("Icon not found: \(icon.path)")
        }
        if !FileManager.default.fileExists(atPath: dmhost.path) {
            errors.append("dmhost not found: \(dmhost.path)")
        }
        if !FileManager.default.fileExists(atPath: settings.path) {
            errors.append("Settings (launcher.json) not found: \(settings.path)")
        }

        // Optional paths
        let aoc = buildFolder.appendingPathComponent("aoc")
        let pso = buildFolder.appendingPathComponent("pso")

        if errors.isEmpty {
            self.patchedPath = patched
            self.romfsPath = romfs
            self.mslPath = msl
            self.tablesPath = tables
            self.fontPath = font
            self.iconPath = icon
            self.dmhostPath = dmhost
            self.settingsPath = settings
            self.aocPath = FileManager.default.fileExists(atPath: aoc.path) ? aoc : nil
            self.psoPath = FileManager.default.fileExists(atPath: pso.path) ? pso : nil
            self.buildStatus = .valid

            // Check for existing app
            let appsFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("FC26Launcher/Apps")
            let appPath = appsFolder.appendingPathComponent("EA-Sports-FC-26.app")
            if FileManager.default.fileExists(atPath: appPath.path) {
                detectedAppPath = appPath
            }
        } else {
            self.buildStatus = .invalid(errors: errors)
            self.validationErrors = errors
        }
    }

    func launchGame(with settings: [String: String]) async throws {
        guard let appPath = detectedAppPath else {
            throw GameError.appNotBuilt
        }

        // Build environment from settings
        var env = ProcessInfo.processInfo.environment
        for (key, value) in settings {
            env[key] = value
        }

        let task = Process()
        task.executableURL = appPath.appendingPathComponent("Contents/MacOS/nxnative").absoluteURL
        task.environment = env

        // Capture output for logging
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        // Don't wait - game runs independently
    }

    enum GameError: LocalizedError {
        case appNotBuilt
        case launchFailed(String)

        var errorDescription: String? {
            switch self {
            case .appNotBuilt: return "Game app not built yet. Please build first."
            case .launchFailed(let msg): return "Launch failed: \(msg)"
            }
        }
    }
}