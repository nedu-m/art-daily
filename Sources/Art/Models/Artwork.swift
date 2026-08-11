import Foundation

/// A single curated masterpiece shown by the app.
struct Artwork: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let artist: String
    let years: String
    let museum: String
    let city: String
    let country: String
    let imageURL: String
    let pageURL: String
    let license: String
    /// Optional fractional crop rect (x, y, w, h in 0...1, origin top-left).
    /// When present, the artwork is framed to this region before display.
    let crop: [Double]?

    var locationLine: String {
        let place = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
        return place.isEmpty ? museum : "\(museum) · \(place)"
    }

    func cropped(to crop: [Double]) -> Artwork {
        Artwork(
            id: id,
            title: title,
            artist: artist,
            years: years,
            museum: museum,
            city: city,
            country: country,
            imageURL: imageURL,
            pageURL: pageURL,
            license: license,
            crop: crop
        )
    }

    func replacingImageURL(_ imageURL: String, id newID: String? = nil) -> Artwork {
        Artwork(
            id: newID ?? id,
            title: title,
            artist: artist,
            years: years,
            museum: museum,
            city: city,
            country: country,
            imageURL: imageURL,
            pageURL: pageURL,
            license: license,
            crop: crop
        )
    }

    func removingCrop() -> Artwork {
        Artwork(
            id: id,
            title: title,
            artist: artist,
            years: years,
            museum: museum,
            city: city,
            country: country,
            imageURL: imageURL,
            pageURL: pageURL,
            license: license,
            crop: nil
        )
    }

    func renamed(_ title: String) -> Artwork {
        Artwork(
            id: id,
            title: title,
            artist: artist,
            years: years,
            museum: museum,
            city: city,
            country: country,
            imageURL: imageURL,
            pageURL: pageURL,
            license: license,
            crop: crop
        )
    }
}
