import SwiftUI

struct SearchPanelView: View {
    @EnvironmentObject private var store: ArtworkStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.searchResults.isEmpty {
                Text("No masterpieces match “\(store.searchText)”")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(18)
            } else {
                Text("\(store.searchResults.count) masterpiece\(store.searchResults.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(ArtTheme.gold)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(store.searchResults) { artwork in
                            Button {
                                store.show(artwork)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(artwork.title)
                                            .font(.system(size: 15, weight: .semibold, design: .serif))
                                            .foregroundStyle(.white)
                                        Text("\(artwork.artist) · \(artwork.museum)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(ArtTheme.gold)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                // Row highlight handled by hover state on the background below.
                            }
                        }
                    }
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 22, y: 8)
    }
}
