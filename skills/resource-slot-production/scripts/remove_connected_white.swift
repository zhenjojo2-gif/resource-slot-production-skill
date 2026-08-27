import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: remove_connected_white.swift <input> <output.png>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard
    let image = NSImage(contentsOf: inputURL),
    let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    fputs("failed to read image: \(inputURL.path)\n", stderr)
    exit(1)
}

let width = source.width
let height = source.height
let bytesPerPixel = 4
let bytesPerRow = width * bytesPerPixel
var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("failed to create bitmap context\n", stderr)
    exit(1)
}

context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

let pixelCount = width * height
var visited = [Bool](repeating: false, count: pixelCount)
var queue = [Int]()
queue.reserveCapacity(pixelCount)

func isBackground(_ index: Int) -> Bool {
    let offset = index * bytesPerPixel
    let r = Int(pixels[offset])
    let g = Int(pixels[offset + 1])
    let b = Int(pixels[offset + 2])
    return r > 222 && g > 222 && b > 222 && (max(r, g, b) - min(r, g, b)) < 42
}

func enqueue(_ index: Int) {
    guard !visited[index], isBackground(index) else { return }
    visited[index] = true
    queue.append(index)
}

for x in 0..<width {
    enqueue(x)
    enqueue((height - 1) * width + x)
}
for y in 0..<height {
    enqueue(y * width)
    enqueue(y * width + width - 1)
}

var head = 0
while head < queue.count {
    let index = queue[head]
    head += 1
    let x = index % width
    let y = index / width
    if x > 0 { enqueue(index - 1) }
    if x + 1 < width { enqueue(index + 1) }
    if y > 0 { enqueue(index - width) }
    if y + 1 < height { enqueue(index + width) }
}

for index in queue {
    pixels[index * bytesPerPixel + 3] = 0
}

guard let outputImage = context.makeImage() else {
    fputs("failed to create output image\n", stderr)
    exit(1)
}

let destinationDirectory = outputURL.deletingLastPathComponent()
try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
let representation = NSBitmapImageRep(cgImage: outputImage)
guard let pngData = representation.representation(using: .png, properties: [:]) else {
    fputs("failed to encode PNG\n", stderr)
    exit(1)
}
try pngData.write(to: outputURL)
