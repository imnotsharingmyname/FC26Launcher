import Foundation
import SwiftUI

/// Manages game settings from launcher.json and user preferences
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: [GameSetting] = []
    @Published var userPreferences: [String: String] = [:]
    @Published var showAdvanced = false
    @Published var showWindowAtLaunch = true
    @Published var cloudSavesFolder: String = ""
    @Published var enable120FPS = false

    private let prefsDomain = "com.fc26launcher.preferences"
    private let userDefaults = UserDefaults.standard

    private init() {
        loadPreferences()
        loadCloudSavesFolder()
        load120FPS()
    }

    func loadSettings(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(LauncherSettingsFile.self, from: data)
            self.settings = file.settings.map { GameSetting(from: $0) }
            applySavedPreferences()
        } catch {
            print("Failed to load settings: \(error)")
        }
    }

    private func loadPreferences() {
        if let data = userDefaults.data(forKey: "\(prefsDomain).preferences"),
           let prefs = try? JSONDecoder().decode([String: String].self, from: data) {
            userPreferences = prefs
        }
        showWindowAtLaunch = userDefaults.bool(forKey: "\(prefsDomain).showWindowAtLaunch")
        showAdvanced = userDefaults.bool(forKey: "\(prefsDomain).showAdvanced")
    }

    private func loadCloudSavesFolder() {
        cloudSavesFolder = userDefaults.string(forKey: "\(prefsDomain).cloudSavesFolder") ?? ""
    }

    private func load120FPS() {
        enable120FPS = userDefaults.bool(forKey: "\(prefsDomain).enable120FPS")
    }

    func savePreference(_ key: String, value: String) {
        userPreferences[key] = value
        savePreferences()
    }

    func savePreferences() {
        if let data = try? JSONEncoder().encode(userPreferences) {
            userDefaults.set(data, forKey: "\(prefsDomain).preferences")
        }
        userDefaults.set(showWindowAtLaunch, forKey: "\(prefsDomain).showWindowAtLaunch")
        userDefaults.set(showAdvanced, forKey: "\(prefsDomain).showAdvanced")
        userDefaults.set(cloudSavesFolder, forKey: "\(prefsDomain).cloudSavesFolder")
        userDefaults.set(enable120FPS, forKey: "\(prefsDomain).enable120FPS")
    }

    func applySavedPreferences() {
        for setting in settings {
            if let saved = userPreferences["launcher.\(setting.env)"] {
                setting.currentValue = saved
            }
        }
    }

    func resetToDefaults() {
        for setting in settings {
            setting.currentValue = setting.defaultValue
            userPreferences.removeValue(forKey: "launcher.\(setting.env)")
        }
        savePreferences()
    }

    func getLaunchEnvironment() -> [String: String] {
        var env = userPreferences

        // Add 120 FPS if enabled
        if enable120FPS {
            env["DM_FPS_TARGET"] = "120"
            env["DM_FPS_MAX"] = "120"
        }

        // Add cloud saves if set
        if !cloudSavesFolder.isEmpty {
            env["DM_SAVE_SYNC"] = cloudSavesFolder
        }

        // Convert launcher.* keys to actual env vars
        var result: [String: String] = [:]
        for (key, value) in env {
            if key.hasPrefix("launcher.") {
                let envKey = String(key.dropFirst("launcher.".count))
                result[envKey] = value
            }
        }
        return result
    }
}

// MARK: - Models

struct LauncherSettingsFile: Codable {
    let schema: Int
    let game: String
    let settings: [SettingDefinition]
}

struct SettingDefinition: Codable {
    let env: String
    let kind: String
    let section: String
    let label: String
    let note: String?
    let defaultValue: String
    let level: String?
    let options: [[String]]?
    let on: String?
    let off: String?
    let min: Double?
    let max: Double?
    let step: Double?
    let needs: String?

    enum CodingKeys: String, CodingKey {
        case env, kind, section, label, note
        case defaultValue = "default"
        case level, options, on, off, min, max, step, needs
    }
}

@MainActor
final class GameSetting: ObservableObject, Identifiable {
    let id = UUID()
    let env: String
    let kind: SettingKind
    let section: String
    let label: String
    let note: String?
    let defaultValue: String
    let level: String
    let options: [(value: String, label: String)]
    let onValue: String
    let offValue: String
    let minValue: Double
    let maxValue: Double
    let stepValue: Double
    let needs: String?

    @Published var currentValue: String

    init(from def: SettingDefinition) {
        self.env = def.env
        self.kind = SettingKind(rawValue: def.kind) ?? .choice
        self.section = def.section
        self.label = def.label
        self.note = def.note
        self.defaultValue = def.defaultValue
        self.level = def.level ?? "basic"
        self.options = def.options?.map { ($0[0], $0[1]) } ?? []
        self.onValue = def.on ?? "1"
        self.offValue = def.off ?? "0"
        self.minValue = def.min ?? 0
        self.maxValue = def.max ?? 1
        self.stepValue = def.step ?? 1
        self.needs = def.needs
        self.currentValue = def.defaultValue
    }

    var isAdvanced: Bool { level != "basic" }
    var isEnabled: Bool {
        guard let needs = needs else { return true }
        // Simple needs parsing: "DM_RUMBLE=1"
        let parts = needs.split(separator: "=")
        if parts.count == 2 {
            let neededEnv = String(parts[0])
            let neededValue = String(parts[1])
            return userPreferences["launcher.\(neededEnv)"] == neededValue
        }
        return true
    }

    private var userPreferences: [String: String] {
        SettingsManager.shared.userPreferences
    }
}

enum SettingKind: String, Codable {
    case choice, toggle, range
}