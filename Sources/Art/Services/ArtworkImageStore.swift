import AppKit
import Foundation

/// Loads artwork images from a local cache, falling back to Wikimedia.
actor ArtworkImageStore {
    static let shared = ArtworkImageStore()

    private let memory = NSCache<NSString, NSImage>()
    private let diskDirectory: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        diskDirectory = base.appendingPathComponent("ArtDaily/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    func image(for artwork: Artwork) async throws -> NSImage {
        let key = artwork.id as NSString
        if let cached = memory.object(forKey: key) {
            return cached
        }

        let fileURL = try await fileURL(for: artwork)
        guard let image = NSImage(contentsOfFile: fileURL.path) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        memory.setObject(image, forKey: key)
        return image
    }

    /// Ensures the artwork image is on disk and returns its file URL.
    func fileURL(for artwork: Artwork) async throws -> URL {
        let rawURL = diskDirectory.appendingPathComponent(artwork.id + ".jpg")
        let rawExists = ((try? Data(contentsOf: rawURL))?.isEmpty ?? true) == false

        if !rawExists {
            guard let url = URL(string: artwork.imageURL) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            guard !data.isEmpty, NSImage(data: data) != nil else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try data.write(to: rawURL, options: .atomic)
        }

        guard let crop = artwork.crop, crop.count == 4 else {
            return rawURL
        }

        let signature = crop.map { String(format: "%.3f", $0) }.joined(separator: "-")
        let processedURL = diskDirectory.appendingPathComponent("\(artwork.id)-crop-\(signature).jpg")
        let processedExists = ((try? Data(contentsOf: processedURL))?.isEmpty ?? true) == false
        if !processedExists {
            guard let rawData = try? Data(contentsOf: rawURL),
                  let cropped = Self.cropping(rawData, to: crop) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try cropped.write(to: processedURL, options: .atomic)
        }
        return processedURL
    }

    /// Builds a display-sized wallpaper so paintings are framed intentionally instead of
    /// being cropped unpredictably by System Settings.
    func wallpaperURL(for artwork: Artwork, pixelSize: CGSize, fill: Bool) async throws -> URL {
        let sourceURL = try await fileURL(for: artwork)
        guard let source = NSImage(contentsOf: sourceURL), pixelSize.width > 0, pixelSize.height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let width = Int(pixelSize.width.rounded())
        let height = Int(pixelSize.height.rounded())
        let mode = fill ? "fill" : "framed"
        let outputURL = diskDirectory.appendingPathComponent("\(artwork.id)-\(width)x\(height)-\(mode).jpg")
        if FileManager.default.fileExists(atPath: outputURL.path) { return outputURL }

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.black.setFill()
        canvas.fill()

        if fill {
            source.draw(in: Self.aspectFillRect(imageSize: source.size, canvas: canvas), from: .zero, operation: .copy, fraction: 1)
        } else {
            // Use the same art as a subdued edge-to-edge background, then preserve the
            // complete painting in front. This avoids both black bars and destructive crops.
            source.draw(in: Self.aspectFillRect(imageSize: source.size, canvas: canvas), from: .zero, operation: .copy, fraction: 0.52)
            NSColor.black.withAlphaComponent(0.52).setFill()
            canvas.fill()
            let framed = Self.aspectFitRect(imageSize: source.size, canvas: canvas)
                .insetBy(dx: CGFloat(width) * 0.018, dy: CGFloat(height) * 0.018)
            source.draw(in: framed, from: .zero, operation: .sourceOver, fraction: 1)
        }

        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.93]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private static func aspectFitRect(imageSize: CGSize, canvas: CGRect) -> CGRect {
        let scale = min(canvas.width / imageSize.width, canvas.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2, width: size.width, height: size.height)
    }

    private static func aspectFillRect(imageSize: CGSize, canvas: CGRect) -> CGRect {
        let scale = max(canvas.width / imageSize.width, canvas.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// Applies a fractional crop rect (origin top-left) to JPEG data.
    private static func cropping(_ data: Data, to rect: [Double]) -> Data? {
        guard let image = NSImage(data: data),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        let x = CGFloat(rect[0]) * width
        let y = (1 - CGFloat(rect[1]) - CGFloat(rect[3])) * height
        let w = CGFloat(rect[2]) * width
        let h = CGFloat(rect[3]) * height
        let cropRect = CGRect(x: x, y: y, width: w, height: h)
        guard let cropped = cg.cropping(to: cropRect) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cropped)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }
}
