#!/usr/bin/env swift
// Composes promotional frames from captures of the actual EasyRead window.
// Run: swift scripts/make-reading-demo.swift <native-image-directory> <output-directory>
// Encode the numbered PNG frames as a looping GIF with ffmpeg at 12 fps.
import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
let source = URL(fileURLWithPath: arguments.first ?? "docs/images/reading-demo")
let output = URL(fileURLWithPath: arguments.dropFirst().first ?? ".tmp/reading-demo")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let images = try ["query.png", "translation.png", "analysis.png"].map { name in
    guard let image = NSImage(contentsOf: source.appendingPathComponent(name)) else {
        throw NSError(
            domain: "ReadingDemo",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing native capture: \(name)"]
        )
    }
    return image
}

let width = 1440
let height = 1320
let frameCount = 120

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 255) / 255,
        green: CGFloat((hex >> 8) & 255) / 255,
        blue: CGFloat(hex & 255) / 255,
        alpha: alpha
    )
}

func text(
    _ value: String,
    _ x: CGFloat,
    _ y: CGFloat,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    tint: NSColor = color(0x20242B)
) {
    (value as NSString).draw(in: NSRect(x: x, y: y, width: 1300, height: 90), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: tint,
    ])
}

// Only framing is drawn here. Every product control, string and result is in the native PNG.
func nativePanel(_ image: NSImage, opacity: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let rect = NSRect(x: 72, y: 198, width: 1296, height: image.size.height * 1296 / image.size.width)
    let clip = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
    let shadow = NSShadow()
    shadow.shadowColor = color(0x182A49, alpha: 0.12 * opacity)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: 8)
    shadow.set()
    color(0x232323, alpha: opacity).setFill()
    clip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    image.draw(
        in: rect,
        from: .zero,
        operation: .sourceOver,
        fraction: opacity,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high.rawValue]
    )
    NSGraphicsContext.restoreGraphicsState()
}

for frame in 0 ..< frameCount {
    try autoreleasepool {
        let time = Double(frame) / 12
        let stage = time < 1.5 ? 0 : time < 3.2 ? 1 : 2
        let starts = [0.0, 1.5, 3.2]
        let blend = CGFloat(min(1, (time - starts[stage]) / 0.25))
        let bitmap = NSBitmapImageRep(
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
        )!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        context.cgContext.translateBy(x: 0, y: CGFloat(height))
        context.cgContext.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
        color(0xF4F5F7).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        text("长难句，也能读明白。", 72, 63, size: 42, weight: .semibold)
        text("原文对照 · AI 翻译 · 句子结构", 74, 128, size: 22, tint: color(0x707782))
        text("EasyRead", 1195, 78, size: 27, weight: .semibold)
        if stage > 0, blend < 1 {
            nativePanel(images[stage - 1], opacity: 1)
        }
        nativePanel(images[stage], opacity: stage == 0 ? 1 : blend)
        for (index, label) in ["01  划词唤起", "02  对照译文", "03  理解结构"].enumerated() {
            let x = CGFloat(116 + index * 454)
            text(
                label,
                x,
                1257,
                size: 20,
                weight: index == stage ? .semibold : .regular,
                tint: color(index == stage ? 0x20242B : 0x9298A2)
            )
            if index == stage {
                color(0x007AFF).setFill()
                NSBezierPath(ovalIn: NSRect(x: x - 24, y: 1267, width: 7, height: 7)).fill()
            }
        }
        let url = output.appendingPathComponent(String(format: "frame-%03d.png", frame))
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}

print("Composed \(frameCount) frames from native EasyRead captures.")
