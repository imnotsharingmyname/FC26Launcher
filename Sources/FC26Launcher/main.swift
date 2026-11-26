import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
enum LauncherEntryPoint {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        switch arguments.first {
        case "--prepare":
            RecompIntegration.prepare(Array(arguments.dropFirst()))
        case "--play":
            RecompIntegration.play()
        default:
            FC26LauncherApp.main()
        }
    }
}

struct FC26LauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(GameManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(BuildManager.shared)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 700)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
