#!/usr/bin/env swift
// Renders an illustrative workflow for the README, without capturing the desktop.
// Run: swift scripts/make-reading-demo.swift <frame-directory>
// Encode the numbered PNG frames as a looping GIF with ffmpeg at 12 fps.
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".tmp/reading-demo")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let width = 1200
let height = 720
let frameCount = 120

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 255) / 255,
        green: CGFloat((hex >> 8) & 255) / 255,
        blue: CGFloat(hex & 255) / 255,
        alpha: alpha
    )
}

let ink = color(0x20242B)
let muted = color(0x7B818C)
let blue = color(0x1675ED)

func box(_ rect: NSRect, fill: NSColor, radius: CGFloat = 0, border: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let border {
        border.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

func text(
    _ value: String,
    _ x: CGFloat,
    _ y: CGFloat,
    size: CGFloat = 18,
    weight: NSFont.Weight = .regular,
    tint: NSColor = ink,
    maxWidth: CGFloat = 1000
) {
    (value as NSString).draw(in: NSRect(x: x, y: y, width: maxWidth, height: 110), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: tint,
    ])
}

func ease(_ value: Double) -> CGFloat {
    let t = max(0, min(1, value))
    return CGFloat(t * t * (3 - 2 * t))
}

func cursor(_ x: CGFloat, _ y: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x, y: y))
    for point in [(0.0, 23.0), (6.0, 18.0), (11.0, 28.0), (15.0, 26.0), (10.0, 16.0), (19.0, 15.0)] {
        path.line(to: NSPoint(x: x + point.0, y: y + point.1))
    }
    path.close()
    NSColor.white.setStroke()
    path.lineWidth = 3
    path.stroke()
    ink.setFill()
    path.fill()
}

for frame in 0 ..< frameCount {
    autoreleasepool {
        let time = Double(frame) / 12
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
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
        box(NSRect(x: 0, y: 0, width: width, height: height), fill: color(0xF5F6F8))

        text("EasyRead", 64, 42, size: 28, weight: .semibold)
        text("Understand English. Stay in the flow.", 64, 82, size: 19, tint: muted)
        text("AI SELECTION TRANSLATION", 843, 53, size: 12, weight: .medium, tint: muted)

        box(
            NSRect(x: 64, y: 162, width: 1072, height: 450),
            fill: .white,
            radius: 16,
            border: color(0xDFE3E9)
        )
        for (index, dot) in [UInt32(0xFF6058), 0xFEBC2E, 0x28C840].enumerated() {
            box(NSRect(x: 85 + index * 20, y: 182, width: 10, height: 10), fill: color(dot), radius: 5)
        }
        text("Reading notes", 520, 179, size: 13, tint: muted)
        box(NSRect(x: 65, y: 211, width: 1070, height: 1), fill: color(0xEBEDF1))
        text("A little progress, every day", 108, 254, size: 28, weight: .medium)
        text("Good ideas begin with curiosity.", 108, 311, size: 22, tint: color(0x656C76))

        let selection = ease((time - 0.8) / 1.1)
        let selectionWidth = ("Small steps make a big difference." as NSString)
            .size(withAttributes: [.font: NSFont.systemFont(ofSize: 23)]).width + 4
        if selection > 0 {
            box(
                NSRect(x: 106, y: 349, width: selectionWidth * selection, height: 34),
                fill: color(0xDCEBFF),
                radius: 3
            )
        }
        text("Small steps make a big difference.", 108, 350, size: 23)
        text("Keep learning, one sentence at a time.", 108, 400, size: 22, tint: color(0x656C76))
        for row in 0 ..< 3 {
            box(
                NSRect(x: 108, y: 466 + row * 25, width: row == 2 ? 305 : 430, height: 7),
                fill: color(0xF0F1F4),
                radius: 3
            )
        }

        if time >= 1.9 && time < 3.4 {
            box(NSRect(x: 470, y: 390, width: 62, height: 37), fill: ink, radius: 9)
            text("⌥ D", 485, 398, size: 17, weight: .medium, tint: .white)
        }

        if time >= 3.4 {
            let alpha = ease((time - 3.4) / 0.4)
            NSGraphicsContext.saveGraphicsState()
            context.cgContext.setAlpha(alpha)
            let panel = NSRect(x: 650, y: 240, width: 450, height: 335)
            let shadow = NSShadow()
            shadow.shadowColor = color(0x182A49, alpha: 0.14)
            shadow.shadowBlurRadius = 24
            shadow.shadowOffset = NSSize(width: 0, height: 7)
            shadow.set()
            box(panel, fill: .white, radius: 13)
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.saveGraphicsState()
            context.cgContext.setAlpha(alpha)
            box(panel, fill: .white, radius: 13, border: color(0xDFE3E9))
            text("English   →   简体中文", 771, 257, size: 13, tint: muted)
            text("原文", 670, 294, size: 12, tint: muted)
            box(NSRect(x: 669, y: 316, width: 411, height: 48), fill: color(0xF5F6F8), radius: 7)
            text("Small steps make a big difference.", 682, 328, size: 18)
            text("翻译", 670, 382, size: 12, tint: muted)
            box(NSRect(x: 669, y: 404, width: 411, height: 54), fill: color(0xF5F6F8), radius: 7)
            if time < 4.3 {
                text("AI 正在翻译…", 682, 422, size: 17, tint: muted)
            } else {
                text("小小的行动，也能带来巨大的改变。", 682, 421, size: 20)
            }
            box(NSRect(x: 669, y: 476, width: 411, height: 31), fill: color(0xF0F2F5), radius: 7)
            box(NSRect(x: 672, y: 479, width: 133, height: 25), fill: blue, radius: 5)
            text("句子解析", 714, 485, size: 12, weight: .medium, tint: .white)
            text("词典", 856, 485, size: 12, tint: muted)
            text("其他译文", 976, 485, size: 12, tint: muted)
            if time >= 4.3 {
                for (phrase, role, x, length) in [
                    ("Small steps", "主语", 680.0, 100.0),
                    ("make", "谓语", 795.0, 48.0),
                    ("a big difference.", "宾语", 858.0, 148.0),
                ] {
                    text(phrase, x, 519, size: 17)
                    box(NSRect(x: x, y: 541, width: length, height: 2), fill: blue)
                    text(role, x, 548, size: 10, tint: muted)
                }
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        if time < 3.4 {
            cursor(108 + selectionWidth * selection, 370)
        }
        let stage = time < 2.4 ? 0 : time < 4.3 ? 1 : 2
        for (index, label) in ["01  Select text", "02  Press ⌥ D", "03  Read with AI"].enumerated() {
            text(
                label,
                CGFloat(110 + index * 370),
                658,
                size: 16,
                weight: index == stage ? .semibold : .regular,
                tint: index == stage ? ink : muted
            )
            if index == stage {
                box(NSRect(x: 88 + index * 370, y: 664, width: 6, height: 6), fill: blue, radius: 3)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let url = output.appendingPathComponent(String(format: "frame-%03d.png", frame))
        try! bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}

print("Rendered \(frameCount) illustrative frames to \(output.path)")
