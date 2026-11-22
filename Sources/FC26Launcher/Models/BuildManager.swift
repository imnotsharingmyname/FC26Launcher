import Foundation
import SwiftUI

/// Manages the build process using pack_app.py
@MainActor
final class BuildManager: ObservableObject {
    static let shared = BuildManager()

    @Published var isBuilding = false
    @Published var buildProgress: Double = 0
    @Published var buildStatus: String = ""
    @Published var buildLog: String = ""
    @Published var lastBuildResult: BuildResult?

    private let gameManager = GameManager.shared
    private let settingsManager = SettingsManager.shared

    private init() {}

    enum BuildResult: Equatable {
        case success(appPath: URL)
        case failure(error: String)
        case cancelled
    }

    func buildGame(enable120FPS: Bool) async {
        guard !isBuilding else { return }
        guard gameManager.buildFolderURL != nil else {
            lastBuildResult = .failure(error: "No build folder selected")
            return
        }

        isBuilding = true
        buildProgress = 0
        buildStatus = "Preparing build..."
        buildLog = ""
        lastBuildResult = nil

        // Apply 120fps patch if enabled
        if enable120FPS {
            await apply120FPSPatch()
        }

        // Run pack_app.py
        await runPackApp()
    }

    private func apply120FPSPatch() async {
        buildStatus = "Applying 120 FPS patch..."
        buildLog += "\n=== Applying 120 FPS Patch ===\n"

        let patchPath = gameManager.buildFolderURL?
            .deletingLastPathComponent() // Go up from build folder
            .appendingPathComponent("extras/source-changes/fc26-120fps-nxnative-65501fbb.patch")

        let nxnativePath = URL(fileURLWithPath: "/Users/faycalelhandi/nxnative")

        guard let patch = patchPath, FileManager.default.fileExists(atPath: patch.path) else {
            buildLog += "⚠️ 120 FPS patch not found at \(patchPath?.path ?? "unknown")\n"
            return
        }

        do {
            // Apply patch using git apply
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            task.arguments = ["apply", patch.path]
            task.currentDirectoryURL = nxnativePath

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            buildLog += output

            if task.terminationStatus == 0 {
                buildLog += "✅ 120 FPS patch applied successfully\n"
            } else {
                buildLog += "⚠️ Patch may have already been applied or failed\n"
            }
        } catch {
            buildLog += "❌ Failed to apply patch: \(error)\n"
        }

        // Also extract new files if needed
        let tarPath = gameManager.buildFolderURL?
            .deletingLastPathComponent()
            .appendingPathComponent("extras/source-changes/fc26-new-files.tar")

        if let tar = tarPath, FileManager.default.fileExists(atPath: tar.path) {
            buildLog += "\nExtracting new files...\n"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            task.arguments = ["xf", tar.path]
            task.currentDirectoryURL = nxnativePath

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            try? task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            buildLog += output
            buildLog += "✅ New files extracted\n"
        }
    }

    private func runPackApp() async {
        buildStatus = "Building game app..."
        buildProgress = 0.2

        guard gameManager.buildFolderURL != nil,
              let patched = gameManager.patchedPath,
              let romfs = gameManager.romfsPath,
              let msl = gameManager.mslPath,
              let tables = gameManager.tablesPath,
              let font = gameManager.fontPath,
              let icon = gameManager.iconPath,
              let dmhost = gameManager.dmhostPath,
              let settings = gameManager.settingsPath else {
            lastBuildResult = .failure(error: "Missing required build paths")
            isBuilding = false
            return
        }

        // Output app location
        let appsFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FC26Launcher/Apps", isDirectory: true)

        try? FileManager.default.createDirectory(at: appsFolder, withIntermediateDirectories: true)

        let appPath = appsFolder.appendingPathComponent("EA-Sports-FC-26.app")

        // Build arguments for pack_app.py
        var args = [
            appPath.path,
            "--host", dmhost.path,
            "--patched", patched.path,
            "--romfs", romfs.path,
            "--msl", msl.path,
            "--tables", tables.path,
            "--font", font.deletingLastPathComponent().path,
            "--title-id", "01004FF021942000",
            "--name", "EA SPORTS FC 26",
            "--version", "1.86.1233",
            "--bundle-id", "com.ea.fc26.mac",
            "--category", "public.app-category.games",
            "--lang", "en-US",
            "--marker", "RomFS.img",
            "--icon", icon.path,
            "--settings", settings.path,
            "--sign", "-"
        ]

        if let aoc = gameManager.aocPath {
            args += ["--aoc", aoc.path]
        }
        if let pso = gameManager.psoPath {
            args += ["--pso", pso.path]
        }

        buildLog += "\n=== Running pack_app.py ===\n"
        buildLog += "Command: python3 \(nxnativePackAppPath()) \(args.joined(separator: " "))\n\n"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        task.arguments = [nxnativePackAppPath()] + args
        task.currentDirectoryURL = URL(fileURLWithPath: "/Users/faycalelhandi/nxnative/dm/mac")

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        // Monitor progress
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.buildLog += output
                    self?.updateProgress(from: output)
                }
            }
        }

        do {
            try task.run()
            task.waitUntilExit()
            handle.readabilityHandler = nil

            let data = handle.readDataToEndOfFile()
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                buildLog += output
            }

            if task.terminationStatus == 0 {
                buildProgress = 1.0
                buildStatus = "Build successful!"
                buildLog += "\n✅ Build completed successfully!\n"
                buildLog += "App location: \(appPath.path)\n"

                gameManager.detectedAppPath = appPath
                lastBuildResult = .success(appPath: appPath)
            } else {
                buildStatus = "Build failed"
                buildLog += "\n❌ Build failed with exit code: \(task.terminationStatus)\n"
                lastBuildResult = .failure(error: "Build failed with exit code \(task.terminationStatus)")
            }
        } catch {
            buildStatus = "Build error"
            buildLog += "\n❌ Build error: \(error)\n"
            lastBuildResult = .failure(error: error.localizedDescription)
        }

        isBuilding = false
    }

    private func updateProgress(from output: String) {
        if output.contains("step: launcher and host") { buildProgress = 0.3 }
        else if output.contains("step: shader libraries") { buildProgress = 0.5 }
        else if output.contains("step: add-on content") { buildProgress = 0.6 }
        else if output.contains("step: pipeline archive") { buildProgress = 0.7 }
        else if output.contains("step: game files") { buildProgress = 0.8 }
        else if output.contains("step: icon") { buildProgress = 0.85 }
        else if output.contains("step: signing") { buildProgress = 0.95 }
        else if output.contains("app:") && output.contains(".app") { buildProgress = 1.0 }
    }

    private func nxnativePackAppPath() -> String {
        return "/Users/faycalelhandi/nxnative/dm/mac/pack_app.py"
    }

    func cancelBuild() {
        // TODO: Implement cancellation
    }
}