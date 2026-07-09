#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent(".build/LimitLens.iconset", isDirectory: true)
let outputURL = root.appendingPathComponent("Resources/LimitLens.icns")

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

// MARK: - Colors

func ringColor(index: Int) -> NSColor {
    switch index {
    case 0: return NSColor(calibratedRed: 0.24, green: 0.51, blue: 0.96, alpha: 1)  // blue (Codex)
    case 1: return NSColor(calibratedRed: 0.30, green: 0.85, blue: 0.60, alpha: 1)  // green (Cursor)
    case 2: return NSColor(calibratedRed: 0.96, green: 0.56, blue: 0.20, alpha: 1)  // orange (Devin)
    case 3: return NSColor(calibratedRed: 0.69, green: 0.32, blue: 0.96, alpha: 1)  // purple (OpenCode Go)
    default: return NSColor.white
    }
}

let backgroundColor = NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.16, alpha: 1)
let backgroundGradientTop = NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.22, alpha: 1)
let backgroundGradientBottom = NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.12, alpha: 1)

// Progress values for each ring (0.0 to 1.0) — represents typical usage
let ringProgress: [CGFloat] = [0.72, 0.45, 0.85, 0.30]

// MARK: - Drawing

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let s = CGFloat(size)
    let rect = NSRect(x: 0, y: 0, width: s, height: s)

    // Clear
    NSColor.clear.setFill()
    rect.fill()

    // Background with subtle gradient
    let bgRect = rect.insetBy(dx: s * 0.04, dy: s * 0.04)
    let radius = s * 0.22
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(starting: backgroundGradientTop, ending: backgroundGradientBottom)
    gradient?.draw(in: bgPath, angle: -90)

    // Subtle inner border for depth
    let borderRect = bgRect.insetBy(dx: s * 0.01, dy: s * 0.01)
    let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: radius * 0.95, yRadius: radius * 0.95)
    NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.06).setStroke()
    borderPath.lineWidth = max(1, s * 0.008)
    borderPath.stroke()

    // Draw 4 concentric activity rings
    let center = NSPoint(x: s / 2, y: s / 2)
    let maxOuterRadius = s * 0.34
    let ringSpacing = s * 0.055
    let ringWidth = s * 0.038

    for i in 0..<4 {
        let ringRadius = maxOuterRadius - CGFloat(i) * ringSpacing
        let progress = ringProgress[i]
        let color = ringColor(index: i)

        // Background track (full circle, dimmed)
        let trackPath = NSBezierPath()
        trackPath.appendArc(withCenter: center, radius: ringRadius, startAngle: 0, endAngle: 360, clockwise: false)
        color.withAlphaComponent(0.15).setStroke()
        trackPath.lineWidth = ringWidth
        trackPath.lineCapStyle = .round
        trackPath.stroke()

        // Progress arc (starts at 12 o'clock, goes clockwise)
        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (360 * progress)
        progressPath.appendArc(withCenter: center, radius: ringRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        color.setStroke()
        progressPath.lineWidth = ringWidth
        progressPath.lineCapStyle = .round
        progressPath.stroke()
    }

    return image
}

// MARK: - Generate

for variant in variants {
    let image = drawIcon(size: variant.pixels)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LimitLensIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render \(variant.filename)"])
    }
    try png.write(to: iconsetURL.appendingPathComponent(variant.filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "LimitLensIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print("Generated \(outputURL.path)")
