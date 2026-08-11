#!/usr/bin/env swift

import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("no graphics context")
}

// Dark marble background.
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.23, alpha: 1),
    NSColor(calibratedRed: 0.035, green: 0.04, blue: 0.07, alpha: 1),
])!
background.draw(in: NSRect(origin: .zero, size: size), angle: -90)

// Gold frame.
let gold = NSColor(calibratedRed: 0.85, green: 0.70, blue: 0.38, alpha: 1)
gold.setStroke()
let frame = NSBezierPath(roundedRect: NSRect(x: 34, y: 34, width: 956, height: 956), xRadius: 190, yRadius: 190)
frame.lineWidth = 16
frame.stroke()

// Serif wordmark.
let font = NSFont(name: "New York", size: 300)
    ?? NSFont(name: "Times New Roman", size: 320)
    ?? NSFont.systemFont(ofSize: 300)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: gold,
    .kern: 4,
]
let word = NSAttributedString(string: "Art", attributes: attributes)
let textSize = word.size()
let textRect = NSRect(
    x: (1024 - textSize.width) / 2,
    y: (1024 - textSize.height) / 2 - 16,
    width: textSize.width,
    height: textSize.height
)
word.draw(in: textRect)

image.unlockFocus()

let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources/ArtIcon.png")
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not render icon")
}
try png.write(to: output)
print("Wrote \(output.path)")
