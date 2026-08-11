import SwiftUI

struct TopBarView: View {
    @EnvironmentObject private var store: ArtworkStore
    @FocusState.Binding var searchFocused: Bool
    @AppStorage("zoomToFill") private var zoomToFill = true
    @Environment(\.openSettings) private var openSettings

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: Date())
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: Date()))"
    }

    var body: some View {
        HStack(spacing: 16) {
            Text("Art")
                .font(.system(size: 23, weight: .semibold, design: .serif))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.65))
                TextField("Find a masterpiece, artist, museum…", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(width: 300)
            .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )

            Spacer()

            HStack(spacing: 10) {
                iconButton("chevron.left", help: "Previous Artwork") {
                    store.previousArtwork()
                }

                iconButton("arrow.triangle.2.circlepath", help: "New Artwork (⌘N)") {
                    store.nextArtwork()
                }

                iconButton("rectangle.grid.2x2", help: "Open Art Library") {
                    store.openDiscover()
                }

                if store.wallpaperState == .working {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 28, height: 28)
                } else {
                    iconButton(
                        store.wallpaperState == .done ? "checkmark.circle.fill" : "photo.on.rectangle.angled",
                        help: store.wallpaperState == .done ? "Wallpaper set — click to re-apply (⌥⌘W)" : "Set as Wallpaper (⌥⌘W)"
                    ) {
                        store.setAsWallpaper()
                    }
                }

                iconButton("safari", help: "Open Artwork Page (⌘O)") {
                    store.openPage()
                }

                iconButton(
                    store.updateInstalled ? "checkmark.circle.fill" : "clock.badge",
                    help: store.updateInstalled ? "Remove Daily 9 AM Wallpaper" : "Install Daily 9 AM Wallpaper",
                    tint: store.updateInstalled ? ArtTheme.gold : .white.opacity(0.85)
                ) {
                    store.toggleDailyUpdate()
                }

                iconButton("gearshape", help: "Settings (⌘,)") {
                    openSettings()
                }

                Button {
                    zoomToFill.toggle()
                } label: {
                    Image(systemName: zoomToFill ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(.black.opacity(0.38), in: Circle())
                }
                .buttonStyle(.plain)
                .help(zoomToFill ? "Fit the whole artwork" : "Fill the window")

                Text(dateText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text(dayNumber)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(ArtTheme.gold)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.38))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(ArtTheme.gold.opacity(0.8), lineWidth: 1.5))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.62), .black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func iconButton(
        _ systemImage: String,
        help: String,
        tint: Color = .white.opacity(0.85),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.38), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
