import AppKit
import SwiftUI

struct BottomInfoView: View {
    @EnvironmentObject private var store: ArtworkStore

    var body: some View {
        let artwork = store.current
        VStack(alignment: .leading, spacing: 0) {
            Text("TODAY'S MASTERPIECE")
                .font(.system(size: 12, weight: .semibold))
                .tracking(3.4)
                .foregroundStyle(ArtTheme.gold)

            Text(artwork.title)
                .font(ArtTheme.serifTitle)
                .foregroundStyle(.white)
                .padding(.top, 8)

            Text("\(artwork.artist) · \(artwork.years)")
                .font(ArtTheme.serifArt)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 4)

            Text(artwork.locationLine)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 3)

            Text("\(artwork.license) · via Wikimedia Commons")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 6)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
