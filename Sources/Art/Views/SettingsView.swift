import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ArtworkStore
    @AppStorage("applyToAllDisplays") private var applyToAllDisplays = true
    @AppStorage("zoomToFill") private var zoomToFill = true
    @AppStorage("updateHour") private var updateHour = 9
    @AppStorage("updateMinute") private var updateMinute = 0

    var body: some View {
        TabView {
            Form {
                Section("Wallpaper") {
                    Toggle("Fill the screen by default", isOn: $zoomToFill)
                    Toggle("Apply to all connected displays", isOn: $applyToAllDisplays)
                    Text("Portraits, sculpture and square works are preserved in full with a softened edge-to-edge background. Turn on Fill only when you prefer cropping.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Sacred Christian art is central, alongside a selective group of inspiring masterpieces from Michelangelo, Raphael, Bernini, Caravaggio and others.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("The collection is hand-curated and follows a fixed daily rotation. Images are cached after their first use.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Discover More searches Wikimedia Commons only when requested. Accepted, deduplicated works are saved and mixed into the daily rotation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Lock screen") {
                    Label {
                        Text("macOS uses your desktop wallpaper for the current user's lock screen. The FileVault pre-login screen is managed by macOS and can't be safely customized by apps.")
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(ArtTheme.gold)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "paintbrush") }

            Form {
                Section("Daily update") {
                    DatePicker("Update at", selection: updateTime, displayedComponents: .hourAndMinute)

                    HStack {
                        Label(
                            store.updateInstalled ? "Automatic updates are on" : "Automatic updates are off",
                            systemImage: store.updateInstalled ? "checkmark.circle.fill" : "pause.circle"
                        )
                        .foregroundStyle(store.updateInstalled ? ArtTheme.gold : .secondary)
                        Spacer()
                        Button(store.updateInstalled ? "Turn Off" : "Turn On") {
                            store.toggleDailyUpdate()
                        }
                        .disabled(store.updateInstallBusy)
                    }
                }

                Text("Updates use a lightweight macOS LaunchAgent, so Art doesn't need to stay open. If your Mac is asleep at the scheduled time, macOS runs the update after it wakes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .tabItem { Label("Schedule", systemImage: "clock") }
        }
        .frame(width: 520, height: 330)
    }

    private var updateTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: updateHour, minute: updateMinute)) ?? Date()
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            updateHour = components.hour ?? 9
            updateMinute = components.minute ?? 0
            store.refreshInstalledSchedule()
        }
    }
}
