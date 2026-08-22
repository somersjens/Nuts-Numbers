#!/usr/bin/env swift
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 4 else {
    fputs("usage: contact-sheet.swift <outdir-frames> <output.png> <names...>\n", stderr)
    exit(1)
}
let folder = URL(fileURLWithPath: args[1], isDirectory: true)
let dest = URL(fileURLWithPath: args[2])
let names = Array(args.dropFirst(3))
var images: [NSImage] = []
for name in names {
    let url = folder.appendingPathComponent(name)
    guard let image = NSImage(contentsOf: url) else { continue }
    images.append(image)
}
guard let first = images.first else { exit(1) }
let cols = min(4, images.count)
let rows = Int(ceil(Double(images.count) / Double(cols)))
let cellW: CGFloat = 220
let aspect = first.size.height / max(first.size.width, 1)
let cellH = cellW * aspect
let size = NSSize(width: cellW * CGFloat(cols), height: cellH * CGFloat(rows))
let image = NSImage(size: size)
image.lockFocus()
NSColor.black.setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: size))
for (index, img) in images.enumerated() {
    let col = index % cols
    let row = index / cols
    let rect = NSRect(x: CGFloat(col) * cellW,
                      y: size.height - CGFloat(row + 1) * cellH,
                      width: cellW, height: cellH)
    img.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: dest)
print("wrote \(dest.path) \(Int(size.width))x\(Int(size.height))")
