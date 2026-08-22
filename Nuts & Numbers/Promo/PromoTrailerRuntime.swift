//
//  PromoTrailerRuntime.swift
//  Nuts & Numbers
//
//  Development-only App Store teaser entry. Activated solely by launch
//  arguments so Release production gameplay is untouched.
//

import Foundation
import CoreGraphics

enum PromoTrailerRuntime {
    /// `-PromoTrailer` enables the deterministic teaser host.
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-PromoTrailer")
    }

    /// `-PromoSize=886x1920` or `1200x1600`. Defaults to iPhone teaser size.
    static var exportSize: CGSize {
        let prefix = "-PromoSize="
        let value = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
        switch value {
        case "1200x1600":
            return CGSize(width: 1200, height: 1600)
        default:
            return CGSize(width: 886, height: 1920)
        }
    }

    /// Logical SwiftUI layout matching real device proportions so claw / nut /
    /// HUD sizes match production. The recorder scales this up to `exportSize`.
    static var layoutSize: CGSize {
        switch (Int(exportSize.width), Int(exportSize.height)) {
        case (1200, 1600):
            return CGSize(width: 834, height: 1_112)
        default:
            return CGSize(width: 393, height: 852)
        }
    }

    static var exportTag: String {
        let size = exportSize
        return "\(Int(size.width))x\(Int(size.height))"
    }

    static var exportFileName: String {
        "claw-math-app-store-teaser-\(exportTag).mp4"
    }

    /// iPad composition uses the game's pad metrics. iPhone teasers use phone
    /// metrics so the cabinet, nuts and controls match real gameplay size.
    static var usesPadMetrics: Bool {
        exportSize.width >= 1000
    }

    static var framesPerSecond: Int { 30 }

    /// Soft ceiling past the ~20–24s target so the icon beat is never clipped.
    static var maximumDuration: TimeInterval { 26 }
}
