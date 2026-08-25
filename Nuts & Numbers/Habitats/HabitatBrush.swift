//
//  HabitatBrush.swift
//  Nuts & Numbers
//
//  Shared drawing vocabulary for the procedural habitat cabinets. Every scene
//  is built from these primitives so the ten environments stay consistent in
//  material, lighting and level of detail while remaining entirely code-native:
//  no bitmaps, no imported artwork, only paths, curves and gradients.
//

import SwiftUI

/// Stable scatter value in `0...1`. Habitats need irregular placement that is
/// identical on every redraw and every device, so scenes index into this hash
/// instead of holding a random generator.
@inline(__always)
func habitatNoise(_ index: Int, _ channel: Int = 0) -> CGFloat {
    var state = UInt64(truncatingIfNeeded: index &* 0x9E37_79B1 &+ channel &* 0x85EB_CA77 &+ 0x2545_F491)
    state ^= state &>> 30
    state = state &* 0xBF58_476D_1CE4_E5B9
    state ^= state &>> 27
    state = state &* 0x94D0_49BB_1331_11EB
    state ^= state &>> 31
    return CGFloat(Double(state & 0xF_FFFF) / Double(0x10_0000))
}

@inline(__always)
func habitatNoise(_ index: Int, _ channel: Int, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
    lower + habitatNoise(index, channel) * (upper - lower)
}

/// One canvas' worth of geometry helpers plus the shared object primitives.
/// All placement is fractional, so a composition authored once reads the same
/// on a compact phone, a tall phone and an iPad.
struct HabitatBrush {
    let size: CGSize
    let isPad: Bool

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var minSide: CGFloat { min(size.width, size.height) }

    func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: w * fx, y: h * fy)
    }

    func rx(_ fraction: CGFloat) -> CGFloat { w * fraction }
    func ry(_ fraction: CGFloat) -> CGFloat { h * fraction }

    /// Rectangle described by its centre, in canvas fractions.
    func box(_ fx: CGFloat, _ fy: CGFloat, _ fw: CGFloat, _ fh: CGFloat) -> CGRect {
        CGRect(x: w * (fx - fw * 0.5),
               y: h * (fy - fh * 0.5),
               width: w * fw,
               height: h * fh)
    }

    /// Line weights are authored for phones and thicken on iPad, where the
    /// same composition is displayed far larger.
    func lw(_ base: CGFloat) -> CGFloat { max(0.45, base * (isPad ? 1.7 : 1)) }

    func stroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round)
    }

    func joined(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}

// MARK: - Path construction

extension HabitatBrush {
    /// Smooth closed silhouette through a ring of points. Rocks, foliage
    /// masses, clouds, ice and mud all start here, which is what keeps the
    /// scenes free of recognisable circles and rectangles.
    func blob(_ points: [CGPoint]) -> Path {
        guard points.count > 2 else { return Path() }
        var path = Path()
        let last = points[points.count - 1]
        path.move(to: CGPoint(x: (last.x + points[0].x) * 0.5,
                              y: (last.y + points[0].y) * 0.5))
        for index in 0..<points.count {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            path.addQuadCurve(to: CGPoint(x: (current.x + next.x) * 0.5,
                                          y: (current.y + next.y) * 0.5),
                              control: current)
        }
        path.closeSubpath()
        return path
    }

    /// Irregular ring of points around a centre, squashed vertically. Used for
    /// almost every natural mass in the game.
    func blobPoints(center: CGPoint,
                    radiusX: CGFloat,
                    radiusY: CGFloat,
                    count: Int = 9,
                    irregularity: CGFloat = 0.26,
                    seed: Int = 0) -> [CGPoint] {
        (0..<count).map { index in
            let angle = Double(index) / Double(count) * 2 * .pi
            let wobble = 1 - irregularity * 0.5 + habitatNoise(seed &+ index, 11) * irregularity
            return CGPoint(x: center.x + CGFloat(cos(angle)) * radiusX * wobble,
                           y: center.y + CGFloat(sin(angle)) * radiusY * wobble)
        }
    }

    /// Open ridge line, e.g. hills, dunes, reef crests or snow banks.
    func ridge(from start: CGPoint,
               to end: CGPoint,
               peaks: [(CGFloat, CGFloat)],
               floor: CGFloat) -> Path {
        var path = Path()
        path.move(to: start)
        var previous = start
        for peak in peaks {
            let point = CGPoint(x: peak.0, y: peak.1)
            path.addQuadCurve(to: point,
                              control: CGPoint(x: (previous.x + point.x) * 0.5,
                                               y: min(previous.y, point.y) - abs(point.x - previous.x) * 0.10))
            previous = point
        }
        path.addQuadCurve(to: end,
                          control: CGPoint(x: (previous.x + end.x) * 0.5,
                                           y: (previous.y + end.y) * 0.5))
        path.addLine(to: CGPoint(x: end.x, y: floor))
        path.addLine(to: CGPoint(x: start.x, y: floor))
        path.closeSubpath()
        return path
    }
}

// MARK: - Light, sky and air

extension HabitatBrush {
    /// Sun or moon with a wide falloff. The glow is painted first so the disc
    /// keeps a crisp edge inside it.
    func sun(in context: inout GraphicsContext,
             center: CGPoint,
             radius: CGFloat,
             core: Color,
             glow: Color,
             glowSpread: CGFloat = 3.4) {
        let halo = CGRect(x: center.x - radius * glowSpread,
                          y: center.y - radius * glowSpread,
                          width: radius * glowSpread * 2,
                          height: radius * glowSpread * 2)
        context.fill(Path(ellipseIn: halo),
                     with: .radialGradient(Gradient(colors: [glow, .clear]),
                                           center: center,
                                           startRadius: radius * 0.4,
                                           endRadius: radius * glowSpread))
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius,
                                            y: center.y - radius,
                                            width: radius * 2,
                                            height: radius * 2)),
                     with: .color(core))
    }

    /// Soft cumulus built from overlapping smoothed masses rather than a row
    /// of circles, with a flattened, slightly darker base.
    func cloud(in context: inout GraphicsContext,
               center: CGPoint,
               width: CGFloat,
               height: CGFloat,
               color: Color,
               shade: Color,
               seed: Int = 0) {
        var lobes: [CGPoint] = []
        let lobeCount = 5
        for index in 0..<lobeCount {
            let t = CGFloat(index) / CGFloat(lobeCount - 1)
            let lift = sin(Double(t) * .pi)
            lobes.append(CGPoint(x: center.x + (t - 0.5) * width,
                                 y: center.y - CGFloat(lift) * height * habitatNoise(seed &+ index, 3, 0.55, 1.0)))
        }
        var path = Path()
        path.move(to: CGPoint(x: center.x - width * 0.5, y: center.y))
        for index in 0..<lobes.count {
            let lobe = lobes[index]
            let next = index + 1 < lobes.count
                ? lobes[index + 1]
                : CGPoint(x: center.x + width * 0.5, y: center.y)
            path.addQuadCurve(to: CGPoint(x: (lobe.x + next.x) * 0.5,
                                          y: (lobe.y + next.y) * 0.5 - height * 0.10),
                              control: CGPoint(x: lobe.x, y: lobe.y - height * 0.22))
        }
        path.addLine(to: CGPoint(x: center.x + width * 0.5, y: center.y))
        path.addQuadCurve(to: CGPoint(x: center.x - width * 0.5, y: center.y),
                          control: CGPoint(x: center.x, y: center.y + height * 0.22))
        path.closeSubpath()
        context.fill(path, with: .linearGradient(Gradient(colors: [color, shade]),
                                                 startPoint: CGPoint(x: center.x, y: center.y - height),
                                                 endPoint: CGPoint(x: center.x, y: center.y + height * 0.3)))
    }

    /// Wedge of light falling from a source. Used for sunbeams between trunks
    /// and for underwater shafts.
    func lightShaft(in context: inout GraphicsContext,
                    topLeft: CGFloat,
                    topRight: CGFloat,
                    bottomLeft: CGFloat,
                    bottomRight: CGFloat,
                    topY: CGFloat,
                    bottomY: CGFloat,
                    color: Color) {
        var shaft = Path()
        shaft.move(to: CGPoint(x: w * topLeft, y: topY))
        shaft.addLine(to: CGPoint(x: w * topRight, y: topY))
        shaft.addLine(to: CGPoint(x: w * bottomRight, y: bottomY))
        shaft.addLine(to: CGPoint(x: w * bottomLeft, y: bottomY))
        shaft.closeSubpath()
        context.fill(shaft, with: .linearGradient(Gradient(colors: [color, .clear]),
                                                  startPoint: CGPoint(x: w * topLeft, y: topY),
                                                  endPoint: CGPoint(x: w * bottomLeft, y: bottomY)))
    }

    /// Horizontal haze band that separates two depth planes.
    func hazeBand(in context: inout GraphicsContext,
                  top: CGFloat,
                  bottom: CGFloat,
                  color: Color) {
        let rect = CGRect(x: 0, y: h * top, width: w, height: h * (bottom - top))
        context.fill(Path(rect),
                     with: .linearGradient(Gradient(colors: [.clear, color, .clear]),
                                           startPoint: CGPoint(x: 0, y: rect.minY),
                                           endPoint: CGPoint(x: 0, y: rect.maxY)))
    }

    /// Distant birds as two-stroke chevrons.
    func bird(in context: inout GraphicsContext,
              center: CGPoint,
              span: CGFloat,
              color: Color,
              lift: CGFloat = 0.42) {
        var wings = Path()
        wings.move(to: CGPoint(x: center.x - span, y: center.y + span * lift * 0.4))
        wings.addQuadCurve(to: center,
                           control: CGPoint(x: center.x - span * 0.5, y: center.y - span * lift))
        wings.addQuadCurve(to: CGPoint(x: center.x + span, y: center.y + span * lift * 0.4),
                           control: CGPoint(x: center.x + span * 0.5, y: center.y - span * lift))
        context.stroke(wings, with: .color(color), style: joined(lw(1.1)))
    }
}

// MARK: - Ground and stone

extension HabitatBrush {
    /// Soft elliptical shadow that seats an object on the ground plane.
    func contactShadow(in context: inout GraphicsContext,
                       center: CGPoint,
                       width: CGFloat,
                       height: CGFloat,
                       opacity: Double = 0.18) {
        let rect = CGRect(x: center.x - width * 0.5,
                          y: center.y - height * 0.5,
                          width: width,
                          height: height)
        context.fill(Path(ellipseIn: rect),
                     with: .radialGradient(Gradient(colors: [Color.black.opacity(opacity), .clear]),
                                           center: center,
                                           startRadius: 0,
                                           endRadius: max(width, height) * 0.5))
    }

    /// Faceted boulder with a lit shoulder and a shaded crack. Angular enough
    /// to read as stone at any size.
    func rock(in context: inout GraphicsContext,
              center: CGPoint,
              radius: CGFloat,
              light: Color,
              dark: Color,
              seed: Int = 0,
              flatten: CGFloat = 0.74,
              seated: Bool = true) {
        if seated {
            contactShadow(in: &context,
                          center: CGPoint(x: center.x, y: center.y + radius * flatten * 0.72),
                          width: radius * 2.5,
                          height: radius * 0.66,
                          opacity: 0.20)
        }
        var points: [CGPoint] = []
        let count = 8
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi - .pi * 0.5
            let jitter = habitatNoise(seed &+ index, 5, 0.76, 1.16)
            let vertical = sin(angle) > 0 ? flatten * 0.82 : flatten
            points.append(CGPoint(x: center.x + CGFloat(cos(angle)) * radius * jitter,
                                  y: center.y + CGFloat(sin(angle)) * radius * jitter * vertical))
        }
        let body = blob(points)
        context.fill(body, with: .linearGradient(
            Gradient(colors: [light, dark]),
            startPoint: CGPoint(x: center.x - radius * 0.7, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius * 0.8, y: center.y + radius)))

        // The lit shoulder is a filled cap rather than an outline; an arc
        // stroke plus a fissure below it turns every boulder into a face.
        let shoulder = blobPoints(center: CGPoint(x: center.x - radius * 0.18,
                                                  y: center.y - radius * flatten * 0.42),
                                  radiusX: radius * habitatNoise(seed, 6, 0.42, 0.58),
                                  radiusY: radius * flatten * 0.34,
                                  count: 7,
                                  irregularity: 0.34,
                                  seed: seed &+ 17)
        context.fill(blob(shoulder), with: .color(Color.white.opacity(0.12)))

        // The fissure has to be seeded: a fixed zig-zag repeated on every
        // boulder in a scene reads as a stamped tick mark rather than stone.
        let startX = center.x + radius * habitatNoise(seed, 7, -0.40, 0.36)
        let startY = center.y - radius * flatten * habitatNoise(seed, 8, 0.34, 0.70)
        let endX = startX + radius * habitatNoise(seed, 9, -0.30, 0.34)
        let endY = center.y + radius * flatten * habitatNoise(seed, 10, 0.10, 0.52)
        var fissure = Path()
        fissure.move(to: CGPoint(x: startX, y: startY))
        fissure.addQuadCurve(to: CGPoint(x: endX, y: endY),
                             control: CGPoint(x: startX + radius * habitatNoise(seed, 12, -0.26, 0.26),
                                              y: (startY + endY) * 0.5))
        context.stroke(fissure, with: .color(Color.black.opacity(0.16)), style: stroke(lw(radius * 0.04)))
    }

    /// Ground speckle grouped into small beds instead of even confetti.
    func pebbleBeds(in context: inout GraphicsContext,
                    bounds: CGRect,
                    color: Color,
                    highlight: Color,
                    clusters: Int,
                    seed: Int = 0) {
        for cluster in 0..<clusters {
            let cx = bounds.minX + habitatNoise(seed &+ cluster, 21) * bounds.width
            let cy = bounds.minY + habitatNoise(seed &+ cluster, 22) * bounds.height
            let depth = (cy - bounds.minY) / max(bounds.height, 1)
            for grain in 0..<4 {
                let gx = cx + (CGFloat(grain) - 1.5) * w * 0.007 * habitatNoise(seed &+ cluster &+ grain, 23, 0.5, 1.4)
                let gy = cy + habitatNoise(seed &+ cluster &+ grain, 24, -0.004, 0.006) * h
                let radius = max(0.6, (0.5 + depth) * (isPad ? 1.9 : 1.2))
                let dot = CGRect(x: gx, y: gy, width: radius * 1.8, height: radius)
                context.fill(Path(ellipseIn: dot),
                             with: .color(grain.isMultiple(of: 2) ? color : highlight))
            }
        }
    }

    /// Broad, low-contrast soil or sand patches. They give a flat ground plane
    /// a history instead of leaving it a clean gradient.
    func groundPatch(in context: inout GraphicsContext,
                     center: CGPoint,
                     width: CGFloat,
                     height: CGFloat,
                     color: Color,
                     seed: Int = 0) {
        let points = blobPoints(center: center,
                                radiusX: width * 0.5,
                                radiusY: height * 0.5,
                                count: 9,
                                irregularity: 0.34,
                                seed: seed)
        context.fill(blob(points), with: .color(color))
    }

    /// Perspective-scaled surface marks: sand ripples, mown lines, ice grooves.
    func surfaceStrokes(in context: inout GraphicsContext,
                        bounds: CGRect,
                        count: Int,
                        color: Color,
                        highlight: Color?,
                        lengthRange: ClosedRange<CGFloat>,
                        seed: Int = 0) {
        for index in 0..<count {
            let depth = CGFloat(index) / CGFloat(max(1, count - 1))
            let y = bounds.minY + bounds.height * (depth * 0.94 + habitatNoise(seed &+ index, 31, 0, 0.06))
            let x = bounds.minX + habitatNoise(seed &+ index, 32) * bounds.width
            let length = w * (lengthRange.lowerBound
                              + depth * (lengthRange.upperBound - lengthRange.lowerBound))
            let rise = h * (0.0014 + depth * 0.0024)
            var mark = Path()
            mark.move(to: CGPoint(x: x - length * 0.5, y: y))
            mark.addCurve(to: CGPoint(x: x + length * 0.5, y: y + rise * 0.2),
                          control1: CGPoint(x: x - length * 0.2, y: y - rise),
                          control2: CGPoint(x: x + length * 0.2, y: y + rise))
            context.stroke(mark, with: .color(color), style: stroke(lw(0.8 + depth * 0.55)))
            if let highlight {
                var lifted = context
                lifted.translateBy(x: 0, y: -lw(1.0))
                lifted.stroke(mark, with: .color(highlight), style: stroke(lw(0.55 + depth * 0.35)))
            }
        }
    }
}

// MARK: - Plants

extension HabitatBrush {
    /// Dense tuft of tapered blades with a contact shadow. The workhorse for
    /// every grassy habitat.
    func grassTuft(in context: inout GraphicsContext,
                   base: CGPoint,
                   height: CGFloat,
                   width: CGFloat,
                   colors: [Color],
                   bladeCount: Int = 9,
                   seed: Int = 0,
                   shadow: Double = 0.12) {
        if shadow > 0 {
            contactShadow(in: &context,
                          center: CGPoint(x: base.x, y: base.y),
                          width: width * 1.05,
                          height: height * 0.20,
                          opacity: shadow)
        }
        guard !colors.isEmpty else { return }
        for index in 0..<bladeCount {
            let t = bladeCount > 1 ? CGFloat(index) / CGFloat(bladeCount - 1) : 0.5
            let rootX = base.x + (t - 0.5) * width * 0.62
            let lean = (t - 0.5) * width * habitatNoise(seed &+ index, 41, 0.6, 1.15)
            let bladeHeight = height * habitatNoise(seed &+ index, 42, 0.58, 1.05)
            let bladeWidth = max(0.6, width * habitatNoise(seed &+ index, 43, 0.026, 0.052))
            let tip = CGPoint(x: rootX + lean, y: base.y - bladeHeight)
            var blade = Path()
            blade.move(to: CGPoint(x: rootX - bladeWidth * 0.5, y: base.y))
            blade.addQuadCurve(to: tip,
                               control: CGPoint(x: rootX + lean * 0.2, y: base.y - bladeHeight * 0.56))
            blade.addQuadCurve(to: CGPoint(x: rootX + bladeWidth * 0.5, y: base.y),
                               control: CGPoint(x: rootX + lean * 0.5 + bladeWidth,
                                                y: base.y - bladeHeight * 0.44))
            blade.closeSubpath()
            let color = colors[index % colors.count]
            context.fill(blade, with: .linearGradient(
                Gradient(colors: [color.opacity(0.94), color.opacity(0.60)]),
                startPoint: base,
                endPoint: tip))
        }
    }

    /// Straight-stemmed water plants; `headColor` turns them into cattails.
    func reedStand(in context: inout GraphicsContext,
                   base: CGPoint,
                   height: CGFloat,
                   spread: CGFloat,
                   count: Int,
                   stem: Color,
                   stemLight: Color,
                   headColor: Color? = nil,
                   seed: Int = 0) {
        for index in 0..<count {
            let t = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 0.5
            let offset = (t - 0.5) * spread
            let reedHeight = height * habitatNoise(seed &+ index, 51, 0.60, 1.05)
            let tip = CGPoint(x: base.x + offset * 1.25, y: base.y - reedHeight)
            var path = Path()
            path.move(to: CGPoint(x: base.x + offset, y: base.y))
            path.addQuadCurve(to: tip,
                              control: CGPoint(x: base.x + offset * 0.7, y: base.y - reedHeight * 0.5))
            context.stroke(path,
                           with: .color(index.isMultiple(of: 2) ? stemLight : stem),
                           style: stroke(max(0.7, lw(height * 0.020))))
            if let headColor, index % 3 == 1 {
                let headHeight = reedHeight * 0.20
                let head = CGRect(x: tip.x - headHeight * 0.16,
                                  y: tip.y - headHeight * 0.10,
                                  width: headHeight * 0.32,
                                  height: headHeight)
                context.fill(Path(roundedRect: head, cornerRadius: headHeight * 0.16),
                             with: .color(headColor))
                var spike = Path()
                spike.move(to: CGPoint(x: head.midX, y: head.minY))
                spike.addLine(to: CGPoint(x: head.midX, y: head.minY - headHeight * 0.42))
                context.stroke(spike, with: .color(stemLight), style: stroke(lw(0.8)))
            }
        }
    }

    /// Simple pointed leaf with a centre vein.
    func leaf(in context: inout GraphicsContext,
              center: CGPoint,
              length: CGFloat,
              angle: Double,
              color: Color,
              vein: Double = 0.16) {
        let direction = CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
        let normal = CGVector(dx: -direction.dy, dy: direction.dx)
        let tip = CGPoint(x: center.x + direction.dx * length * 0.52,
                          y: center.y + direction.dy * length * 0.52)
        let root = CGPoint(x: center.x - direction.dx * length * 0.52,
                           y: center.y - direction.dy * length * 0.52)
        var path = Path()
        path.move(to: root)
        path.addQuadCurve(to: tip,
                          control: CGPoint(x: center.x + normal.dx * length * 0.29,
                                           y: center.y + normal.dy * length * 0.29))
        path.addQuadCurve(to: root,
                          control: CGPoint(x: center.x - normal.dx * length * 0.29,
                                           y: center.y - normal.dy * length * 0.29))
        path.closeSubpath()
        context.fill(path, with: .linearGradient(
            Gradient(colors: [color.opacity(0.97), color.opacity(0.66)]),
            startPoint: root,
            endPoint: tip))
        if vein > 0 {
            var line = Path()
            line.move(to: CGPoint(x: root.x + direction.dx * length * 0.14,
                                  y: root.y + direction.dy * length * 0.14))
            line.addLine(to: CGPoint(x: tip.x - direction.dx * length * 0.12,
                                     y: tip.y - direction.dy * length * 0.12))
            context.stroke(line,
                           with: .color(Color.white.opacity(vein)),
                           style: stroke(max(0.45, length * 0.03)))
        }
    }

    /// Fern or palm frond: a curved rib carrying paired leaflets.
    func frond(in context: inout GraphicsContext,
               base: CGPoint,
               length: CGFloat,
               angle: Double,
               curl: CGFloat,
               color: Color,
               tipColor: Color,
               leaflets: Int = 9) {
        let direction = CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
        let normal = CGVector(dx: -direction.dy, dy: direction.dx)
        let tip = CGPoint(x: base.x + direction.dx * length + normal.dx * curl * length,
                          y: base.y + direction.dy * length + normal.dy * curl * length)
        let control = CGPoint(x: base.x + direction.dx * length * 0.55 + normal.dx * curl * length * 0.28,
                              y: base.y + direction.dy * length * 0.55 + normal.dy * curl * length * 0.28)
        var rib = Path()
        rib.move(to: base)
        rib.addQuadCurve(to: tip, control: control)
        context.stroke(rib, with: .color(color), style: stroke(max(0.6, lw(length * 0.020))))

        // A leafless frond is a legitimate shape: reeds and cattails arch as
        // bare ribs, so callers are allowed to ask for zero leaflets.
        guard leaflets > 0 else { return }
        for index in 1...leaflets {
            let t = CGFloat(index) / CGFloat(leaflets + 1)
            let one = CGPoint(x: base.x + (control.x - base.x) * t, y: base.y + (control.y - base.y) * t)
            let two = CGPoint(x: control.x + (tip.x - control.x) * t, y: control.y + (tip.y - control.y) * t)
            let onRib = CGPoint(x: one.x + (two.x - one.x) * t, y: one.y + (two.y - one.y) * t)
            let taper = sin(Double(t) * .pi) * 0.85 + 0.15
            let leafLength = length * 0.30 * CGFloat(taper)
            let shade = t > 0.66 ? tipColor : color
            leaf(in: &context, center: CGPoint(x: onRib.x + normal.dx * leafLength * 0.42,
                                               y: onRib.y + normal.dy * leafLength * 0.42),
                 length: leafLength, angle: angle + .pi * 0.30, color: shade, vein: 0)
            leaf(in: &context, center: CGPoint(x: onRib.x - normal.dx * leafLength * 0.42,
                                               y: onRib.y - normal.dy * leafLength * 0.42),
                 length: leafLength, angle: angle - .pi * 0.30, color: shade, vein: 0)
        }
    }

    /// Layered conifer. Skirts are jagged rather than triangular so a forest
    /// line never turns into a row of identical cones.
    func conifer(in context: inout GraphicsContext,
                 base: CGPoint,
                 height: CGFloat,
                 width: CGFloat,
                 needle: Color,
                 needleLight: Color,
                 trunk: Color?,
                 seed: Int = 0,
                 tiers: Int = 5) {
        if let trunk {
            var stem = Path()
            stem.move(to: CGPoint(x: base.x - width * 0.055, y: base.y))
            stem.addLine(to: CGPoint(x: base.x + width * 0.055, y: base.y))
            stem.addLine(to: CGPoint(x: base.x + width * 0.03, y: base.y - height * 0.30))
            stem.addLine(to: CGPoint(x: base.x - width * 0.03, y: base.y - height * 0.30))
            stem.closeSubpath()
            context.fill(stem, with: .color(trunk))
        }
        for tier in 0..<tiers {
            let t = CGFloat(tier) / CGFloat(tiers - 1)
            let tierY = base.y - height * (0.08 + t * 0.80)
            let tierWidth = width * (1 - t * 0.74) * habitatNoise(seed &+ tier, 61, 0.90, 1.08)
            let tierHeight = height * 0.30 * (1 - t * 0.42)
            var skirt = Path()
            skirt.move(to: CGPoint(x: base.x, y: tierY - tierHeight))
            let steps = 5
            for step in 0...steps {
                let st = CGFloat(step) / CGFloat(steps)
                let x = base.x + tierWidth * 0.5 * st
                let notch = step.isMultiple(of: 2) ? tierHeight * 0.10 : 0
                skirt.addLine(to: CGPoint(x: x, y: tierY - notch))
            }
            for step in stride(from: steps, through: 0, by: -1) {
                let st = CGFloat(step) / CGFloat(steps)
                let x = base.x - tierWidth * 0.5 * st
                let notch = step.isMultiple(of: 2) ? tierHeight * 0.10 : 0
                skirt.addLine(to: CGPoint(x: x, y: tierY - notch))
            }
            skirt.closeSubpath()
            context.fill(skirt, with: .linearGradient(
                Gradient(colors: [needleLight, needle]),
                startPoint: CGPoint(x: base.x - tierWidth * 0.5, y: tierY - tierHeight),
                endPoint: CGPoint(x: base.x + tierWidth * 0.5, y: tierY)))
        }
    }

    /// Rounded crown assembled from overlapping masses, with a lit top-left
    /// and a shaded underside.
    func crown(in context: inout GraphicsContext,
               center: CGPoint,
               width: CGFloat,
               height: CGFloat,
               colors: [Color],
               seed: Int = 0,
               lobes: Int = 5) {
        guard !colors.isEmpty else { return }
        for index in 0..<lobes {
            let angle = Double(index) / Double(lobes) * 2 * .pi + 0.6
            let distance = CGFloat(index == 0 ? 0 : 1)
            let lobeCenter = CGPoint(x: center.x + CGFloat(cos(angle)) * width * 0.24 * distance,
                                     y: center.y + CGFloat(sin(angle)) * height * 0.26 * distance)
            let scale = habitatNoise(seed &+ index, 71, 0.62, 0.92)
            let points = blobPoints(center: lobeCenter,
                                    radiusX: width * 0.5 * scale,
                                    radiusY: height * 0.5 * scale,
                                    count: 8,
                                    irregularity: 0.30,
                                    seed: seed &+ index &* 7)
            context.fill(blob(points), with: .color(colors[index % colors.count]))
        }
        let highlight = blobPoints(center: CGPoint(x: center.x - width * 0.16, y: center.y - height * 0.20),
                                   radiusX: width * 0.26,
                                   radiusY: height * 0.22,
                                   count: 7,
                                   irregularity: 0.34,
                                   seed: seed &+ 91)
        context.fill(blob(highlight), with: .color(Color.white.opacity(0.10)))
    }

    /// Tapered trunk with a subtle S-curve and bark grain.
    func trunk(in context: inout GraphicsContext,
               base: CGPoint,
               top: CGPoint,
               baseWidth: CGFloat,
               topWidth: CGFloat,
               bark: Color,
               barkLight: Color,
               grain: Int = 3,
               seed: Int = 0) {
        let bow = (top.x - base.x) * 0.25 + w * 0.004
        var path = Path()
        path.move(to: CGPoint(x: base.x - baseWidth * 0.5, y: base.y))
        path.addQuadCurve(to: CGPoint(x: top.x - topWidth * 0.5, y: top.y),
                          control: CGPoint(x: (base.x + top.x) * 0.5 - baseWidth * 0.5 - bow,
                                           y: (base.y + top.y) * 0.5))
        path.addLine(to: CGPoint(x: top.x + topWidth * 0.5, y: top.y))
        path.addQuadCurve(to: CGPoint(x: base.x + baseWidth * 0.5, y: base.y),
                          control: CGPoint(x: (base.x + top.x) * 0.5 + topWidth * 0.5 - bow,
                                           y: (base.y + top.y) * 0.5))
        path.closeSubpath()
        context.fill(path, with: .linearGradient(
            Gradient(colors: [bark, barkLight, bark]),
            startPoint: CGPoint(x: base.x - baseWidth * 0.5, y: base.y),
            endPoint: CGPoint(x: base.x + baseWidth * 0.5, y: base.y)))
        context.stroke(path, with: .color(Color.black.opacity(0.22)), style: joined(lw(0.9)))

        for index in 0..<grain {
            let offset = (CGFloat(index) / CGFloat(max(1, grain - 1)) - 0.5) * baseWidth * 0.56
            var line = Path()
            line.move(to: CGPoint(x: base.x + offset, y: base.y - baseWidth * 0.2))
            line.addQuadCurve(to: CGPoint(x: top.x + offset * 0.45, y: top.y + topWidth * 0.4),
                              control: CGPoint(x: (base.x + top.x) * 0.5 + offset * habitatNoise(seed &+ index, 81, -1.6, 1.6),
                                               y: (base.y + top.y) * 0.5))
            context.stroke(line,
                           with: .color(index.isMultiple(of: 2)
                                        ? Color.white.opacity(0.10)
                                        : Color.black.opacity(0.18)),
                           style: stroke(lw(0.9)))
        }
    }

    /// Flower on a stem: a ring of petals around a heart, plus two leaves.
    func flower(in context: inout GraphicsContext,
                base: CGPoint,
                height: CGFloat,
                stem: Color,
                petal: Color,
                heart: Color,
                petals: Int = 6,
                seed: Int = 0,
                lean: CGFloat = 0) {
        let head = CGPoint(x: base.x + lean * height, y: base.y - height)
        var stalk = Path()
        stalk.move(to: base)
        stalk.addQuadCurve(to: head,
                           control: CGPoint(x: base.x + lean * height * 0.2, y: base.y - height * 0.55))
        context.stroke(stalk, with: .color(stem), style: stroke(max(0.6, lw(height * 0.045))))

        let leafLength = height * 0.34
        leaf(in: &context,
             center: CGPoint(x: base.x + leafLength * 0.24, y: base.y - height * 0.34),
             length: leafLength, angle: -0.35, color: stem, vein: 0.10)
        leaf(in: &context,
             center: CGPoint(x: base.x - leafLength * 0.22, y: base.y - height * 0.52),
             length: leafLength * 0.82, angle: .pi + 0.42, color: stem, vein: 0.10)

        let petalLength = height * 0.30
        for index in 0..<petals {
            let angle = Double(index) / Double(petals) * 2 * .pi + Double(habitatNoise(seed, 95)) * 0.6
            leaf(in: &context,
                 center: CGPoint(x: head.x + CGFloat(cos(angle)) * petalLength * 0.42,
                                 y: head.y + CGFloat(sin(angle)) * petalLength * 0.42),
                 length: petalLength, angle: angle, color: petal, vein: 0)
        }
        let heartSize = height * 0.13
        context.fill(Path(ellipseIn: CGRect(x: head.x - heartSize * 0.5,
                                            y: head.y - heartSize * 0.5,
                                            width: heartSize,
                                            height: heartSize)),
                     with: .color(heart))
    }

    /// Cap-and-stem mushroom with gills and speckles.
    func mushroom(in context: inout GraphicsContext,
                  base: CGPoint,
                  height: CGFloat,
                  cap: Color,
                  capShade: Color,
                  stem: Color,
                  speckles: Bool = false,
                  seed: Int = 0) {
        let stemWidth = height * 0.26
        var stalk = Path()
        stalk.move(to: CGPoint(x: base.x - stemWidth * 0.5, y: base.y))
        stalk.addQuadCurve(to: CGPoint(x: base.x - stemWidth * 0.34, y: base.y - height * 0.62),
                           control: CGPoint(x: base.x - stemWidth * 0.62, y: base.y - height * 0.3))
        stalk.addLine(to: CGPoint(x: base.x + stemWidth * 0.34, y: base.y - height * 0.62))
        stalk.addQuadCurve(to: CGPoint(x: base.x + stemWidth * 0.5, y: base.y),
                           control: CGPoint(x: base.x + stemWidth * 0.62, y: base.y - height * 0.3))
        stalk.closeSubpath()
        context.fill(stalk, with: .color(stem))

        let capWidth = height * 0.92
        var hat = Path()
        hat.move(to: CGPoint(x: base.x - capWidth * 0.5, y: base.y - height * 0.60))
        hat.addCurve(to: CGPoint(x: base.x + capWidth * 0.5, y: base.y - height * 0.60),
                     control1: CGPoint(x: base.x - capWidth * 0.42, y: base.y - height * 1.06),
                     control2: CGPoint(x: base.x + capWidth * 0.42, y: base.y - height * 1.06))
        hat.addQuadCurve(to: CGPoint(x: base.x - capWidth * 0.5, y: base.y - height * 0.60),
                         control: CGPoint(x: base.x, y: base.y - height * 0.50))
        hat.closeSubpath()
        context.fill(hat, with: .linearGradient(
            Gradient(colors: [cap, capShade]),
            startPoint: CGPoint(x: base.x - capWidth * 0.4, y: base.y - height),
            endPoint: CGPoint(x: base.x + capWidth * 0.4, y: base.y - height * 0.6)))
        if speckles {
            for index in 0..<4 {
                let dotX = base.x + habitatNoise(seed &+ index, 101, -0.34, 0.34) * capWidth
                let dotY = base.y - height * habitatNoise(seed &+ index, 102, 0.68, 0.92)
                let dotSize = capWidth * habitatNoise(seed &+ index, 103, 0.07, 0.13)
                context.fill(Path(ellipseIn: CGRect(x: dotX - dotSize * 0.5,
                                                    y: dotY - dotSize * 0.4,
                                                    width: dotSize,
                                                    height: dotSize * 0.8)),
                             with: .color(Color.white.opacity(0.80)))
            }
        }
    }
}

// MARK: - Timber and built structures

extension HabitatBrush {
    /// Fallen log or beam drawn along an axis, with end grain on both caps.
    func log(in context: inout GraphicsContext,
             from start: CGPoint,
             to end: CGPoint,
             thickness: CGFloat,
             bark: Color,
             barkLight: Color,
             core: Color,
             showEndGrain: Bool = true,
             seed: Int = 0) {
        // A uniform round-capped stroke with a bright disc on the end reads as
        // a cannon barrel, so the trunk is built as a filled outline that
        // tapers, bows and wobbles along its length.
        let angle = atan2(end.y - start.y, end.x - start.x)
        let normal = CGVector(dx: -sin(angle), dy: cos(angle))
        let axisLength = hypot(end.x - start.x, end.y - start.y)
        let bow = thickness * habitatNoise(seed, 31, -0.30, 0.30)

        func axis(_ t: CGFloat) -> CGPoint {
            let bend = bow * sin(CGFloat.pi * t)
            return CGPoint(x: start.x + (end.x - start.x) * t + normal.dx * bend,
                           y: start.y + (end.y - start.y) * t + normal.dy * bend)
        }
        func halfWidth(_ t: CGFloat) -> CGFloat {
            let taper = 1 - 0.22 * t
            let wobble = 1 + 0.09 * sin(CGFloat(t) * 9.4 + CGFloat(habitatNoise(seed, 32, 0, 6.2)))
            return thickness * 0.5 * taper * wobble
        }

        let samples = 14
        var body = Path()
        for index in 0...samples {
            let t = CGFloat(index) / CGFloat(samples)
            let point = axis(t)
            let offset = halfWidth(t)
            let side = CGPoint(x: point.x - normal.dx * offset, y: point.y - normal.dy * offset)
            if index == 0 { body.move(to: side) } else { body.addLine(to: side) }
        }
        for index in stride(from: samples, through: 0, by: -1) {
            let t = CGFloat(index) / CGFloat(samples)
            let point = axis(t)
            let offset = halfWidth(t)
            body.addLine(to: CGPoint(x: point.x + normal.dx * offset, y: point.y + normal.dy * offset))
        }
        body.closeSubpath()

        contactShadow(in: &context,
                      center: CGPoint(x: (start.x + end.x) * 0.5,
                                      y: (start.y + end.y) * 0.5 + thickness * 0.46),
                      width: axisLength * 1.05,
                      height: thickness * 0.62,
                      opacity: 0.20)
        context.fill(body, with: .linearGradient(
            Gradient(colors: [barkLight, bark, Color.black.opacity(0.38)]),
            startPoint: CGPoint(x: start.x - normal.dx * thickness * 0.5,
                                y: start.y - normal.dy * thickness * 0.5),
            endPoint: CGPoint(x: start.x + normal.dx * thickness * 0.5,
                              y: start.y + normal.dy * thickness * 0.5)))

        // Bark ridges running with the grain, broken so they do not look like
        // pinstripes on a tube.
        for index in 0..<4 {
            let lateral = habitatNoise(seed, 33 &+ index, -0.34, 0.34)
            let from = habitatNoise(seed, 37 &+ index, 0.04, 0.34)
            let to = habitatNoise(seed, 41 &+ index, 0.58, 0.96)
            var ridge = Path()
            let a = axis(from), b = axis(to), m = axis((from + to) * 0.5)
            ridge.move(to: CGPoint(x: a.x + normal.dx * thickness * lateral,
                                   y: a.y + normal.dy * thickness * lateral))
            ridge.addQuadCurve(to: CGPoint(x: b.x + normal.dx * thickness * lateral * 0.7,
                                           y: b.y + normal.dy * thickness * lateral * 0.7),
                               control: CGPoint(x: m.x + normal.dx * thickness * lateral * 1.25,
                                                y: m.y + normal.dy * thickness * lateral * 1.25))
            context.stroke(ridge,
                           with: .color(lateral < 0 ? Color.white.opacity(0.10) : Color.black.opacity(0.17)),
                           style: stroke(max(0.6, thickness * 0.06)))
        }

        if showEndGrain {
            let cap = CGRect(x: end.x - thickness * 0.30,
                             y: end.y - thickness * 0.46,
                             width: thickness * 0.60,
                             height: thickness * 0.92)
            var local = context
            local.translateBy(x: end.x, y: end.y)
            local.rotate(by: .radians(angle))
            local.translateBy(x: -end.x, y: -end.y)
            local.fill(Path(ellipseIn: cap), with: .radialGradient(
                Gradient(colors: [core, core.opacity(0.82), bark]),
                center: CGPoint(x: cap.midX, y: cap.midY),
                startRadius: 0,
                endRadius: cap.height * 0.6))
            for ring in 1...3 {
                let inset = CGFloat(ring) * thickness * 0.075
                local.stroke(Path(ellipseIn: cap.insetBy(dx: inset * 0.9, dy: inset)),
                             with: .color(Color.black.opacity(0.13)),
                             style: stroke(max(0.5, lw(0.6))))
            }
            local.stroke(Path(ellipseIn: cap),
                         with: .color(Color.black.opacity(0.24)),
                         style: stroke(max(0.6, lw(0.8))))
        }
    }

    /// Sawn plank between two points, useful for fences, ramps and jetties.
    func plank(in context: inout GraphicsContext,
               from start: CGPoint,
               to end: CGPoint,
               thickness: CGFloat,
               wood: Color,
               woodLight: Color,
               woodDeep: Color) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let normal = CGVector(dx: -sin(angle), dy: cos(angle))
        var body = Path()
        body.move(to: CGPoint(x: start.x - normal.dx * thickness * 0.5,
                              y: start.y - normal.dy * thickness * 0.5))
        body.addLine(to: CGPoint(x: end.x - normal.dx * thickness * 0.5,
                                 y: end.y - normal.dy * thickness * 0.5))
        body.addLine(to: CGPoint(x: end.x + normal.dx * thickness * 0.5,
                                 y: end.y + normal.dy * thickness * 0.5))
        body.addLine(to: CGPoint(x: start.x + normal.dx * thickness * 0.5,
                                 y: start.y + normal.dy * thickness * 0.5))
        body.closeSubpath()
        context.fill(body, with: .linearGradient(
            Gradient(colors: [woodLight, wood, woodDeep]),
            startPoint: CGPoint(x: start.x - normal.dx * thickness * 0.5,
                                y: start.y - normal.dy * thickness * 0.5),
            endPoint: CGPoint(x: start.x + normal.dx * thickness * 0.5,
                              y: start.y + normal.dy * thickness * 0.5)))
        context.stroke(body, with: .color(Color.black.opacity(0.20)), style: joined(lw(0.8)))

        var grain = Path()
        grain.move(to: CGPoint(x: start.x + (end.x - start.x) * 0.12,
                               y: start.y + (end.y - start.y) * 0.12 - normal.dy * thickness * 0.16))
        grain.addLine(to: CGPoint(x: start.x + (end.x - start.x) * 0.88,
                                  y: start.y + (end.y - start.y) * 0.88 - normal.dy * thickness * 0.16))
        context.stroke(grain, with: .color(Color.white.opacity(0.14)), style: stroke(lw(0.7)))
    }

    /// Rope or vine with a slack curve and a highlighted twist.
    func rope(in context: inout GraphicsContext,
              from start: CGPoint,
              to end: CGPoint,
              sag: CGFloat,
              thickness: CGFloat,
              color: Color,
              highlight: Color) {
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end,
                          control: CGPoint(x: (start.x + end.x) * 0.5,
                                           y: (start.y + end.y) * 0.5 + sag))
        context.stroke(path, with: .color(Color.black.opacity(0.22)), style: stroke(thickness * 1.5))
        context.stroke(path, with: .color(color), style: stroke(thickness))
        var twist = context
        twist.translateBy(x: 0, y: -thickness * 0.24)
        twist.stroke(path, with: .color(highlight.opacity(0.5)), style: stroke(thickness * 0.34))
    }
}

// MARK: - Water and ice

extension HabitatBrush {
    /// Broken surface reflections. Deliberately interrupted so they never read
    /// as progress bars behind the gameplay.
    func waterGlints(in context: inout GraphicsContext,
                     bounds: CGRect,
                     count: Int,
                     color: Color,
                     seed: Int = 0) {
        for index in 0..<count {
            let t = CGFloat(index) / CGFloat(max(1, count - 1))
            let y = bounds.minY + bounds.height * (0.10 + t * 0.82)
            let x = bounds.minX + habitatNoise(seed &+ index, 111) * bounds.width * 0.62
            let length = bounds.width * habitatNoise(seed &+ index, 112, 0.14, 0.34)
            var glint = Path()
            glint.move(to: CGPoint(x: x, y: y))
            glint.addCurve(to: CGPoint(x: min(bounds.maxX, x + length), y: y),
                           control1: CGPoint(x: x + length * 0.3, y: y - bounds.height * 0.020),
                           control2: CGPoint(x: x + length * 0.7, y: y + bounds.height * 0.018))
            context.stroke(glint,
                           with: .color(color.opacity(0.55 - Double(t) * 0.22)),
                           style: stroke(lw(0.9 + t * 0.5)))
        }
    }

    /// Flat lily pad with a wedge notch and a rim highlight.
    func lilyPad(in context: inout GraphicsContext,
                 center: CGPoint,
                 radius: CGFloat,
                 color: Color,
                 rim: Color,
                 rotation: Double = 0) {
        var pad = Path()
        pad.addArc(center: center,
                   radius: radius,
                   startAngle: .radians(rotation + 0.32),
                   endAngle: .radians(rotation - 0.32),
                   clockwise: false)
        pad.addLine(to: center)
        pad.closeSubpath()
        var squashed = context
        squashed.translateBy(x: center.x, y: center.y)
        squashed.scaleBy(x: 1, y: 0.52)
        squashed.translateBy(x: -center.x, y: -center.y)
        squashed.fill(pad, with: .linearGradient(
            Gradient(colors: [color, rim]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)))
        squashed.stroke(pad, with: .color(Color.black.opacity(0.16)), style: joined(lw(0.8)))
        for index in 0..<5 {
            let angle = rotation + 0.55 + Double(index) * 0.98
            var vein = Path()
            vein.move(to: center)
            vein.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * radius * 0.88,
                                     y: center.y + CGFloat(sin(angle)) * radius * 0.88))
            squashed.stroke(vein, with: .color(Color.black.opacity(0.10)), style: stroke(lw(0.7)))
        }
    }

    /// Snow or ice mound with a blue shadow side.
    func snowMound(in context: inout GraphicsContext,
                   center: CGPoint,
                   width: CGFloat,
                   height: CGFloat,
                   snow: Color,
                   shade: Color,
                   seed: Int = 0) {
        var points = blobPoints(center: center,
                                radiusX: width * 0.5,
                                radiusY: height * 0.5,
                                count: 9,
                                irregularity: 0.24,
                                seed: seed)
        points = points.map { point in
            point.y > center.y ? CGPoint(x: point.x, y: center.y + (point.y - center.y) * 0.3) : point
        }
        context.fill(blob(points), with: .linearGradient(
            Gradient(colors: [snow, shade]),
            startPoint: CGPoint(x: center.x - width * 0.3, y: center.y - height * 0.6),
            endPoint: CGPoint(x: center.x + width * 0.3, y: center.y + height * 0.4)))
    }

    /// Row of icicles hanging from an edge. Roots can sit slightly inside the
    /// ledge (`embed`) so the lip covers the attachment.
    func icicles(in context: inout GraphicsContext,
                 from start: CGPoint,
                 to end: CGPoint,
                 count: Int,
                 maxLength: CGFloat,
                 color: Color,
                 tip: Color,
                 seed: Int = 0,
                 embed: CGFloat = 0) {
        var roots: [CGPoint] = []
        for index in 0..<count {
            let t = CGFloat(index) / CGFloat(max(1, count - 1))
            roots.append(CGPoint(x: start.x + (end.x - start.x) * t,
                                 y: start.y + (end.y - start.y) * t - embed))
        }
        icicles(in: &context, roots: roots, maxLength: maxLength, color: color, tip: tip, seed: seed)
    }

    func icicles(in context: inout GraphicsContext,
                 roots: [CGPoint],
                 maxLength: CGFloat,
                 color: Color,
                 tip: Color,
                 seed: Int = 0) {
        for (index, root) in roots.enumerated() {
            let length = maxLength * habitatNoise(seed &+ index, 121, 0.34, 1.0)
            let width = length * habitatNoise(seed &+ index, 122, 0.18, 0.30)
            var spike = Path()
            spike.move(to: CGPoint(x: root.x - width * 0.5, y: root.y))
            spike.addQuadCurve(to: CGPoint(x: root.x, y: root.y + length),
                               control: CGPoint(x: root.x - width * 0.18, y: root.y + length * 0.6))
            spike.addQuadCurve(to: CGPoint(x: root.x + width * 0.5, y: root.y),
                               control: CGPoint(x: root.x + width * 0.18, y: root.y + length * 0.6))
            spike.closeSubpath()
            context.fill(spike, with: .linearGradient(
                Gradient(colors: [color, tip]),
                startPoint: CGPoint(x: root.x, y: root.y),
                endPoint: CGPoint(x: root.x, y: root.y + length)))
        }
    }
}

// MARK: - Marine life

extension HabitatBrush {
    /// Branching coral built from a recursive fork pattern.
    func branchCoral(in context: inout GraphicsContext,
                     base: CGPoint,
                     height: CGFloat,
                     color: Color,
                     thickness: CGFloat,
                     seed: Int = 0) {
        func limb(_ start: CGPoint, _ angle: Double, _ length: CGFloat, _ depth: Int, _ width: CGFloat) {
            guard depth > 0, length > height * 0.05 else { return }
            let end = CGPoint(x: start.x + CGFloat(cos(angle)) * length,
                              y: start.y + CGFloat(sin(angle)) * length)
            var path = Path()
            path.move(to: start)
            path.addQuadCurve(to: end,
                              control: CGPoint(x: start.x + CGFloat(cos(angle - 0.35)) * length * 0.6,
                                               y: start.y + CGFloat(sin(angle - 0.35)) * length * 0.6))
            context.stroke(path, with: .color(color), style: stroke(max(0.6, width)))
            let spread = 0.44 + Double(habitatNoise(seed &+ depth, 131)) * 0.30
            limb(end, angle - spread, length * 0.66, depth - 1, width * 0.72)
            limb(end, angle + spread * 0.82, length * 0.62, depth - 1, width * 0.70)
            if depth <= 2 {
                let bud = max(1.2, width * 0.55)
                context.fill(Path(ellipseIn: CGRect(x: end.x - bud * 0.5, y: end.y - bud * 0.5,
                                                    width: bud, height: bud)),
                             with: .color(color.opacity(0.95)))
            }
        }
        limb(base, -.pi / 2, height * 0.44, 4, thickness)
        limb(CGPoint(x: base.x - height * 0.08, y: base.y),
             -.pi / 2 - 0.34, height * 0.32, 3, thickness * 0.8)
        limb(CGPoint(x: base.x + height * 0.09, y: base.y),
             -.pi / 2 + 0.30, height * 0.34, 3, thickness * 0.8)
    }

    /// Table coral: an irregular plate on a short stalk, rimmed with polyps
    /// so it never reads as a flat oval sticker.
    func plateCoral(in context: inout GraphicsContext,
                    base: CGPoint,
                    width: CGFloat,
                    color: Color,
                    shade: Color,
                    flipped: Bool = false,
                    seed: Int = 0) {
        let direction: CGFloat = flipped ? -1 : 1
        let plateCenter = CGPoint(x: base.x + width * 0.04,
                                  y: base.y - direction * width * 0.28)
        var stalk = Path()
        stalk.move(to: base)
        stalk.addQuadCurve(to: plateCenter,
                           control: CGPoint(x: base.x + width * 0.02,
                                            y: base.y - direction * width * 0.14))
        context.stroke(stalk, with: .color(shade), style: stroke(max(0.8, width * 0.10)))

        let plate = blobPoints(center: plateCenter,
                               radiusX: width * 0.52,
                               radiusY: width * 0.16,
                               count: 11,
                               irregularity: 0.28,
                               seed: seed)
        context.fill(blob(plate), with: .linearGradient(
            Gradient(colors: [color, shade]),
            startPoint: CGPoint(x: plateCenter.x - width * 0.5, y: plateCenter.y - width * 0.18),
            endPoint: CGPoint(x: plateCenter.x + width * 0.5, y: plateCenter.y + width * 0.18)))

        let inner = blobPoints(center: CGPoint(x: plateCenter.x - width * 0.04,
                                               y: plateCenter.y - direction * width * 0.02),
                               radiusX: width * 0.28,
                               radiusY: width * 0.08,
                               count: 8,
                               irregularity: 0.22,
                               seed: seed &+ 9)
        context.fill(blob(inner), with: .color(Color.white.opacity(0.12)))

        for index in 0..<14 {
            let angle = Double(index) / 14 * 2 * .pi + Double(habitatNoise(seed, 101))
            let reach = 0.72 + habitatNoise(seed &+ index, 102, 0, 0.22)
            let point = CGPoint(x: plateCenter.x + CGFloat(cos(angle)) * width * 0.48 * reach,
                                y: plateCenter.y + CGFloat(sin(angle)) * width * 0.15 * reach)
            let bud = width * habitatNoise(seed &+ index, 103, 0.018, 0.032)
            context.fill(Path(ellipseIn: CGRect(x: point.x - bud, y: point.y - bud * 0.7,
                                                width: bud * 2, height: bud * 1.4)),
                         with: .color(index.isMultiple(of: 3) ? Color.white.opacity(0.22) : shade.opacity(0.55)))
        }
    }

    /// Sea fan: a fan-shaped lattice growing from a short holdfast, with
    /// irregular ribs so it never reads as a drawn sunburst.
    func seaFan(in context: inout GraphicsContext,
                base: CGPoint,
                height: CGFloat,
                color: Color,
                seed: Int = 0) {
        let foot = blobPoints(center: base,
                              radiusX: height * 0.10,
                              radiusY: height * 0.055,
                              count: 6,
                              irregularity: 0.30,
                              seed: seed)
        context.fill(blob(foot), with: .color(color.opacity(0.85)))

        var tips: [CGPoint] = []
        for index in 0..<9 {
            let spread = (CGFloat(index) / 8 - 0.5) * 1.55
                + habitatNoise(seed &+ index, 140, -0.08, 0.08)
            let reach = habitatNoise(seed &+ index, 141, 0.62, 1.02)
            let tip = CGPoint(x: base.x + spread * height * 0.58,
                              y: base.y - height * reach)
            tips.append(tip)
            var rib = Path()
            rib.move(to: base)
            rib.addQuadCurve(to: tip,
                             control: CGPoint(x: base.x + spread * height * 0.18,
                                              y: base.y - height * 0.42))
            context.stroke(rib, with: .color(color),
                           style: stroke(max(0.5, height * (0.018 + (1 - abs(spread) / 1.55) * 0.028))))
        }
        for band in 0..<4 {
            let t = 0.28 + CGFloat(band) * 0.18
            var web = Path()
            for (index, tip) in tips.enumerated() {
                let point = CGPoint(x: base.x + (tip.x - base.x) * t,
                                    y: base.y + (tip.y - base.y) * t
                                        + height * habitatNoise(seed &+ band &+ index, 142, -0.012, 0.012))
                if index == 0 { web.move(to: point) } else { web.addLine(to: point) }
            }
            context.stroke(web, with: .color(color.opacity(0.55)),
                           style: stroke(max(0.4, height * 0.016)))
        }
    }

    /// Domed brain coral with meandering grooves.
    func brainCoral(in context: inout GraphicsContext,
                    center: CGPoint,
                    radius: CGFloat,
                    color: Color,
                    groove: Color,
                    seed: Int = 0) {
        let points = blobPoints(center: center,
                                radiusX: radius,
                                radiusY: radius * 0.74,
                                count: 9,
                                irregularity: 0.18,
                                seed: seed)
        context.fill(blob(points), with: .linearGradient(
            Gradient(colors: [color, groove]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)))
        for index in 0..<4 {
            let y = center.y - radius * 0.44 + CGFloat(index) * radius * 0.30
            var line = Path()
            line.move(to: CGPoint(x: center.x - radius * 0.78, y: y))
            line.addCurve(to: CGPoint(x: center.x + radius * 0.78, y: y),
                          control1: CGPoint(x: center.x - radius * 0.24, y: y - radius * 0.22),
                          control2: CGPoint(x: center.x + radius * 0.26, y: y + radius * 0.22))
            context.stroke(line, with: .color(groove.opacity(0.8)), style: stroke(max(0.5, radius * 0.10)))
        }
    }

    /// Barrel or tube sponge cluster.
    func sponge(in context: inout GraphicsContext,
                base: CGPoint,
                height: CGFloat,
                color: Color,
                shade: Color,
                tubes: Int = 3,
                seed: Int = 0) {
        for index in 0..<tubes {
            let offset = (CGFloat(index) - CGFloat(tubes - 1) * 0.5) * height * 0.36
            let tubeHeight = height * habitatNoise(seed &+ index, 151, 0.62, 1.0)
            let tubeWidth = height * habitatNoise(seed &+ index, 152, 0.24, 0.36)
            var body = Path()
            body.move(to: CGPoint(x: base.x + offset - tubeWidth * 0.5, y: base.y))
            body.addQuadCurve(to: CGPoint(x: base.x + offset - tubeWidth * 0.40, y: base.y - tubeHeight),
                              control: CGPoint(x: base.x + offset - tubeWidth * 0.62, y: base.y - tubeHeight * 0.5))
            body.addLine(to: CGPoint(x: base.x + offset + tubeWidth * 0.40, y: base.y - tubeHeight))
            body.addQuadCurve(to: CGPoint(x: base.x + offset + tubeWidth * 0.5, y: base.y),
                              control: CGPoint(x: base.x + offset + tubeWidth * 0.62, y: base.y - tubeHeight * 0.5))
            body.closeSubpath()
            context.fill(body, with: .linearGradient(
                Gradient(colors: [color, shade]),
                startPoint: CGPoint(x: base.x + offset - tubeWidth * 0.5, y: base.y - tubeHeight),
                endPoint: CGPoint(x: base.x + offset + tubeWidth * 0.5, y: base.y)))
            let mouth = CGRect(x: base.x + offset - tubeWidth * 0.40,
                               y: base.y - tubeHeight - tubeWidth * 0.16,
                               width: tubeWidth * 0.80,
                               height: tubeWidth * 0.32)
            context.fill(Path(ellipseIn: mouth), with: .color(shade.opacity(0.9)))
            context.stroke(Path(ellipseIn: mouth), with: .color(Color.white.opacity(0.16)), style: stroke(lw(0.7)))
        }
        // A sand or rock collar so the cluster sits in the ground instead of
        // hovering on a mathematical point.
        let collar = blobPoints(center: CGPoint(x: base.x, y: base.y + height * 0.04),
                                radiusX: height * 0.42,
                                radiusY: height * 0.12,
                                count: 7,
                                irregularity: 0.28,
                                seed: seed &+ 9)
        context.fill(blob(collar), with: .color(shade.opacity(0.55)))
    }

    /// Anemone: a foot with a corona of tentacles.
    func anemone(in context: inout GraphicsContext,
                 base: CGPoint,
                 radius: CGFloat,
                 color: Color,
                 tip: Color,
                 tentacles: Int = 13,
                 seed: Int = 0) {
        let foot = CGRect(x: base.x - radius * 0.52,
                          y: base.y - radius * 0.28,
                          width: radius * 1.04,
                          height: radius * 0.56)
        context.fill(Path(ellipseIn: foot), with: .color(color.opacity(0.85)))
        for index in 0..<tentacles {
            let angle = -.pi + Double(index) / Double(tentacles - 1) * .pi
            let length = radius * habitatNoise(seed &+ index, 161, 0.66, 1.14)
            let tipPoint = CGPoint(x: base.x + CGFloat(cos(angle)) * length,
                                   y: base.y + CGFloat(sin(angle)) * length * 0.94)
            var arm = Path()
            arm.move(to: base)
            arm.addQuadCurve(to: tipPoint,
                             control: CGPoint(x: base.x + CGFloat(cos(angle + 0.3)) * length * 0.6,
                                              y: base.y + CGFloat(sin(angle + 0.3)) * length * 0.6))
            context.stroke(arm, with: .color(color), style: stroke(max(0.6, radius * 0.13)))
            let bud = radius * 0.13
            context.fill(Path(ellipseIn: CGRect(x: tipPoint.x - bud * 0.5,
                                                y: tipPoint.y - bud * 0.5,
                                                width: bud,
                                                height: bud)),
                         with: .color(tip))
        }
    }

    /// Gorgonian / sea whip growing out of rock: a crusty holdfast, a tapering
    /// stem, and tiny polyp cups along it. The cups are living tissue, not a
    /// string of beads, and the stem starts inside the rock so it cannot
    /// dangle unattached in open water.
    func gorgonian(in context: inout GraphicsContext,
                   root: CGPoint,
                   length: CGFloat,
                   color: Color,
                   seed: Int = 0,
                   hanging: Bool = false) {
        if !hanging {
            let hold = blobPoints(center: root,
                                  radiusX: length * 0.16,
                                  radiusY: length * 0.10,
                                  count: 7,
                                  irregularity: 0.34,
                                  seed: seed)
            context.fill(blob(hold), with: .color(color.opacity(0.92)))
            context.fill(blob(blobPoints(center: CGPoint(x: root.x, y: root.y + length * 0.02),
                                         radiusX: length * 0.09,
                                         radiusY: length * 0.05,
                                         count: 6,
                                         irregularity: 0.28,
                                         seed: seed &+ 3)),
                         with: .color(Color.black.opacity(0.18)))
        }

        let lean = habitatNoise(seed, 201, hanging ? -0.10 : -0.16, hanging ? 0.10 : 0.16)
        let tip = CGPoint(x: root.x + length * lean, y: root.y + length)
        let normalX = -(tip.y - root.y)
        let normalY = tip.x - root.x
        let nLen = max(1, hypot(normalX, normalY))
        let nx = normalX / nLen
        let ny = normalY / nLen

        let stemHalf = hanging ? length * 0.028 : length * 0.055
        var stem = Path()
        stem.move(to: CGPoint(x: root.x - nx * stemHalf, y: root.y - ny * stemHalf))
        stem.addQuadCurve(to: tip,
                          control: CGPoint(x: root.x + (tip.x - root.x) * 0.45 - nx * length * 0.04,
                                           y: root.y + (tip.y - root.y) * 0.45 - ny * length * 0.04))
        stem.addQuadCurve(to: CGPoint(x: root.x + nx * stemHalf, y: root.y + ny * stemHalf),
                          control: CGPoint(x: root.x + (tip.x - root.x) * 0.45 + nx * length * 0.04,
                                           y: root.y + (tip.y - root.y) * 0.45 + ny * length * 0.04))
        stem.closeSubpath()
        context.fill(stem, with: .linearGradient(
            Gradient(colors: [color, color.opacity(0.55)]),
            startPoint: root,
            endPoint: tip))

        // Ceiling whips only branch on the lower half so cups never sit on the lip.
        let cupStart = hanging ? 4 : 2
        for index in cupStart...7 {
            let t = CGFloat(index) / 8
            let along = CGPoint(x: root.x + (tip.x - root.x) * t,
                                y: root.y + (tip.y - root.y) * t)
            let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let reach = length * habitatNoise(seed &+ index, 202, hanging ? 0.04 : 0.06, hanging ? 0.08 : 0.11)
            let cup = CGPoint(x: along.x + nx * reach * side,
                              y: along.y + ny * reach * side + (hanging ? length * 0.02 : 0))
            var arm = Path()
            arm.move(to: along)
            arm.addQuadCurve(to: cup,
                             control: CGPoint(x: along.x + nx * reach * side * 0.5,
                                              y: along.y + ny * reach * side * 0.5 + length * (hanging ? 0.03 : -0.02)))
            context.stroke(arm, with: .color(color.opacity(0.85)),
                           style: stroke(max(0.5, length * 0.028)))
        }
    }
    func kelp(in context: inout GraphicsContext,
              base: CGPoint,
              height: CGFloat,
              sway: CGFloat,
              color: Color,
              blade: Color,
              seed: Int = 0) {
        let tip = CGPoint(x: base.x + sway * height, y: base.y - height)
        let hold = blobPoints(center: CGPoint(x: base.x, y: base.y + height * 0.02),
                              radiusX: height * 0.06,
                              radiusY: height * 0.025,
                              count: 6,
                              irregularity: 0.30,
                              seed: seed)
        context.fill(blob(hold), with: .color(color.opacity(0.90)))
        var stipe = Path()
        stipe.move(to: base)
        stipe.addCurve(to: tip,
                       control1: CGPoint(x: base.x - sway * height * 0.35, y: base.y - height * 0.36),
                       control2: CGPoint(x: base.x + sway * height * 1.1, y: base.y - height * 0.72))
        context.stroke(stipe, with: .color(color), style: stroke(max(0.8, lw(height * 0.016))))

        let blades = 7
        for index in 1...blades {
            let t = CGFloat(index) / CGFloat(blades + 1)
            let point = CGPoint(x: base.x + (tip.x - base.x) * t + sway * height * sin(Double(t) * .pi) * 0.3,
                                y: base.y - height * t)
            let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let bladeLength = height * habitatNoise(seed &+ index, 171, 0.16, 0.28)
            leaf(in: &context,
                 center: CGPoint(x: point.x + side * bladeLength * 0.42, y: point.y - bladeLength * 0.08),
                 length: bladeLength,
                 angle: side > 0 ? -0.22 : .pi + 0.22,
                 color: blade,
                 vein: 0.08)
        }
    }

    /// Small side-on fish with a triangular tail. `flick` bends the tail so a
    /// swimming fish never sits as a frozen silhouette.
    func fish(in context: inout GraphicsContext,
              center: CGPoint,
              length: CGFloat,
              color: Color,
              belly: Color,
              facingRight: Bool = true,
              flick: CGFloat = 0) {
        let direction: CGFloat = facingRight ? 1 : -1
        var body = Path()
        body.move(to: CGPoint(x: center.x + direction * length * 0.5, y: center.y))
        body.addQuadCurve(to: CGPoint(x: center.x - direction * length * 0.36, y: center.y + flick * length * 0.08),
                          control: CGPoint(x: center.x, y: center.y - length * 0.28))
        body.addQuadCurve(to: CGPoint(x: center.x + direction * length * 0.5, y: center.y),
                          control: CGPoint(x: center.x, y: center.y + length * 0.26))
        body.closeSubpath()
        context.fill(body, with: .linearGradient(
            Gradient(colors: [color, belly]),
            startPoint: CGPoint(x: center.x, y: center.y - length * 0.28),
            endPoint: CGPoint(x: center.x, y: center.y + length * 0.26)))

        let tailBend = flick * length * 0.22
        var tail = Path()
        tail.move(to: CGPoint(x: center.x - direction * length * 0.32, y: center.y))
        tail.addLine(to: CGPoint(x: center.x - direction * length * 0.56,
                                 y: center.y - length * 0.20 + tailBend))
        tail.addLine(to: CGPoint(x: center.x - direction * length * 0.56,
                                 y: center.y + length * 0.20 + tailBend))
        tail.closeSubpath()
        context.fill(tail, with: .color(color.opacity(0.92)))

        let eye = length * 0.07
        context.fill(Path(ellipseIn: CGRect(x: center.x + direction * length * 0.28 - eye * 0.5,
                                            y: center.y - length * 0.055,
                                            width: eye,
                                            height: eye)),
                     with: .color(Color.black.opacity(0.55)))
    }

    /// Spiral sea shell.
    func shell(in context: inout GraphicsContext,
               center: CGPoint,
               radius: CGFloat,
               color: Color,
               shade: Color) {
        var body = Path()
        body.move(to: CGPoint(x: center.x - radius, y: center.y + radius * 0.45))
        body.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius * 0.75),
                          control: CGPoint(x: center.x - radius * 0.95, y: center.y - radius * 0.55))
        body.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y + radius * 0.45),
                          control: CGPoint(x: center.x + radius * 0.95, y: center.y - radius * 0.55))
        body.closeSubpath()
        context.fill(body, with: .linearGradient(
            Gradient(colors: [color, shade]),
            startPoint: CGPoint(x: center.x, y: center.y - radius),
            endPoint: CGPoint(x: center.x, y: center.y + radius * 0.5)))
        for index in 0..<4 {
            let spread = (CGFloat(index) / 3 - 0.5) * 1.5
            var rib = Path()
            rib.move(to: CGPoint(x: center.x + spread * radius * 0.7, y: center.y + radius * 0.42))
            rib.addQuadCurve(to: CGPoint(x: center.x + spread * radius * 0.16, y: center.y - radius * 0.62),
                             control: CGPoint(x: center.x + spread * radius * 0.5, y: center.y - radius * 0.1))
            context.stroke(rib, with: .color(shade.opacity(0.55)), style: stroke(max(0.4, radius * 0.09)))
        }
    }

    /// Five-armed starfish.
    func starfish(in context: inout GraphicsContext,
                  center: CGPoint,
                  radius: CGFloat,
                  color: Color,
                  shade: Color,
                  rotation: Double = 0) {
        var path = Path()
        for index in 0..<10 {
            let angle = rotation + Double(index) / 10 * 2 * .pi - .pi / 2
            let r = index.isMultiple(of: 2) ? radius : radius * 0.42
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * r,
                                y: center.y + CGFloat(sin(angle)) * r * 0.62)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        context.fill(path, with: .linearGradient(
            Gradient(colors: [color, shade]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)))
        for index in 0..<3 {
            let dot = radius * 0.10
            let angle = rotation + Double(index) * 2.1
            context.fill(Path(ellipseIn: CGRect(x: center.x + CGFloat(cos(angle)) * radius * 0.22 - dot * 0.5,
                                                y: center.y + CGFloat(sin(angle)) * radius * 0.14 - dot * 0.5,
                                                width: dot,
                                                height: dot)),
                         with: .color(Color.white.opacity(0.24)))
        }
    }

    /// Sea urchin: a dark dome behind a corona of spines.
    func urchin(in context: inout GraphicsContext,
                center: CGPoint,
                radius: CGFloat,
                color: Color,
                spine: Color,
                seed: Int = 0) {
        for index in 0..<14 {
            let angle = -.pi + Double(index) / 13 * .pi
            let length = radius * habitatNoise(seed &+ index, 181, 1.2, 1.9)
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * length,
                                       y: center.y + CGFloat(sin(angle)) * length * 0.9))
            context.stroke(needle, with: .color(spine), style: stroke(max(0.45, radius * 0.11)))
        }
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.7,
                                            y: center.y - radius * 0.58,
                                            width: radius * 1.4,
                                            height: radius * 1.1)),
                     with: .color(color))
    }
}
