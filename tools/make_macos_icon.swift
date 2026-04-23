#!/usr/bin/env swift

import AppKit
import Foundation

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let sourceIconURL = root.appendingPathComponent("Interfaces/VideoSubFinderWXW/videosubfinder.ico")
let dataDir = root.appendingPathComponent("Data", isDirectory: true)
let previewURL = dataDir.appendingPathComponent("VideoSubFinder.png")
let icnsURL = dataDir.appendingPathComponent("VideoSubFinder.icns")
let iconsetURL = dataDir.appendingPathComponent("VideoSubFinder.iconset", isDirectory: true)
let keepIconset = CommandLine.arguments.contains("--keep-iconset")

guard let sourceImage = NSImage(contentsOf: sourceIconURL) else {
    fatalError("Could not load original icon: \(sourceIconURL.path)")
}

try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)
try? fm.removeItem(at: iconsetURL)
try fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func renderSourceIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    rep.size = NSSize(width: size, height: size)

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create graphics context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let cg = context.cgContext
    cg.clear(CGRect(x: 0, y: 0, width: size, height: size))
    cg.interpolationQuality = .high

    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .copy,
        fraction: 1.0
    )

    NSGraphicsContext.restoreGraphicsState()

    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG: \(url.path)")
    }
    try! data.write(to: url)
}

let requested: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in requested {
    let rep = renderSourceIcon(size: size)
    writePNG(rep, to: iconsetURL.appendingPathComponent(name))
    if size == 1024 {
        writePNG(rep, to: previewURL)
    }
}

func appendFourCC(_ value: String, to data: inout Data) {
    let bytes = Array(value.utf8)
    guard bytes.count == 4 else {
        fatalError("Invalid ICNS chunk type: \(value)")
    }
    data.append(contentsOf: bytes)
}

func appendUInt32BE(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

let chunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic14", "icon_256x256@2x.png")
]

var payload = Data()
for (type, file) in chunks {
    let png = try Data(contentsOf: iconsetURL.appendingPathComponent(file))
    appendFourCC(type, to: &payload)
    appendUInt32BE(UInt32(png.count + 8), to: &payload)
    payload.append(png)
}

var icns = Data()
appendFourCC("icns", to: &icns)
appendUInt32BE(UInt32(payload.count + 8), to: &icns)
icns.append(payload)
try icns.write(to: icnsURL)

if !keepIconset {
    try? fm.removeItem(at: iconsetURL)
}

print("Generated \(icnsURL.path) from \(sourceIconURL.path)")
