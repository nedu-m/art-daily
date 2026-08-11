import Foundation

/// User-triggered discovery from Wikimedia Commons. Accepted works are persisted,
/// deduplicated, and mixed into the daily rotation.
actor ArtworkDiscoveryService {
    static let shared = ArtworkDiscoveryService()

    private let apiURL = URL(string: "https://commons.wikimedia.org/w/api.php")!
    private let queries = [
        "Michelangelo masterpiece sculpture",
        "Raphael Renaissance masterpiece",
        "Bernini sculpture masterpiece",
        "Caravaggio sacred painting",
        "Fra Angelico masterpiece painting",
        "Botticelli masterpiece painting",
        "Rembrandt masterpiece painting",
        "Leonardo da Vinci masterpiece painting",
        "Tintoretto masterpiece painting",
        "Veronese masterpiece painting",
        "Titian masterpiece painting",
        "Jan van Eyck masterpiece painting",
        "Pieter Bruegel masterpiece painting",
        "El Greco masterpiece painting",
        "Velazquez masterpiece painting",
        "Rodin masterpiece sculpture",
    ]

    private static let acceptedMasters = [
        "michelangelo", "raphael", "raffaello", "bernini", "caravaggio",
        "fra angelico", "botticelli", "rembrandt", "leonardo", "da vinci",
        "tintoretto", "veronese", "titian", "tiziano", "van eyck", "bruegel",
        "el greco", "velázquez", "velazquez", "rodin", "ghirlandaio", "giotto",
        "rubens", "vermeer", "melozzo", "perugino", "campin", "van der goes",
    ]

    private static let blockedTerms = [
        "death", "dead", "corpse", "execution", "beheading", "torture", "murder",
        "hell", "demon", "devil", "skull", "battle", "funeral", "wounded",
        "lamentation", "flagellation", "entombment", "calvary", "golgotha",
        "crucifixion", "martyrdom", "judith", "holofernes", "saturn", "medusa",
        "belshazzar", "massacre", "slaughter", "rape", "abduction", "sacrifice of isaac",
        "monster", "grotesque", "macabre", "anatomical", "dissection",
        "detail", "diagram", "poster", "book cover", "souvenir", "gift shop",
        "museum visitors", "exhibition view", "installation view", "restoration process",
        "interior", "interieur", "documentary photograph", "sculpting the statue",
    ]

    static func cachedDiscoveries() -> [Artwork] {
        guard let data = try? Data(contentsOf: discoveryCacheURL) else { return [] }
        let decoded = (try? JSONDecoder().decode([Artwork].self, from: data)) ?? []
        let retained = deduplicated(decoded.filter(isStillAccepted), excluding: [])
        if retained.count != decoded.count {
            saveDiscoveries(retained)
        }
        return retained
    }

    static func saveDiscoveries(_ artworks: [Artwork]) {
        let retained = Array(artworks.prefix(100))
        guard let data = try? JSONEncoder().encode(retained) else { return }
        let directory = discoveryCacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: discoveryCacheURL, options: .atomic)
    }

    private static var discoveryCacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ArtDaily", isDirectory: true)
            .appendingPathComponent("accepted-discoveries-v2.json")
    }

    private static func isStillAccepted(_ artwork: Artwork) -> Bool {
        let artist = artwork.artist.lowercased()
        let text = "\(artwork.title) \(artwork.artist)".lowercased()
        return acceptedMasters.contains(where: artist.contains)
            && !blockedTerms.contains(where: text.contains)
    }

    func discover(excluding existing: [Artwork]) async throws -> [Artwork] {
        let defaults = UserDefaults.standard
        let start = defaults.integer(forKey: "discoveryQueryIndex") % queries.count
        defaults.set((start + 2) % queries.count, forKey: "discoveryQueryIndex")

        var candidates: [Artwork] = []
        for offset in 0..<2 {
            candidates += try await search(query: queries[(start + offset) % queries.count])
            if offset == 0 { try? await Task.sleep(for: .milliseconds(450)) }
        }

        return Self.deduplicated(candidates, excluding: existing)
    }

    static func deduplicated(_ candidates: [Artwork], excluding existing: [Artwork]) -> [Artwork] {
        var known = Set(existing.map(canonicalKey))
        return candidates.filter { artwork in
            known.insert(canonicalKey(artwork)).inserted
        }
    }

    private func search(query: String) async throws -> [Artwork] {
        var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: query + " filetype:bitmap"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "40"),
            URLQueryItem(name: "prop", value: "imageinfo|info"),
            URLQueryItem(name: "inprop", value: "url"),
            URLQueryItem(name: "iiprop", value: "size|url|mime|extmetadata"),
            URLQueryItem(name: "iiurlwidth", value: "2560"),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("ArtDaily/2.0 (macOS art discovery; Wikimedia Commons reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        let artworks = (decoded.query?.pages ?? []).compactMap(makeArtwork)
        return Array(artworks.sorted { qualityScore($0) > qualityScore($1) }.prefix(8))
    }

    private func makeArtwork(from page: APIResponse.Page) -> Artwork? {
        guard let info = page.imageinfo?.first,
              max(info.width, info.height) >= 1_800,
              min(info.width, info.height) >= 900,
              info.mime == "image/jpeg" || info.mime == "image/png" else {
            return nil
        }

        let metadata = info.extmetadata
        let fileTitle = cleanFileTitle(page.title)
        let title = displayValue(clean(metadata?.ObjectName?.value), fallback: fileTitle)
        let artist = displayValue(clean(metadata?.Artist?.value), fallback: "Unknown artist")
        let searchable = "\(title) \(artist) \(fileTitle)".lowercased()
        let creditedArtist = artist.lowercased()
        guard Self.acceptedMasters.contains(where: creditedArtist.contains),
              !Self.blockedTerms.contains(where: searchable.contains) else { return nil }

        let license = clean(metadata?.LicenseShortName?.value)
        let normalizedLicense = license.lowercased()
        guard normalizedLicense.contains("public domain") || normalizedLicense == "cc0"
                || normalizedLicense.hasPrefix("cc by") else {
            return nil
        }

        let date = displayValue(clean(metadata?.DateTimeOriginal?.value), fallback: "Discovered artwork")
        let institution = displayValue(clean(metadata?.Institution?.value), fallback: "Wikimedia Commons")
        return Artwork(
            id: "discovery-\(page.pageid)",
            title: title,
            artist: artist,
            years: date,
            museum: institution,
            city: "",
            country: "",
            imageURL: info.thumburl ?? info.url,
            pageURL: page.fullurl,
            license: license,
            crop: nil
        )
    }

    private func qualityScore(_ artwork: Artwork) -> Int {
        let text = "\(artwork.title) \(artwork.artist)".lowercased()
        let sacred = [
            "christ", "madonna", "virgin", "angel", "saint", "holy family",
            "annunciation", "nativity", "resurrection", "ascension", "baptism",
        ]
        var score = Self.acceptedMasters.filter(text.contains).count * 6
        score += sacred.filter(text.contains).count * 3
        if artwork.license.lowercased().contains("public domain") { score += 2 }
        if artwork.artist == "Unknown artist" { score -= 2 }
        return score
    }

    private static func canonicalKey(_ artwork: Artwork) -> String {
        var title = artwork.title.lowercased()
        title = title.replacingOccurrences(
            of: "\\b(high resolution|google art project|restored|painting|photo|photograph|copy)\\b",
            with: "",
            options: .regularExpression
        )
        title = title.replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
        let text = "\(artwork.title) \(artwork.artist) \(artwork.pageURL)".lowercased()
        if text.contains("last supper"), text.contains("leonardo") || text.contains("da_vinci") {
            return "lastsupperleonardo"
        }
        if text.contains("ultima cena") || text.contains("cenacolo"), text.contains("leonardo") {
            return "lastsupperleonardo"
        }
        if text.contains("creation of adam") || text.contains("creation_of_adam") {
            return "creationofadammichelangelo"
        }
        if text.contains("ecstasy"), text.contains("teresa") { return "ecstasysaintteresa" }
        if text.contains("pietà") || text.contains("pieta"), text.contains("michelangelo") {
            return "pietamichelangelo"
        }
        if text.contains("david"), text.contains("michelangelo") { return "davidmichelangelo" }
        if text.contains("david"), text.contains("bernini") { return "davidbernini" }
        if text.contains("school of athens") || text.contains("school_of_athens")
            || text.contains("scuola di atene") { return "schoolofathens" }
        if text.contains("sistine madonna") || text.contains("madonna sistina") { return "sistinemadonna" }
        if text.contains("calling of saint matthew") || text.contains("calling_of_saint_matthew") {
            return "callingofsaintmatthew"
        }
        if text.contains("birth of venus") || text.contains("nascita di venere") { return "birthofvenus" }
        if text.contains("madonna"), text.contains("raphael"),
           ["goldfinch", "cardellino", "chardonneret"].contains(where: text.contains) {
            return "raphaelmadonnagoldfinch"
        }
        if text.contains("transfiguration") || text.contains("trasfigurazione"), text.contains("raphael") {
            return "raphaeltransfiguration"
        }
        if text.contains("mona lisa") || text.contains("gioconda"), text.contains("leonardo") {
            return "monalisaleonardo"
        }
        if text.contains("night watch") || text.contains("nachtwacht") { return "nightwatch" }
        if text.contains("las meninas") { return "lasmeninas" }
        if text.contains("arnolfini") { return "arnolfini" }
        if text.contains("prodigal son"), text.contains("rembrandt") { return "prodigalsonrembrandt" }
        return title
    }

    private func clean(_ value: String?) -> String {
        guard let value else { return "" }
        return value
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func displayValue(_ raw: String, fallback: String) -> String {
        guard !raw.isEmpty else { return fallback }
        let markers = ["title QS:", "label QS:", "Edit this at Wikidata", "date QS:"]
        var value = raw
        for marker in markers {
            if let range = value.range(of: marker, options: .caseInsensitive) {
                value = String(value[..<range.lowerBound])
            }
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value.count > 140 ? fallback : value
    }

    private func cleanFileTitle(_ value: String) -> String {
        var title = value.replacingOccurrences(of: "File:", with: "")
        if let dot = title.lastIndex(of: ".") { title = String(title[..<dot]) }
        return title.replacingOccurrences(of: "_", with: " ")
    }

    private struct APIResponse: Decodable, Sendable {
        let query: Query?

        struct Query: Decodable, Sendable { let pages: [Page] }
        struct Page: Decodable, Sendable {
            let pageid: Int
            let title: String
            let fullurl: String
            let imageinfo: [ImageInfo]?
        }
        struct ImageInfo: Decodable, Sendable {
            let width: Int
            let height: Int
            let url: String
            let thumburl: String?
            let mime: String
            let extmetadata: Metadata?
        }
        struct Metadata: Decodable, Sendable {
            let ObjectName: MetadataValue?
            let Artist: MetadataValue?
            let DateTimeOriginal: MetadataValue?
            let Institution: MetadataValue?
            let LicenseShortName: MetadataValue?
        }
        struct MetadataValue: Decodable, Sendable { let value: String }
    }
}
