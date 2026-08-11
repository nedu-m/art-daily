import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ArtworkStore
    @State private var image: NSImage?
    @State private var loadFailed = false
    @FocusState private var searchFocused: Bool
    @AppStorage("zoomToFill") private var zoomToFill = true

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
            ArtTheme.backdrop(for: store.current)
                .ignoresSafeArea()

            if let image {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: zoomToFill ? 0 : 28)
                        .scaleEffect(zoomToFill ? 1 : 1.08)
                        .overlay(.black.opacity(zoomToFill ? 0 : 0.48))

                    if !zoomToFill {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                            .shadow(color: .black.opacity(0.55), radius: 24, y: 10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
            } else if loadFailed {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Offline — artwork will appear once you're back online.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            LinearGradient(
                colors: [.black.opacity(0.6), .clear, .clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBarView(searchFocused: $searchFocused)
                Spacer()
                BottomInfoView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let notice = store.notice {
                NoticeView(notice: notice) {
                    withAnimation(.easeOut(duration: 0.18)) { store.notice = nil }
                }
                .padding(.top, 76)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(3)
            }

            if !store.searchText.isEmpty {
                SearchPanelView()
                    .padding(.top, 74)
                    .padding(.leading, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
        .frame(minWidth: 940, minHeight: 640)
        .task(id: store.current.id) {
            await loadCurrentArtwork()
        }
        .onReceive(NotificationCenter.default.publisher(for: .artSearchFocus)) { _ in
            searchFocused = true
        }
        .sheet(isPresented: $store.discoverOpen) {
            DiscoverView()
                .environmentObject(store)
        }
        .animation(.easeInOut(duration: 0.22), value: store.notice)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func loadCurrentArtwork() async {
        image = nil
        loadFailed = false
        do {
            image = try await ArtworkImageStore.shared.image(for: store.current)
        } catch {
            loadFailed = true
        }
    }
}

private struct NoticeView: View {
    let notice: ArtworkStore.Notice
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(notice.isError ? .orange : ArtTheme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title).font(.system(size: 13, weight: .semibold))
                Text(notice.message).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Button(action: dismiss) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }
}
