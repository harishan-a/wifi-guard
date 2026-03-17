#!/usr/bin/env swift
// Generates WiFi Guard app icon using SF Symbols + AppKit drawing
import AppKit

let sizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

func tintImage(_ source: NSImage, color: NSColor, targetSize: NSSize) -> NSImage {
    let result = NSImage(size: targetSize)
    result.lockFocus()
    source.draw(in: NSRect(origin: .zero, size: targetSize),
                from: .zero, operation: .sourceOver, fraction: 1.0)
    color.set()
    NSRect(origin: .zero, size: targetSize).fill(using: .sourceAtop)
    result.unlockFocus()
    return result
}

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    // Background: rounded rectangle with gradient
    let cornerRadius = size * 0.22
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Gradient from deep blue to teal
    let gradient = NSGradient(
        colors: [
            NSColor(red: 0.06, green: 0.15, blue: 0.50, alpha: 1.0),
            NSColor(red: 0.08, green: 0.38, blue: 0.62, alpha: 1.0),
        ],
        atLocations: [0.0, 1.0],
        colorSpace: .deviceRGB
    )!
    gradient.draw(in: bgPath, angle: -45)

    // Subtle border
    NSColor(white: 1.0, alpha: 0.12).setStroke()
    bgPath.lineWidth = max(size * 0.008, 0.5)
    bgPath.stroke()

    // Draw wifi symbol
    let wifiPointSize = size * 0.42
    let wifiConfig = NSImage.SymbolConfiguration(pointSize: wifiPointSize, weight: .semibold)
    if let wifiSymbol = NSImage(systemSymbolName: "wifi", accessibilityDescription: nil)?
        .withSymbolConfiguration(wifiConfig) {

        let symbolSize = wifiSymbol.size
        let tinted = tintImage(wifiSymbol, color: NSColor(white: 1.0, alpha: 0.95), targetSize: symbolSize)

        let x = (size - symbolSize.width) / 2
        let y = (size - symbolSize.height) / 2 + size * 0.04
        tinted.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
                    from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    // Small shield at bottom-right
    let shieldPointSize = size * 0.22
    let shieldConfig = NSImage.SymbolConfiguration(pointSize: shieldPointSize, weight: .semibold)
    if let shield = NSImage(systemSymbolName: "checkmark.shield.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(shieldConfig) {

        let sSize = shield.size
        let tinted = tintImage(shield, color: NSColor(red: 0.25, green: 0.88, blue: 0.45, alpha: 1.0), targetSize: sSize)

        let sx = size * 0.63
        let sy = size * 0.08
        tinted.draw(in: NSRect(x: sx, y: sy, width: sSize.width, height: sSize.height),
                    from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

// Create iconset directory
let iconsetPath = "Resources/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for entry in sizes {
    let image = renderIcon(size: entry.size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to render \(entry.name)")
        continue
    }
    let path = "\(iconsetPath)/\(entry.name).png"
    try png.write(to: URL(fileURLWithPath: path))
    print("Generated \(entry.name) (\(Int(entry.size))px)")
}

print("\nConverting to icns...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "Resources/AppIcon.icns"]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    try? fm.removeItem(atPath: iconsetPath)
    print("Created Resources/AppIcon.icns")
} else {
    print("iconutil failed with status \(process.terminationStatus)")
}
