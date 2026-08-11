import SwiftUI

enum ArtTheme {
    static let gold = Color(red: 0.85, green: 0.70, blue: 0.38)
    static let goldDim = Color(red: 0.85, green: 0.70, blue: 0.38).opacity(0.75)

    static let serifTitle = Font.system(size: 38, weight: .semibold, design: .serif)
    static let serifArt = Font.system(size: 21, weight: .medium, design: .serif)

    /// A dark, deterministic backdrop used while an image loads or fails.
    static func backdrop(for artwork: Artwork) -> LinearGradient {
        let hash = abs(artwork.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) })
        let top = Color(hue: Double(hash % 360) / 360.0, saturation: 0.22, brightness: 0.16)
        let bottom = Color(hue: Double((hash / 37) % 360) / 360.0, saturation: 0.30, brightness: 0.07)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}

extension Notification.Name {
    static let artSearchFocus = Notification.Name("art.searchFocus")
    static let artInstallChanged = Notification.Name("art.installChanged")
}
