import AppKit
import CoreGraphics

// Background remover for the pet reference art.
//
// Removes the connected white background by flood-filling inward from the image
// border: any near-white pixel reachable from an edge becomes transparent, so
// the white *inside* the pet (puppy chest, cat paws, eye whites) — which is
// fenced off by the dark outlines — is preserved. The bright anti-aliased halo
// the flood fill leaves between the cut and the dark outline is then eroded
// away, and the final edge is softened with coverage-based alpha anti-aliasing.
//
// Usage: swift strip_white.swift <input.png> <output.png> [whiteThreshold=232]

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write("usage: strip_white.swift <in> <out> [threshold]\n".data(using: .utf8)!)
    exit(2)
}

let inPath = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]
let threshold = CommandLine.arguments.count >= 4 ? (UInt8(CommandLine.arguments[3]) ?? 232) : 232

guard let nsImage = NSImage(contentsOfFile: inPath),
      let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("could not load \(inPath)\n".data(using: .utf8)!)
    exit(1)
}

let width = cg.width
let height = cg.height
let bytesPerRow = width * 4
var pixels = [UInt8](repeating: 0, count: width * height * 4)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write("could not create context\n".data(using: .utf8)!)
    exit(1)
}

ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

func isWhite(_ idx: Int) -> Bool {
    let r = pixels[idx], g = pixels[idx + 1], b = pixels[idx + 2]
    return r >= threshold && g >= threshold && b >= threshold
}

// Flood fill from every border pixel that is near-white.
var visited = [Bool](repeating: false, count: width * height)
var stack = [Int]()

func seed(_ x: Int, _ y: Int) {
    let p = y * width + x
    if !visited[p] && isWhite(p * 4) {
        visited[p] = true
        stack.append(p)
    }
}

for x in 0..<width {
    seed(x, 0)
    seed(x, height - 1)
}
for y in 0..<height {
    seed(0, y)
    seed(width - 1, y)
}

while let p = stack.popLast() {
    let x = p % width
    let y = p / width
    pixels[p * 4 + 3] = 0   // make transparent

    let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
    for (nx, ny) in neighbors {
        if nx < 0 || ny < 0 || nx >= width || ny >= height {
            continue
        }
        let np = ny * width + nx
        if !visited[np] && isWhite(np * 4) {
            visited[np] = true
            stack.append(np)
        }
    }
}

// The flood fill only clears pixels at/above the white threshold, so the
// anti-aliased band between the white background and the pet's dark outline —
// which sits just under it — survives as a bright halo (most visible around the
// ears). Erode it: repeatedly drop opaque *light* pixels that touch a
// transparent pixel, peeling the halo inward round by round until the cut
// reaches the dark outline (avg < 175), which is kept as the real edge.
let erodeRounds = 3
let lightSum = 525   // r+g+b above this (avg 175) is background fringe, not outline
for _ in 0..<erodeRounds {
    var clear = [Int]()
    for y in 0..<height {
        for x in 0..<width {
            let p = y * width + x
            if pixels[p * 4 + 3] == 0 {
                continue
            }
            let sum = Int(pixels[p * 4]) + Int(pixels[p * 4 + 1]) + Int(pixels[p * 4 + 2])
            if sum < lightSum {
                continue
            }
            let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            for (nx, ny) in neighbors {
                if nx < 0 || ny < 0 || nx >= width || ny >= height {
                    continue
                }
                if pixels[(ny * width + nx) * 4 + 3] == 0 {
                    clear.append(p)
                    break
                }
            }
        }
    }
    if clear.isEmpty {
        break
    }
    for p in clear {
        pixels[p * 4 + 3] = 0
    }
}

// Alpha-based anti-aliasing: box-blur the alpha channel by one pixel so the
// hard cut becomes a soft feathered edge. Interior pixels keep full alpha (all
// neighbours opaque); only the boundary grades down. The buffer is
// premultipliedLast, so each softened pixel's RGB is scaled by its new coverage
// too — otherwise reducing alpha alone would re-brighten the edge on export.
let snapshot = pixels
for y in 0..<height {
    for x in 0..<width {
        let p = y * width + x
        if snapshot[p * 4 + 3] == 0 {
            continue
        }
        var sum = 0
        var count = 0
        for dy in -1...1 {
            for dx in -1...1 {
                let nx = x + dx, ny = y + dy
                if nx < 0 || ny < 0 || nx >= width || ny >= height {
                    continue
                }
                sum += Int(snapshot[(ny * width + nx) * 4 + 3])
                count += 1
            }
        }
        let coverage = sum / count
        if coverage >= 255 {
            continue
        }
        pixels[p * 4] = UInt8(Int(snapshot[p * 4]) * coverage / 255)
        pixels[p * 4 + 1] = UInt8(Int(snapshot[p * 4 + 1]) * coverage / 255)
        pixels[p * 4 + 2] = UInt8(Int(snapshot[p * 4 + 2]) * coverage / 255)
        pixels[p * 4 + 3] = UInt8(coverage)
    }
}

guard let out = ctx.makeImage() else {
    FileHandle.standardError.write("could not render output\n".data(using: .utf8)!)
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: out)
guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("could not encode png\n".data(using: .utf8)!)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outPath))
FileHandle.standardError.write("wrote \(outPath) (\(width)x\(height))\n".data(using: .utf8)!)
