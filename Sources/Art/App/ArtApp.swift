import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--set-wallpaper") {
            NSApp.setActivationPolicy(.accessory)
            // Headless daily run: hide the window, change the wallpaper, quit.
            Task { @MainActor in
                NSApp.windows.forEach { $0.orderOut(nil) }
                await ArtworkStore.shared.setTodayWallpaperAndQuit()
            }
        } else {
            // Art lives in the menu bar. The gallery window is opened on demand.
            NSApp.setActivationPolicy(.accessory)
            hideInitialGalleryWindow()
            // SwiftUI may finish restoring the scene one run-loop turn later.
            DispatchQueue.main.async { [weak self] in
                self?.hideInitialGalleryWindow()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func hideInitialGalleryWindow() {
        NSApp.windows
            .filter { $0.identifier?.rawValue == "gallery" || $0.title == "Art Gallery" }
            .forEach { $0.orderOut(nil) }
    }
}

@main
struct ArtApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ArtworkStore.shared

    var body: some Scene {
        Window("Art Gallery", id: "gallery") {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Artwork") {
                    store.nextArtwork()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Open Artwork Page") {
                    store.openPage()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button(store.wallpaperState == .done ? "Wallpaper Set ✓" : "Set as Wallpaper") {
                    store.setAsWallpaper()
                }
                .keyboardShortcut("w", modifiers: [.command, .option])

                Button("Find a Masterpiece") {
                    NotificationCenter.default.post(name: .artSearchFocus, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Divider()

                Button(store.updateInstalled ? "Remove Daily 9 AM Wallpaper Update" : "Install Daily 9 AM Wallpaper Update") {
                    store.toggleDailyUpdate()
                }
            }
        }

        MenuBarExtra {
            ArtMenuBarView()
                .environmentObject(store)
        } label: {
            Label("Art", systemImage: "paintpalette.fill")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
