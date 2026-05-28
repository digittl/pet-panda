#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Render a cute panda head into a PNG at the given size.
func drawPanda(size: CGFloat) -> Data {
    let pixel = Int(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: pixel,
        height: pixel,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    ctx.saveGState()

    // Soft rounded-square background with warm pink-cream gradient
    let cornerRadius = size * 0.22
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    let gradient = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 1.0, green: 0.93, blue: 0.92, alpha: 1.0),
            CGColor(red: 1.0, green: 0.82, blue: 0.85, alpha: 1.0)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: 0),
        options: []
    )
    ctx.resetClip()
    ctx.restoreGState()

    // Helper to draw an ellipse with optional stroke
    func fillEllipse(_ rect: CGRect, _ color: CGColor) {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: rect)
    }

    func strokeEllipse(_ rect: CGRect, _ color: CGColor, width: CGFloat) {
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.strokeEllipse(in: rect)
    }

    let cx = size / 2
    let cy = size / 2

    let black = CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
    let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    let pink = CGColor(red: 1, green: 0.65, blue: 0.75, alpha: 1)

    // Head dimensions
    let headW = size * 0.62
    let headH = size * 0.58

    // Ears
    let earR = size * 0.16
    let earOffsetX = size * 0.22
    let earOffsetY = size * 0.22
    fillEllipse(
        CGRect(x: cx - earOffsetX - earR / 2, y: cy + earOffsetY - earR / 2, width: earR, height: earR),
        black
    )
    fillEllipse(
        CGRect(x: cx + earOffsetX - earR / 2, y: cy + earOffsetY - earR / 2, width: earR, height: earR),
        black
    )

    // Inner ears (pink)
    let innerEarR = earR * 0.5
    fillEllipse(
        CGRect(x: cx - earOffsetX - innerEarR / 2, y: cy + earOffsetY - innerEarR / 2, width: innerEarR, height: innerEarR),
        pink
    )
    fillEllipse(
        CGRect(x: cx + earOffsetX - innerEarR / 2, y: cy + earOffsetY - innerEarR / 2, width: innerEarR, height: innerEarR),
        pink
    )

    // Subtle drop shadow under head
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.015), blur: size * 0.04, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.18))
    fillEllipse(
        CGRect(x: cx - headW / 2, y: cy - headH / 2, width: headW, height: headH),
        white
    )
    ctx.restoreGState()

    // Head outline
    strokeEllipse(
        CGRect(x: cx - headW / 2, y: cy - headH / 2, width: headW, height: headH),
        black,
        width: size * 0.018
    )

    // Eye patches (tilted black ovals)
    let patchW = headW * 0.26
    let patchH = headH * 0.34
    let eyeOffsetX = headW * 0.2
    let eyeY = cy + headH * 0.04

    for sign in [-1.0, 1.0] as [CGFloat] {
        ctx.saveGState()
        let center = CGPoint(x: cx + sign * eyeOffsetX, y: eyeY)
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: sign * 18 * .pi / 180)
        fillEllipse(
            CGRect(x: -patchW / 2, y: -patchH / 2, width: patchW, height: patchH),
            black
        )
        ctx.restoreGState()
    }

    // Sclera (white eyes)
    let eyeR = headW * 0.11
    for sign in [-1.0, 1.0] as [CGFloat] {
        let ex = cx + sign * eyeOffsetX
        let ey = eyeY
        fillEllipse(
            CGRect(x: ex - eyeR, y: ey - eyeR, width: eyeR * 2, height: eyeR * 2),
            white
        )
        // Pupil
        let pupilR = eyeR * 0.55
        fillEllipse(
            CGRect(x: ex - pupilR, y: ey - pupilR, width: pupilR * 2, height: pupilR * 2),
            black
        )
        // Highlight
        let hlR = eyeR * 0.28
        fillEllipse(
            CGRect(x: ex - hlR + eyeR * 0.18, y: ey - hlR + eyeR * 0.3, width: hlR * 2, height: hlR * 2),
            white
        )
    }

    // Cheeks (always faintly visible)
    let cheekR = headW * 0.09
    fillEllipse(
        CGRect(x: cx - headW * 0.28 - cheekR, y: cy - headH * 0.05 - cheekR / 2, width: cheekR * 2, height: cheekR),
        CGColor(red: 1, green: 0.55, blue: 0.65, alpha: 0.55)
    )
    fillEllipse(
        CGRect(x: cx + headW * 0.28 - cheekR, y: cy - headH * 0.05 - cheekR / 2, width: cheekR * 2, height: cheekR),
        CGColor(red: 1, green: 0.55, blue: 0.65, alpha: 0.55)
    )

    // Nose
    let noseW = headW * 0.13
    let noseH = noseW * 0.7
    fillEllipse(
        CGRect(x: cx - noseW / 2, y: cy - headH * 0.06 - noseH / 2, width: noseW, height: noseH),
        black
    )

    // Smile (cute curve)
    let smileY = cy - headH * 0.18
    let smileW = headW * 0.2
    ctx.setStrokeColor(black)
    ctx.setLineWidth(size * 0.018)
    ctx.setLineCap(.round)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx - smileW / 2, y: smileY))
    ctx.addQuadCurve(
        to: CGPoint(x: cx + smileW / 2, y: smileY),
        control: CGPoint(x: cx, y: smileY - smileW * 0.5)
    )
    ctx.strokePath()

    let cgImage = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let entries: [(String, CGFloat)] = [
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

for (name, size) in entries {
    let data = drawPanda(size: size)
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    try data.write(to: url)
    print("wrote \(name) (\(Int(size))x\(Int(size)))")
}
