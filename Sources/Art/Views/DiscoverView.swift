import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var store: ArtworkStore

    private let columns = [GridItem(.adaptive(minimum: 210, maximum: 300), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(.white.opacity(0.12))

            ScrollView {
                if let message = store.discoverMessage {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(store.discoverArtworks.enumerated()), id: \.element.id) { index, artwork in
                        card(for: artwork, position: index + 1)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 780, minHeight: 640)
        .background(Color(red: 0.075, green: 0.08, blue: 0.11))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Art Library")
                    .font(.system(size: 27, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("Curated masterpieces and accepted discoveries · one mixed rotation")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()

            Button {
                store.discoverMore()
            } label: {
                if store.discoverLoading {
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.small)
                        Text("Discovering…")
                    }
                } else {
                    Label("Add More Art", systemImage: "sparkles")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(ArtTheme.gold)
            .disabled(store.discoverLoading)

            Button {
                store.closeDiscover()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func card(for artwork: Artwork, position: Int) -> some View {
        let isDiscovery = artwork.id.hasPrefix("discovery-")
        return Button {
            store.display(artwork)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [ArtTheme.gold.opacity(0.22), .black.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(.white.opacity(0.38))
                    if isDiscovery, let previewURL = previewURL(for: artwork) {
                        AsyncImage(url: previewURL) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                        }
                    }
                    Text("DAY \(position)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(ArtTheme.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(12)
                    }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()

                VStack(alignment: .leading, spacing: 3) {
                    Text(artwork.title)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(artwork.artist) · \(artwork.years)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func previewURL(for artwork: Artwork) -> URL? {
        guard artwork.imageURL.contains("/thumb/") else { return nil }
        let small = artwork.imageURL.replacingOccurrences(
            of: "/[0-9]+px-",
            with: "/480px-",
            options: .regularExpression
        )
        return URL(string: small)
    }
}
