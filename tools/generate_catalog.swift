#!/usr/bin/env swift

import Foundation

// Resolves every seed entry to a verified, high-resolution Wikimedia Commons image
// and writes Sources/Art/Support/ArtworkCatalog.swift.

var stderr = FileHandle.standardError
func print(_ items: Any..., to handle: FileHandle, terminator: String = "\n") {
    let text = items.map { "\($0)" }.joined(separator: " ")
    if let data = (text + terminator).data(using: .utf8) {
        handle.write(data)
    }
}

struct Seed: Codable {
    let id: String
    let title: String
    let artist: String
    let years: String
    let museum: String
    let city: String
    let country: String
    let wikipedia: String
    let files: [String]
    let search: String?
    let crop: [Double]?
}

struct Page: Decodable {
    let title: String?
    let missing: String?
    let imageinfo: [ImageInfo]?
}

struct ImageInfo: Decodable {
    let url: String?
    let width: Int?
    let height: Int?
    let thumburl: String?
    let thumbwidth: Int?
    let extmetadata: [String: ExtValue]?
}

struct ExtValue: Decodable {
    let value: String?

    private enum CodingKeys: String, CodingKey {
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let string = try? container.decode(String.self, forKey: .value) {
            value = string
        } else if let number = try? container.decode(Double.self, forKey: .value) {
            value = String(number)
        } else {
            value = nil
        }
    }
}

struct Query: Decodable {
    let pages: [Page]?
}

struct ApiResponse: Decodable {
    let query: Query?
}

struct Resolved {
    let seed: Seed
    let imageURL: String
    let license: String
}

let scriptsDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("tools")
let seedURL = scriptsDir.appendingPathComponent("artworks.json")
let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Sources/Art/Support/ArtworkCatalog.swift")

let seeds = try JSONDecoder().decode([Seed].self, from: Data(contentsOf: seedURL))
print("Resolving \(seeds.count) artworks…", to: stderr)

var resolved: [Resolved] = []
var failures: [(String, String)] = []

for seed in seeds {
    var chosen: Resolved?
    for fileName in seed.files {
        guard let info = try? fetchImageInfo(file: fileName, thumbWidth: 2400),
              let url = info.url,
              !url.lowercased().hasSuffix(".svg"),
              !url.lowercased().hasSuffix(".pdf") else {
            continue
        }

        var imageURL = url
        let isPortrait = (info.height ?? 0) > (info.width ?? 0) * 13 / 10
        if isPortrait, let thumb = info.thumburl {
            // Portrait work: cap at 1400px wide so downloads stay reasonable.
            let capped = try? fetchImageInfo(file: fileName, thumbWidth: 1400)
            imageURL = capped?.thumburl ?? thumb
        } else if let thumb = info.thumburl {
            imageURL = thumb
        }

        let license = info.extmetadata?["LicenseShortName"]?.value ?? "Public domain"
        chosen = Resolved(seed: seed, imageURL: imageURL, license: license)
        print("  ✓ \(seed.id)  ←  \(fileName)", to: stderr)
        break
    }
    if chosen == nil, let query = seed.search {
        let titles = (try? searchFileTitles(query)) ?? []
        for title in titles {
            let bare = title.hasPrefix("File:") ? String(title.dropFirst(5)) : title
            guard let info = try? fetchImageInfo(file: bare, thumbWidth: 2400),
                  let url = info.url,
                  !url.lowercased().hasSuffix(".svg"),
                  !url.lowercased().hasSuffix(".pdf"),
                  (info.width ?? 0) >= 1200 else {
                continue
            }
            var imageURL = url
            let isPortrait = (info.height ?? 0) > (info.width ?? 0) * 13 / 10
            if isPortrait, let thumb = info.thumburl {
                let capped = try? fetchImageInfo(file: bare, thumbWidth: 1400)
                imageURL = capped?.thumburl ?? thumb
            } else if let thumb = info.thumburl {
                imageURL = thumb
            }
            let license = info.extmetadata?["LicenseShortName"]?.value ?? "Public domain"
            chosen = Resolved(seed: seed, imageURL: imageURL, license: license)
            print("  ✓ \(seed.id)  ←  \(title) (search)", to: stderr)
            break
        }
    }
    if let chosen {
        resolved.append(chosen)
    } else {
        failures.append((seed.id, seed.files.joined(separator: " | ")))
        print("  ✗ \(seed.id): no candidate resolved", to: stderr)
    }
}

// Build the final artwork array.
let artworks: [[String: Any]] = resolved.map { item in
    let pageTitle = item.seed.wikipedia.replacingOccurrences(of: " ", with: "_")
    let pageURL = "https://en.wikipedia.org/wiki/" + pageTitle
    var artwork: [String: Any] = [
        "id": item.seed.id,
        "title": item.seed.title,
        "artist": item.seed.artist,
        "years": item.seed.years,
        "museum": item.seed.museum,
        "city": item.seed.city,
        "country": item.seed.country,
        "imageURL": item.imageURL,
        "pageURL": pageURL,
        "license": item.license,
    ]
    if let crop = item.seed.crop {
        artwork["crop"] = crop
    }
    return artwork
}

let json = try JSONSerialization.data(withJSONObject: artworks, options: [.sortedKeys])
let base64 = json.base64EncodedString()

let swiftSource = """
import Foundation

/// Generated by tools/generate_catalog.swift — do not edit by hand.
enum ArtworkCatalog {
    static let all: [Artwork] = {
        let base64 = "\(base64)"
        guard let data = Data(base64Encoded: base64) else {
            fatalError("ArtworkCatalog: corrupt embedded catalog")
        }
        return (try? JSONDecoder().decode([Artwork].self, from: data)) ?? []
    }()
}
"""

try swiftSource.write(to: outputURL, atomically: true, encoding: .utf8)

print("", to: stderr)
print("Wrote \(resolved.count)/\(seeds.count) artworks to \(outputURL.path)", to: stderr)
if !failures.isEmpty {
    print("FAILED to resolve:", to: stderr)
    for (id, files) in failures {
    print("  - \(id) (tried: \(files))", to: stderr)
    }
    exit(1)
}

// MARK: - API helpers

func fetchImageInfo(file: String, thumbWidth: Int) throws -> ImageInfo? {
    var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
    components.queryItems = [
        URLQueryItem(name: "action", value: "query"),
        URLQueryItem(name: "titles", value: "File:\(file)"),
        URLQueryItem(name: "prop", value: "imageinfo"),
        URLQueryItem(name: "iiprop", value: "url|size|extmetadata"),
        URLQueryItem(name: "iiurlwidth", value: "\(thumbWidth)"),
        URLQueryItem(name: "redirects", value: "1"),
        URLQueryItem(name: "format", value: "json"),
        URLQueryItem(name: "formatversion", value: "2"),
    ]
    guard let url = components.url else { return nil }
    var request = URLRequest(url: url)
    request.setValue("ArtDaily-CatalogGenerator/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
    let data = try syncGet(request)
    let response = try JSONDecoder().decode(ApiResponse.self, from: data)
    return response.query?.pages?.first?.imageinfo?.first
}

func searchFileTitles(_ query: String) throws -> [String] {
    var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
    components.queryItems = [
        URLQueryItem(name: "action", value: "query"),
        URLQueryItem(name: "list", value: "search"),
        URLQueryItem(name: "srsearch", value: query + " filetype:bitmap"),
        URLQueryItem(name: "srnamespace", value: "6"),
        URLQueryItem(name: "srlimit", value: "25"),
        URLQueryItem(name: "format", value: "json"),
        URLQueryItem(name: "formatversion", value: "2"),
    ]
    guard let url = components.url else { return [] }
    var request = URLRequest(url: url)
    request.setValue("ArtDaily-CatalogGenerator/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
    let data = try syncGet(request)
    let response = try JSONDecoder().decode(SearchResponse.self, from: data)
    return response.query?.search?.compactMap { $0.title } ?? []
}

struct SearchResponse: Decodable {
    struct SearchQuery: Decodable {
        let search: [SearchHit]?
    }
    struct SearchHit: Decodable {
        let title: String
    }
    let query: SearchQuery?
}

func syncGet(_ request: URLRequest) throws -> Data {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<Data, Error> = .failure(URLError(.badServerResponse))
    let task = URLSession.shared.dataTask(with: request) { data, _, error in
        if let data {
            result = .success(data)
        } else if let error {
            result = .failure(error)
        }
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()
    return try result.get()
}
