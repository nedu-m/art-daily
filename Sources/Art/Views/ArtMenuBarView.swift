import AppKit
import SwiftUI

struct ArtMenuBarView: View {
    @EnvironmentObject private var store: ArtworkStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(store.menuArtworkTitle)
        Text("\(store.collectionCount) inspiring works available")

        Divider()

        Button("New Artwork") {
            store.nextArtwork()
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("Previous Artwork") {
            store.previousArtwork()
        }

        Button("Set as Wallpaper") {
            store.setAsWallpaper()
        }
        .keyboardShortcut("w", modifiers: [.command, .option])

        Button("Open Artwork Page") {
            store.openPage()
        }
        .keyboardShortcut("o", modifiers: .command)

        if store.wallpaperState == .working {
            Text("Updating wallpaper…")
        } else if store.wallpaperState == .failed {
            Text("Wallpaper update failed")
        }

        Button("Browse Collection…") {
            store.openDiscover()
            openWindow(id: "gallery")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button(store.updateInstalled ? "Daily Update: On" : "Turn On Daily Update") {
            store.toggleDailyUpdate()
        }
        .disabled(store.updateInstallBusy)

        Text(store.updateInstalled ? "Updates at \(store.formattedUpdateTime)" : "Automatic updates are off")

        Divider()

        Button("Settings…") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit Art") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
