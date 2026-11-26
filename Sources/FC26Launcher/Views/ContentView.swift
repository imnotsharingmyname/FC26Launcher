import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var buildManager: BuildManager

    @State private var selectedTab: Tab = .game
    @State private var showBuildSheet = false
    @State private var showSettingsSheet = false

    enum Tab: String, CaseIterable, Identifiable {
        case game = "Game"
        case settings = "Settings"
        case mods = "Mods"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .game: return "gamecontroller.fill"
            case .settings: return "gearshape.fill"
            case .mods: return "puzzlepiece.extension.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(Tab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .listStyle(.sidebar)
        } detail: {
            // Detail view
            Group {
                switch selectedTab {
                case .game:
                    GameTabView()
                case .settings:
                    SettingsTabView()
                case .mods:
                    ModsTabView()
                case .about:
                    AboutTabView()
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if gameManager.buildFolderURL == nil {
                    Button(action: { gameManager.selectBuildFolder() }) {
                        Label("Select Build Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: { showBuildSheet = true }) {
                        Label("Build", systemImage: "hammer.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(buildManager.isBuilding)

                    if gameManager.detectedAppPath != nil {
                        Button(action: launchGame) {
                            Label("Launch", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(buildManager.isBuilding)
                    }
                }
            }
        }
        .sheet(isPresented: $showBuildSheet) {
            BuildSheetView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView()
        }
        .alert("Error", isPresented: .constant(gameManager.buildStatus == .invalid(errors: []))) {
            Button("OK") { gameManager.buildStatus = .notSelected }
        } message: {
            if case .invalid(let errors) = gameManager.buildStatus {
                Text(errors.joined(separator: "\n"))
            }
        }
    }

    private func launchGame() {
        Task {
            do {
                let env = settingsManager.getLaunchEnvironment()
                try await gameManager.launchGame(with: env)
            } catch {
                // Error handled by GameManager
                print("Launch error: \(error)")
            }
        }
    }
}

// MARK: - Tab Views

struct GameTabView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var buildManager: BuildManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                // Build folder selection
                buildFolderSection

                // Build status
                if gameManager.buildFolderURL != nil {
                    buildStatusSection
                }

                // Detected app
                if let appPath = gameManager.detectedAppPath {
                    detectedAppSection(appPath)
                }

                // Build log
                if buildManager.isBuilding || buildManager.lastBuildResult != nil {
                    buildLogSection
                }
            }
            .padding(24)
        }
        .navigationTitle("Game")
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)
                VStack(alignment: .leading) {
                    Text("EA SPORTS FC 26")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Switch Recompiled for Mac")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
        }
    }

    var buildFolderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Build Folder", systemImage: "folder")
                .font(.headline)

            if let url = gameManager.buildFolderURL {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    Text(url.path)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Change") {
                        gameManager.selectBuildFolder()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Button(action: { gameManager.selectBuildFolder() }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Select Build Folder (01004FF021942000_build)")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    var buildStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Build Status", systemImage: "checkmark.shield")
                .font(.headline)

            HStack {
                statusIndicator
                Text(statusText)
                    .font(.subheadline)
                Spacer()
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if case .invalid(let errors) = gameManager.buildStatus {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(errors, id: \.self) { error in
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    var statusColor: Color {
        switch gameManager.buildStatus {
        case .notSelected: .gray
        case .validating: .orange
        case .valid: .green
        case .invalid: .red
        }
    }

    var statusText: String {
        switch gameManager.buildStatus {
        case .notSelected: "No folder selected"
        case .validating: "Validating..."
        case .valid: "Build folder valid ✓"
        case .invalid: "Invalid build folder"
        }
    }

    func detectedAppSection(_ appPath: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Built App", systemImage: "app.fill")
                .font(.headline)

            HStack {
                Image(systemName: "app.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("EA SPORTS FC 26")
                        .font(.headline)
                    Text(appPath.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var buildLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Build Log", systemImage: "doc.text.fill")
                    .font(.headline)
                Spacer()
                if buildManager.isBuilding {
                    ProgressView()
                        .controlSize(.small)
                    Text("Building...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let result = buildManager.lastBuildResult {
                    switch result {
                    case .success: Label("Success", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .failure: Label("Failed", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                    case .cancelled: Label("Cancelled", systemImage: "stop.circle.fill").foregroundStyle(.orange)
                    }
                }
            }

            ScrollView {
                Text(buildManager.buildLog.isEmpty ? "No build log yet" : buildManager.buildLog)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 200)
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct SettingsTabView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var gameManager: GameManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if settingsManager.settings.isEmpty {
                    ContentUnavailableView(
                        "No Settings Loaded",
                        systemImage: "gearshape",
                        description: Text("Select a valid build folder to load game settings")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    settingsContent
                }
            }
            .padding(24)
        }
        .navigationTitle("Settings")
        .onChange(of: gameManager.settingsPath) { _, newPath in
            if let path = newPath {
                settingsManager.loadSettings(from: path)
            }
        }
    }

    var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Show at launch toggle
            Toggle("Show settings window at launch", isOn: $settingsManager.showWindowAtLaunch)
                .onChange(of: settingsManager.showWindowAtLaunch) { _, _ in
                    settingsManager.savePreferences()
                }

            Divider()

            // Basic settings
            settingsSection(title: "Basic Settings", settings: settingsManager.settings.filter { !$0.isAdvanced })

            // Advanced settings
            DisclosureGroup("Advanced Settings", isExpanded: $settingsManager.showAdvanced) {
                settingsSection(title: "", settings: settingsManager.settings.filter { $0.isAdvanced })
            }

            Divider()

            // Reset button
            Button("Reset to Tested Defaults") {
                settingsManager.resetToDefaults()
            }
            .buttonStyle(.bordered)
            .disabled(!settingsManager.settings.contains { $0.currentValue != $0.defaultValue })
        }
    }

    func settingsSection(title: String, settings: [GameSetting]) -> some View {
        Group {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            ForEach(settings) { setting in
                if setting.isEnabled {
                    SettingRowView(setting: setting)
                }
            }
        }
    }
}

struct SettingRowView: View {
    @ObservedObject var setting: GameSetting
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(setting.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let note = setting.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                controlView
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    var controlView: some View {
        switch setting.kind {
        case .choice:
            Picker("", selection: Binding(
                get: { setting.currentValue },
                set: { newValue in
                    setting.currentValue = newValue
                    settingsManager.savePreference("launcher.\(setting.env)", value: newValue)
                }
            )) {
                ForEach(setting.options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)

        case .toggle:
            Toggle("", isOn: Binding(
                get: { setting.currentValue == setting.onValue },
                set: { newValue in
                    setting.currentValue = newValue ? setting.onValue : setting.offValue
                    settingsManager.savePreference("launcher.\(setting.env)", value: setting.currentValue)
                }
            ))
            .labelsHidden()

        case .range:
            HStack {
                Slider(
                    value: Binding(
                        get: { Double(setting.currentValue) ?? setting.minValue },
                        set: { newValue in
                            let str = String(format: "%.1f", newValue)
                            setting.currentValue = str
                            settingsManager.savePreference("launcher.\(setting.env)", value: str)
                        }
                    ),
                    in: setting.minValue...setting.maxValue,
                    step: setting.stepValue
                )
                .frame(width: 150)
                Text(setting.currentValue)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

struct ModsTabView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var buildManager: BuildManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 120 FPS Mod
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange.gradient)
                        VStack(alignment: .leading) {
                            Text("120 FPS Mod")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Enable 120 FPS gameplay on supported displays")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settingsManager.enable120FPS)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: settingsManager.enable120FPS) { _, _ in
                                settingsManager.savePreferences()
                            }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Requires:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("• ProMotion display (120 Hz)")
                            .font(.caption)
                        Text("• 120 FPS patch applied during build")
                            .font(.caption)
                        Text("• Game rebuild after enabling")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if settingsManager.enable120FPS {
                        Text("✅ 120 FPS will be enabled on next build")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(20)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Future mods placeholder
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Mods")
                        .font(.headline)

                    ModCard(
                        title: "60 FPS (Default)",
                        description: "Standard 60 FPS gameplay with regulator margin fix",
                        icon: "60.square.fill",
                        color: .blue,
                        isEnabled: !settingsManager.enable120FPS
                    )

                    ModCard(
                        title: "MetalFX Upscaling",
                        description: "AI upscaling for better visual quality (uses more GPU)",
                        icon: "sparkles.rectangle.stack.fill",
                        color: .purple,
                        isEnabled: false
                    )

                    ModCard(
                        title: "Xbox Button Layout",
                        description: "Xbox-style button mapping for all controllers",
                        icon: "gamecontroller.fill",
                        color: .green,
                        isEnabled: true
                    )

                    ModCard(
                        title: "Second Controller Fix",
                        description: "Fixes DualSense/Xbox second controller detection",
                        icon: "gamecontroller.2.fill",
                        color: .orange,
                        isEnabled: true
                    )
                }

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Mods")
    }
}

struct ModCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color.gradient)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isEnabled ? color : .secondary)
                .font(.title3)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AboutTabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App info
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)

                    Text("FC 26 Launcher")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Version 1.0.0")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("A macOS launcher for EA SPORTS FC 26 Switch recompiled to run natively on Apple Silicon.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)

                Divider()

                // Credits
                VStack(alignment: .leading, spacing: 16) {
                    Text("Based on")
                        .font(.headline)

                    Link("nxnative", destination: URL(string: "https://github.com/seedds/nxnative")!)
                    Text("by seedds - Play your own Nintendo Switch games natively on Apple devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("Game")
                        .font(.headline)

                    Link("EA SPORTS FC 26", destination: URL(string: "https://www.ea.com/games/ea-sports-fc")!)
                    Text("© Electronic Arts Inc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("This launcher is an open-source project for educational purposes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link("View on GitHub", destination: URL(string: "https://github.com/imnotsharingmyname/FC26Launcher")!)
                        .font(.caption)
                }
            }
            .padding(24)
        }
        .navigationTitle("About")
    }
}

// MARK: - Sheet Views

struct BuildSheetView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var buildManager: BuildManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Build Game App")
                .font(.title2)
                .fontWeight(.bold)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("This will create a standalone .app bundle using pack_app.py")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Toggle("Enable 120 FPS Mod", isOn: $settingsManager.enable120FPS)
                    .onChange(of: settingsManager.enable120FPS) { _, _ in
                        settingsManager.savePreferences()
                    }

                if settingsManager.enable120FPS {
                    Text("Applies the 120 FPS patch from nxnative before building")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if buildManager.isBuilding {
                VStack(spacing: 12) {
                    ProgressView(value: buildManager.buildProgress)
                        .frame(width: 300)
                    Text(buildManager.buildStatus)
                        .font(.subheadline)
                    Text("\(Int(buildManager.buildProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .disabled(buildManager.isBuilding)

                if !buildManager.isBuilding {
                    Button("Build") {
                        Task {
                            await buildManager.buildGame(enable120FPS: settingsManager.enable120FPS)
                            if case .success = buildManager.lastBuildResult {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(gameManager.buildStatus != .valid)
                } else {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(30)
        .frame(width: 450)
    }
}

struct SettingsSheetView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Toggle("Show settings window at launch", isOn: $settingsManager.showWindowAtLaunch)
                    Toggle("Show advanced settings by default", isOn: $settingsManager.showAdvanced)
                }

                Section("Cloud Saves") {
                    Text("Sync saves with iOS app via iCloud Drive")
                    HStack {
                        Text(settingsManager.cloudSavesFolder.isEmpty ? "Not configured" : settingsManager.cloudSavesFolder)
                            .foregroundStyle(settingsManager.cloudSavesFolder.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Choose Folder") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            panel.prompt = "Use for Cloud Saves"
                            if panel.runModal() == .OK, let url = panel.url {
                                settingsManager.cloudSavesFolder = url.path
                                settingsManager.savePreferences()
                            }
                        }
                    }
                    if !settingsManager.cloudSavesFolder.isEmpty {
                        Button("Turn Off") {
                            settingsManager.cloudSavesFolder = ""
                            settingsManager.savePreferences()
                        }
                    }
                }

                Section("120 FPS Mod") {
                    Toggle("Enable 120 FPS", isOn: $settingsManager.enable120FPS)
                    if settingsManager.enable120FPS {
                        Text("Requires ProMotion display and rebuild")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
