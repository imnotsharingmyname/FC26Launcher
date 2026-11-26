import Darwin
import Foundation

enum RecompIntegration {
    static func prepare(_ arguments: [String]) -> Never {
        guard let script = Bundle.main.url(forResource: "prepare-fc26", withExtension: "py") else {
            fail("The setup script is missing. Reinstall FC 26 Launcher.")
        }
        let environment = ProcessInfo.processInfo.environment
        let virtualEnv = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("nxnative/.venv/bin/python3").path
        let defaultPython = FileManager.default.isExecutableFile(atPath: virtualEnv) ? virtualEnv : "python3"
        let python = environment["FC26_PYTHON"] ?? defaultPython
        setenv("PATH", "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin"), 1)
        execute("/usr/bin/env", [python, script.path] + arguments)
    }

    static func play() -> Never {
        do {
            guard let path = ProcessInfo.processInfo.environment["RECOMPLAUNCHER_DATA"], path.hasPrefix("/") else {
                fail("The RecompLauncher data path is missing. Start the game from RecompLauncher.")
            }
            let data = URL(fileURLWithPath: path, isDirectory: true)
            let app = data.appendingPathComponent("EA-Sports-FC-26.app")
            let executable = app.appendingPathComponent("Contents/MacOS/nxnative")
            let files = FileManager.default
            guard files.fileExists(atPath: data.appendingPathComponent("prepared").path),
                  files.isExecutableFile(atPath: executable.path),
                  files.isExecutableFile(atPath: app.appendingPathComponent("Contents/MacOS/dmhost").path),
                  files.isReadableFile(atPath: app.appendingPathComponent("Contents/Resources/romfs.img").path) else {
                fail("FC 26 is not ready. Run Easy Setup again in RecompLauncher.")
            }

            let settings = try JSONDecoder().decode(LauncherSettingsFile.self, from: Data(
                contentsOf: app.appendingPathComponent("Contents/Resources/dm/launcher.json")
            ))
            let config = data.appendingPathComponent("settings.json")
            let overrides = files.fileExists(atPath: config.path)
                ? try JSONSerialization.jsonObject(with: Data(contentsOf: config)) as? [String: Any]
                : nil
            let fullScreen = ProcessInfo.processInfo.environment["RECOMPLAUNCHER_MODE"] == "bigpicture"
            setenv("DM_FULLSCREEN", fullScreen ? "1" : "0", 1)
            for setting in settings.settings {
                let settingValue = overrides?[setting.env]
                guard let value = settingValue as? String ?? (settingValue as? NSNumber)?.stringValue,
                      accepts(value, for: setting) else { continue }
                setenv(setting.env, value, 1)
            }

            // nxnative derives its log path from HOME, with explicit paths for saves and runtime data.
            for (key, folder) in [
                ("HOME", "runtime-home"), ("DM_SAVE", "saves"),
                ("DM_ROOT", "cache/runtime"), ("DM_TEMP", "cache/runtime/temp")
            ] {
                let location = data.appendingPathComponent(folder)
                try files.createDirectory(at: location, withIntermediateDirectories: true)
                setenv(key, location.path, 1)
            }
            setenv("DM_SAVED_CHOICES", "0", 1)
            execute(executable.path, ["--no-launcher"])
        } catch {
            fail("Could not start FC 26: \(error.localizedDescription)")
        }
    }

    private static func accepts(_ value: String, for setting: SettingDefinition) -> Bool {
        switch setting.kind {
        case "choice":
            return setting.options?.contains { $0.first == value } == true
        case "toggle":
            return value == setting.on || value == setting.off
        case "range":
            guard let number = Double(value), let min = setting.min, let max = setting.max else { return false }
            return number >= min && number <= max
        default:
            return false
        }
    }

    private static func execute(_ path: String, _ arguments: [String]) -> Never {
        var argv: [UnsafeMutablePointer<CChar>?] = ([path] + arguments).map { strdup($0) }
        argv.append(nil)
        _ = argv.withUnsafeMutableBufferPointer { execv(path, $0.baseAddress!) }
        fail("Could not run \(path): \(String(cString: strerror(errno)))")
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
