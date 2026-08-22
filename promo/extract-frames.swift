#!/usr/bin/env swift
import AVFoundation
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: extract-frames.swift <video> <outdir> [times...]\n", stderr)
    exit(1)
}

let videoURL = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let asset = AVURLAsset(url: videoURL)
let duration = CMTimeGetSeconds(asset.duration)
let tracks = asset.tracks(withMediaType: .video)
let track = tracks.first
let size = track?.naturalSize.applying(track?.preferredTransform ?? .identity) ?? .zero
let fps = track.map { $0.nominalFrameRate } ?? 0
print(String(format: "duration=%.3f size=%.0fx%.0f fps=%.3f path=%@",
             duration, abs(size.width), abs(size.height), fps, videoURL.path))

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
generator.maximumSize = CGSize(width: abs(size.width), height: abs(size.height))

var times: [Double] = []
if args.count > 3 {
    times = args.dropFirst(3).compactMap(Double.init)
} else {
    var t = 0.0
    while t <= duration + 0.001 {
        times.append(t)
        t += 0.5
    }
    if let last = times.last, abs(last - duration) > 0.04 {
        times.append(max(0, duration - 0.04))
    }
}

for time in times {
    let cm = CMTime(seconds: min(max(0, time), max(0, duration - 0.001)), preferredTimescale: 600)
    do {
        let cg = try generator.copyCGImage(at: cm, actualTime: nil)
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        let name = String(format: "t-%05.2f.png", time)
        let dest = outDir.appendingPathComponent(name)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { continue }
        try png.write(to: dest)
        print("wrote \(name) \(cg.width)x\(cg.height)")
    } catch {
        fputs("failed \(time): \(error)\n", stderr)
    }
}
