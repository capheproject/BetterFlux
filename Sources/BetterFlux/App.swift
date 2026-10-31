import Carbon
import SwiftUI

@main
struct BetterFluxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var controller = Controller.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView(c: controller)
        } label: {
            Image(systemName: controller.iconName)
        }
        .menuBarExtraStyle(.window)

        Window("BetterFlux Settings", id: "settings") {
            SettingsView(c: controller)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let c = Controller.shared
        c.start()

        // ⌃⌥⌘↓ dim, ⌃⌥⌘↑ brighten, ⌃⌥⌘0 back to full brightness.
        let mods = controlKey | optionKey | cmdKey
        HotKeys.register(keyCode: kVK_DownArrow, modifiers: mods) { c.nudgeBrightness(-0.05) }
        HotKeys.register(keyCode: kVK_UpArrow, modifiers: mods) { c.nudgeBrightness(0.05) }
        HotKeys.register(keyCode: kVK_ANSI_0, modifiers: mods) { c.brightness = 1 }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Gamma.restore()
    }
}

