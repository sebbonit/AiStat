#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent(".build/ResetStat.iconset", isDirectory: true)
let outputURL = root.appendingPathComponent("Resources/ResetStat.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

struct IconVariant {
    let points: Int
    let scale: Int
    let filename: String

    var pixels: Int { points * scale }
}

let variants = [
    IconVariant(points: 16, scale: 1, filename: "icon_16x16.png"),
    IconVariant(points: 16, scale: 2, filename: "icon_16x16@2x.png"),
    IconVariant(points: 32, scale: 1, filename: "icon_32x32.png"),
    IconVariant(points: 32, scale: 2, filename: "icon_32x32@2x.png"),
    IconVariant(points: 128, scale: 1, filename: "icon_128x128.png"),
    IconVariant(points: 128, scale: 2, filename: "icon_128x128@2x.png"),
    IconVariant(points: 256, scale: 1, filename: "icon_256x256.png"),
    IconVariant(points: 256, scale: 2, filename: "icon_256x256@2x.png"),
    IconVariant(points: 512, scale: 1, filename: "icon_512x512.png"),
    IconVariant(points: 512, scale: 2, filename: "icon_512x512@2x.png")
]

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let radius = CGFloat(size) * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.06, dy: CGFloat(size) * 0.06), xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.18, alpha: 1).setFill()
    background.fill()

    let gloss = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.08, dy: CGFloat(size) * 0.08), xRadius: radius * 0.88, yRadius: radius * 0.88)
    NSColor(calibratedRed: 0.10, green: 0.19, blue: 0.31, alpha: 1).setStroke()
    gloss.lineWidth = max(1, CGFloat(size) * 0.012)
    gloss.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let fontSize = CGFloat(size) * 0.66
    let font = NSFont.systemFont(ofSize: fontSize, weight: .black)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
        .kern: -CGFloat(size) * 0.018
    ]

    let string = "S" as NSString
    let textSize = string.size(withAttributes: attributes)
    let textRect = NSRect(
        x: 0,
        y: (CGFloat(size) - textSize.height) / 2 + CGFloat(size) * 0.01,
        width: CGFloat(size),
        height: textSize.height
    )
    string.draw(in: textRect, withAttributes: attributes)

    return image
}

for variant in variants {
    let image = drawIcon(size: variant.pixels)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ResetStatIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render \(variant.filename)"])
    }
    try png.write(to: iconsetURL.appendingPathComponent(variant.filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "ResetStatIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print("Generated \(outputURL.path)")
