//
//  PenguinIceHabitat.swift
//  Nuts & Numbers
//
//  Polar coast under a low sun: a glacier front across the horizon, open sea
//  with floes behind, and a wind-carved ice shelf in front. A dive hole holds
//  the middle of the frame quiet while seracs and icicles frame the edges.
//

import SwiftUI

struct PenguinIceHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let skyTop = Color(red: 0.28, green: 0.42, blue: 0.70)
    private let skyMid = Color(red: 0.64, green: 0.74, blue: 0.89)
    private let skyLow = Color(red: 0.99, green: 0.88, blue: 0.79)
    private let snowWhite = Color(red: 0.98, green: 0.99, blue: 1.0)
    private let snowShade = Color(red: 0.80, green: 0.87, blue: 0.95)
    private let snowBlue = Color(red: 0.66, green: 0.78, blue: 0.90)
    private let iceBlue = Color(red: 0.58, green: 0.80, blue: 0.92)
    private let iceDeep = Color(red: 0.26, green: 0.51, blue: 0.72)
    private let crevasse = Color(red: 0.13, green: 0.38, blue: 0.63)
    private let sea = Color(red: 0.07, green: 0.21, blue: 0.35)
    private let seaLight = Color(red: 0.21, green: 0.43, blue: 0.57)
    private let rock = Color(red: 0.34, green: 0.34, blue: 0.38)
    private let rockDark = Color(red: 0.15, green: 0.16, blue: 0.20)

    var body: some View {
        Canvas { context, size in
            let brush = HabitatBrush(size: size, isPad: isPad)
            paintSky(brush, in: &context)
            paintDistantPeaks(brush, in: &context)
            paintGlacierFront(brush, in: &context)
            paintSea(brush, in: &context)
            paintFloes(brush, in: &context)
            paintIceShelf(brush, in: &context)
            paintShelfTexture(brush, in: &context)
            paintDiveHole(brush, in: &context)
            paintRookery(brush, in: &context)
            paintLeftSeracs(brush, in: &context)
            paintRightCliff(brush, in: &context)
            paintTopOverhang(brush, in: &context)
            paintForeground(brush, in: &context)
        }
        .overlay {
            LinearGradient(colors: [.white.opacity(0.08),
                                    .clear,
                                    character.deepColor.opacity(0.05)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Sky

    private func paintSky(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        context.fill(Path(CGRect(origin: .zero, size: brush.size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: skyTop, location: 0),
                            .init(color: skyMid, location: 0.28),
                            .init(color: Color(red: 0.87, green: 0.85, blue: 0.90), location: 0.40),
                            .init(color: skyLow, location: 0.49)
                        ]),
                        startPoint: brush.p(0.5, 0),
                        endPoint: brush.p(0.5, 0.52)))

        // Low sun sitting just above the ice, warming the horizon.
        brush.sun(in: &context,
                  center: brush.p(0.685, 0.415),
                  radius: brush.rx(0.052),
                  core: Color(red: 1.0, green: 0.94, blue: 0.82).opacity(0.82),
                  glow: Color(red: 1.0, green: 0.82, blue: 0.62).opacity(0.34),
                  glowSpread: 4.6)

        // High cirrus, kept above the cornice and out of the right-hand
        // undercut so they cannot read as a seam through the icicles.
        for index in 0..<5 {
            let y = 0.042 + CGFloat(index) * 0.022
            let x = habitatNoise(index, 3, 0.08, 0.38)
            let length = habitatNoise(index, 4, 0.22, 0.40)
            var streak = Path()
            streak.move(to: brush.p(x, y))
            streak.addCurve(to: brush.p(min(0.72, x + length), y + habitatNoise(index, 5, -0.008, 0.008)),
                            control1: brush.p(x + length * 0.32, y - 0.010),
                            control2: brush.p(x + length * 0.70, y + 0.008))
            context.stroke(streak,
                           with: .color(Color.white.opacity(index.isMultiple(of: 2) ? 0.26 : 0.15)),
                           style: brush.stroke(brush.lw(1.4 + CGFloat(index % 3) * 0.6)))
        }

        // Pale aurora ribbons hanging in the upper sky. Kept faint so the
        // scene still reads as daylight.
        for index in 0..<2 {
            var ribbon = Path()
            let y = 0.040 + CGFloat(index) * 0.036
            ribbon.move(to: brush.p(0.06, y + 0.022))
            ribbon.addCurve(to: brush.p(0.70, y + 0.012),
                            control1: brush.p(0.26, y - 0.036),
                            control2: brush.p(0.50, y + 0.048))
            context.stroke(ribbon,
                           with: .linearGradient(
                            Gradient(colors: [.clear,
                                              Color(red: 0.58, green: 0.94, blue: 0.80).opacity(0.14),
                                              Color(red: 0.70, green: 0.82, blue: 0.98).opacity(0.08),
                                              .clear]),
                            startPoint: brush.p(0, y),
                            endPoint: brush.p(0.72, y)),
                           style: brush.stroke(brush.ry(0.026 - CGFloat(index) * 0.006)))
        }
    }

    private func paintDistantPeaks(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var peaks = Path()
        peaks.move(to: brush.p(-0.02, 0.470))
        peaks.addLine(to: brush.p(0.09, 0.362))
        peaks.addLine(to: brush.p(0.20, 0.428))
        peaks.addLine(to: brush.p(0.33, 0.330))
        peaks.addLine(to: brush.p(0.46, 0.420))
        peaks.addLine(to: brush.p(0.60, 0.372))
        peaks.addLine(to: brush.p(0.76, 0.436))
        peaks.addLine(to: brush.p(0.89, 0.352))
        peaks.addLine(to: brush.p(1.02, 0.446))
        peaks.addLine(to: brush.p(1.02, 0.520))
        peaks.addLine(to: brush.p(-0.02, 0.520))
        peaks.closeSubpath()
        context.fill(peaks, with: .linearGradient(
            Gradient(colors: [Color(red: 0.86, green: 0.90, blue: 0.96),
                              Color(red: 0.56, green: 0.68, blue: 0.82)]),
            startPoint: brush.p(0.5, 0.33),
            endPoint: brush.p(0.5, 0.50)))

        // Shaded flanks facing away from the low sun.
        for index in 0..<4 {
            let x: CGFloat = [0.09, 0.33, 0.60, 0.89][index]
            let top: CGFloat = [0.362, 0.330, 0.372, 0.352][index]
            var flank = Path()
            flank.move(to: brush.p(x, top))
            flank.addLine(to: brush.p(x - 0.075, top + 0.095))
            flank.addLine(to: brush.p(x - 0.020, top + 0.098))
            flank.closeSubpath()
            context.fill(flank, with: .color(Color(red: 0.48, green: 0.60, blue: 0.78).opacity(0.55)))
        }
        brush.hazeBand(in: &context, top: 0.430, bottom: 0.510, color: Color.white.opacity(0.34))
    }

    private func paintGlacierFront(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A calving front: vertical ice cliffs meeting the sea, with blue
        // crevasses cut into the face.
        // The skyline is a run of calved blocks of different widths and
        // heights. A regular up-down zigzag reads as a picket fence.
        let profile: [(CGFloat, CGFloat)] = [
            (-0.02, 0.472), (0.045, 0.468), (0.052, 0.446), (0.128, 0.451),
            (0.136, 0.469), (0.205, 0.464), (0.262, 0.441), (0.334, 0.447),
            (0.342, 0.470), (0.398, 0.466), (0.404, 0.452), (0.487, 0.455),
            (0.560, 0.473), (0.618, 0.470), (0.626, 0.449), (0.702, 0.454),
            (0.766, 0.443), (0.838, 0.449), (0.846, 0.471), (0.918, 0.467),
            (0.962, 0.452), (1.02, 0.456)
        ]
        var front = Path()
        front.move(to: brush.p(profile[0].0, profile[0].1))
        for point in profile.dropFirst() { front.addLine(to: brush.p(point.0, point.1)) }
        front.addLine(to: brush.p(1.02, 0.545))
        front.addLine(to: brush.p(-0.02, 0.545))
        front.closeSubpath()
        context.fill(front, with: .linearGradient(
            Gradient(colors: [snowWhite, iceBlue, iceDeep]),
            startPoint: brush.p(0.5, 0.445),
            endPoint: brush.p(0.5, 0.545)))

        // Crevasses cluster where blocks have parted, and most of them stop
        // short of the waterline.
        let cracks: [CGFloat] = [0.048, 0.061, 0.134, 0.258, 0.271, 0.281,
                                 0.340, 0.406, 0.492, 0.556, 0.624, 0.636,
                                 0.762, 0.774, 0.844, 0.958]
        for (index, x) in cracks.enumerated() {
            let top = 0.458 + habitatNoise(index, 12, -0.008, 0.008)
            let bottom = top + habitatNoise(index, 16, 0.028, 0.086)
            var crack = Path()
            crack.move(to: brush.p(x, top))
            crack.addQuadCurve(to: brush.p(x + habitatNoise(index, 13, -0.010, 0.010), min(bottom, 0.542)),
                               control: brush.p(x + habitatNoise(index, 17, -0.006, 0.006),
                                                (top + bottom) * 0.5))
            context.stroke(crack,
                           with: .color(crevasse.opacity(habitatNoise(index, 14, 0.20, 0.48))),
                           style: brush.stroke(brush.lw(habitatNoise(index, 15, 0.7, 1.9))))
        }

        // Bright lip along the top of the front.
        var lip = Path()
        lip.move(to: brush.p(profile[0].0, profile[0].1))
        for point in profile.dropFirst() { lip.addLine(to: brush.p(point.0, point.1)) }
        context.stroke(lip, with: .color(Color.white.opacity(0.85)), style: brush.joined(brush.lw(2.0)))
    }

    // MARK: - Sea

    private func paintSea(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var water = Path()
        water.move(to: brush.p(-0.02, 0.542))
        water.addQuadCurve(to: brush.p(1.02, 0.538), control: brush.p(0.5, 0.552))
        water.addLine(to: brush.p(1.02, 0.640))
        water.addLine(to: brush.p(-0.02, 0.645))
        water.closeSubpath()
        context.fill(water, with: .linearGradient(
            Gradient(colors: [seaLight, sea]),
            startPoint: brush.p(0.5, 0.538),
            endPoint: brush.p(0.5, 0.645)))

        // The sun lays a broken track of light across the water.
        for index in 0..<7 {
            let y = 0.552 + CGFloat(index) * 0.012
            let half = brush.rx(0.020 + CGFloat(index) * 0.011)
            var dash = Path()
            dash.move(to: CGPoint(x: brush.rx(0.685) - half, y: brush.ry(y)))
            dash.addLine(to: CGPoint(x: brush.rx(0.685) + half, y: brush.ry(y)))
            context.stroke(dash,
                           with: .color(Color(red: 1.0, green: 0.92, blue: 0.78).opacity(0.42 - Double(index) * 0.045)),
                           style: brush.stroke(brush.lw(1.4)))
        }
        brush.waterGlints(in: &context,
                          bounds: CGRect(x: 0, y: brush.ry(0.548),
                                         width: brush.w, height: brush.ry(0.085)),
                          count: 7,
                          color: Color.white.opacity(0.40),
                          seed: 31)
    }

    private func paintFloes(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        let floes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.085, 0.578, 0.140, 0.022), (0.245, 0.600, 0.115, 0.020),
            (0.400, 0.572, 0.090, 0.016), (0.520, 0.612, 0.130, 0.024),
            (0.815, 0.588, 0.120, 0.020), (0.945, 0.618, 0.105, 0.022)
        ]
        for (index, floe) in floes.enumerated() {
            let center = brush.p(floe.0, floe.1)
            var points = brush.blobPoints(center: center,
                                          radiusX: brush.rx(floe.2 * 0.5),
                                          radiusY: brush.ry(floe.3 * 0.5),
                                          count: 8,
                                          irregularity: 0.42,
                                          seed: 100 &+ index &* 7)
            points = points.map { CGPoint(x: $0.x, y: min($0.y, center.y + brush.ry(floe.3 * 0.3))) }
            context.fill(brush.blob(points), with: .linearGradient(
                Gradient(colors: [snowWhite, snowShade]),
                startPoint: CGPoint(x: center.x, y: center.y - brush.ry(floe.3)),
                endPoint: CGPoint(x: center.x, y: center.y + brush.ry(floe.3 * 0.4))))
            // Submerged shelf glowing turquoise just under each floe.
            let shelf = CGRect(x: center.x - brush.rx(floe.2 * 0.62),
                               y: center.y + brush.ry(floe.3 * 0.18),
                               width: brush.rx(floe.2 * 1.24),
                               height: brush.ry(floe.3 * 0.70))
            context.fill(Path(ellipseIn: shelf), with: .color(iceBlue.opacity(0.30)))
        }
    }

    // MARK: - Shelf

    private func paintIceShelf(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var shelf = Path()
        shelf.move(to: brush.p(-0.02, 0.628))
        shelf.addCurve(to: brush.p(0.40, 0.652),
                       control1: brush.p(0.12, 0.612),
                       control2: brush.p(0.26, 0.664))
        shelf.addCurve(to: brush.p(1.02, 0.624),
                       control1: brush.p(0.62, 0.640),
                       control2: brush.p(0.84, 0.668))
        shelf.addLine(to: brush.p(1.02, 1.04))
        shelf.addLine(to: brush.p(-0.02, 1.04))
        shelf.closeSubpath()
        context.fill(shelf, with: .linearGradient(
            Gradient(stops: [
                .init(color: snowWhite, location: 0),
                .init(color: Color(red: 0.93, green: 0.96, blue: 0.99), location: 0.32),
                .init(color: snowShade, location: 0.72),
                .init(color: snowBlue, location: 1)
            ]),
            startPoint: brush.p(0.5, 0.62),
            endPoint: brush.p(0.5, 1)))

        // The cut edge of the shelf where it meets the sea.
        var edge = Path()
        edge.move(to: brush.p(-0.02, 0.628))
        edge.addCurve(to: brush.p(0.40, 0.652),
                      control1: brush.p(0.12, 0.612),
                      control2: brush.p(0.26, 0.664))
        edge.addCurve(to: brush.p(1.02, 0.624),
                      control1: brush.p(0.62, 0.640),
                      control2: brush.p(0.84, 0.668))
        context.stroke(edge, with: .color(iceBlue.opacity(0.65)), style: brush.stroke(brush.lw(2.4)))
        var underside = context
        underside.translateBy(x: 0, y: brush.lw(2.6))
        underside.stroke(edge, with: .color(crevasse.opacity(0.28)), style: brush.stroke(brush.lw(1.6)))
    }

    private func paintShelfTexture(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Sastrugi: wind-carved scallops that get larger toward the viewer.
        brush.surfaceStrokes(in: &context,
                             bounds: CGRect(x: 0, y: brush.ry(0.660),
                                            width: brush.w, height: brush.ry(0.22)),
                             count: 14,
                             color: snowBlue.opacity(0.32),
                             highlight: nil,
                             lengthRange: 0.04...0.12,
                             seed: 51)

        // Broad, soft drifts.
        let drifts: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.16, 0.700, 0.34, 0.055), (0.78, 0.720, 0.32, 0.060),
            (0.36, 0.830, 0.40, 0.085), (0.88, 0.880, 0.36, 0.070)
        ]
        for (index, drift) in drifts.enumerated() {
            brush.snowMound(in: &context,
                            center: brush.p(drift.0, drift.1),
                            width: brush.rx(drift.2),
                            height: brush.ry(drift.3),
                            snow: Color.white.opacity(0.72),
                            shade: snowBlue.opacity(0.34),
                            seed: 200 &+ index &* 9)
        }

        // Blue melt cracks in the older ice.
        for index in 0..<6 {
            let x = habitatNoise(index, 21, 0.08, 0.92)
            let y = habitatNoise(index, 22, 0.680, 0.860)
            let length = habitatNoise(index, 23, 0.04, 0.12)
            var crack = Path()
            crack.move(to: brush.p(x, y))
            crack.addLine(to: brush.p(x + length * 0.6, y + 0.014))
            crack.addLine(to: brush.p(x + length, y - 0.008))
            context.stroke(crack,
                           with: .color(crevasse.opacity(0.22)),
                           style: brush.stroke(brush.lw(1.1)))
        }

        // Boulders along the waterline, banked into the shelf with a single
        // snowdrift rather than a cap on every stone.
        paintStoneHeap(brush, in: &context,
                       origin: brush.p(0.228, 0.708),
                       seed: 300)
        paintStoneHeap(brush, in: &context,
                       origin: brush.p(0.702, 0.696),
                       seed: 318)
    }

    private func paintDiveHole(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A lead in the ice. Dark, still and low in contrast against the snow,
        // so it reads as depth rather than as an obstacle.
        let center = brush.p(0.505, 0.775)
        let rim = brush.blobPoints(center: center,
                                   radiusX: brush.rx(0.180),
                                   radiusY: brush.ry(0.070),
                                   count: 10,
                                   irregularity: 0.22,
                                   seed: 401)
        context.fill(brush.blob(rim), with: .linearGradient(
            Gradient(colors: [iceBlue.opacity(0.75), snowShade.opacity(0.9)]),
            startPoint: CGPoint(x: center.x, y: center.y - brush.ry(0.07)),
            endPoint: CGPoint(x: center.x, y: center.y + brush.ry(0.07))))

        let waterPoints = brush.blobPoints(center: center,
                                           radiusX: brush.rx(0.148),
                                           radiusY: brush.ry(0.054),
                                           count: 10,
                                           irregularity: 0.18,
                                           seed: 402)
        context.fill(brush.blob(waterPoints), with: .linearGradient(
            Gradient(colors: [Color(red: 0.20, green: 0.44, blue: 0.58),
                              Color(red: 0.05, green: 0.17, blue: 0.30)]),
            startPoint: CGPoint(x: center.x, y: center.y - brush.ry(0.05)),
            endPoint: CGPoint(x: center.x, y: center.y + brush.ry(0.05))))

        // Sky reflected in the lead: broken horizontal glints of different
        // lengths, offset from the centre. Concentric arcs turned the hole
        // into a shooting target.
        let glints: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (-0.052, -0.026, 0.086, 0.26), (0.058, -0.004, 0.052, 0.18),
            (-0.086, 0.020, 0.044, 0.14), (0.014, 0.032, 0.068, 0.11)
        ]
        for glint in glints {
            let y = center.y + brush.ry(glint.1)
            var ripple = Path()
            ripple.move(to: CGPoint(x: center.x + brush.rx(glint.0), y: y))
            ripple.addQuadCurve(to: CGPoint(x: center.x + brush.rx(glint.0 + glint.2), y: y),
                                control: CGPoint(x: center.x + brush.rx(glint.0 + glint.2 * 0.5),
                                                 y: y - brush.ry(0.005)))
            context.stroke(ripple,
                           with: .color(Color.white.opacity(glint.3)),
                           style: brush.stroke(brush.lw(1.0)))
        }

        // Broken ice pushed up on the far rim only, so the near stones
        // around the lead are not ringed by polygonal plates.
        for index in 0..<4 {
            let angle = -.pi * 0.12 + Double(index) / 3 * .pi * 0.55
                + Double(habitatNoise(index, 30, -0.06, 0.06))
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * brush.rx(0.176),
                                y: center.y + CGFloat(sin(angle)) * brush.ry(0.062) - brush.ry(0.012))
            let size = brush.rx(habitatNoise(index, 31, 0.016, 0.028))
            var block = Path()
            block.move(to: CGPoint(x: point.x - size, y: point.y + size * 0.22))
            block.addLine(to: CGPoint(x: point.x - size * 0.50, y: point.y - size * 0.48))
            block.addLine(to: CGPoint(x: point.x + size * 0.70, y: point.y - size * 0.26))
            block.addLine(to: CGPoint(x: point.x + size * 0.88, y: point.y + size * 0.28))
            block.closeSubpath()
            context.fill(block, with: .linearGradient(
                Gradient(colors: [snowWhite, iceBlue.opacity(0.85)]),
                startPoint: CGPoint(x: point.x - size, y: point.y - size),
                endPoint: CGPoint(x: point.x + size, y: point.y + size)))
        }
    }

    private func paintRookery(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Irregular heaps on the snow, not dotted rings with a cap on each stone.
        paintStoneHeap(brush, in: &context, origin: brush.p(0.155, 0.828), seed: 420)
        paintStoneHeap(brush, in: &context, origin: brush.p(0.286, 0.878), seed: 437)
        paintStoneHeap(brush, in: &context, origin: brush.p(0.822, 0.848), seed: 454)

        // Two-toed tracks walking away from the dive hole, kept clear of the heaps.
        for track in 0..<2 {
            let startX: CGFloat = track == 0 ? 0.390 : 0.640
            let startY: CGFloat = track == 0 ? 0.900 : 0.938
            let drift: CGFloat = track == 0 ? -0.040 : 0.055
            for step in 0..<5 {
                let t = CGFloat(step) / 4
                let point = brush.p(startX + drift * t, startY + t * 0.042)
                let side: CGFloat = step.isMultiple(of: 2) ? -1 : 1
                for toe in 0..<2 {
                    let angle = -Double.pi * 0.5 + Double(toe) * 0.55 - 0.22
                    var print = Path()
                    print.move(to: CGPoint(x: point.x + side * brush.rx(0.010), y: point.y))
                    print.addLine(to: CGPoint(x: point.x + side * brush.rx(0.010)
                                              + CGFloat(cos(angle)) * brush.rx(0.012),
                                              y: point.y + CGFloat(sin(angle)) * brush.ry(0.010)))
                    context.stroke(print,
                                   with: .color(snowBlue.opacity(0.42)),
                                   style: brush.stroke(brush.lw(0.9)))
                }
            }
        }
    }

    /// A small pile of stones on the snow: overlapping, uneven, no dish of
    /// shadow or snow around the group.
    private func paintStoneHeap(_ brush: HabitatBrush,
                                in context: inout GraphicsContext,
                                origin: CGPoint,
                                seed: Int) {
        let layout: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.022, 0.010, 0.032), (0.014, 0.014, 0.024),
            (-0.002, -0.008, 0.020), (0.030, 0.002, 0.017),
            (-0.032, 0.000, 0.018)
        ]
        for (index, spec) in layout.enumerated() {
            brush.rock(in: &context,
                       center: CGPoint(x: origin.x + brush.rx(spec.0),
                                       y: origin.y + brush.ry(spec.1)),
                       radius: brush.rx(spec.2),
                       light: index.isMultiple(of: 2)
                            ? Color(red: 0.44, green: 0.44, blue: 0.49)
                            : Color(red: 0.28, green: 0.29, blue: 0.34),
                       dark: rockDark,
                       seed: seed &+ index &* 11,
                       flatten: 0.58,
                       seated: false)
        }
        // A drift against one side of the pile, not a ring under it.
        brush.snowMound(in: &context,
                        center: CGPoint(x: origin.x - brush.rx(0.020),
                                        y: origin.y + brush.ry(0.018)),
                        width: brush.rx(0.048),
                        height: brush.ry(0.018),
                        snow: snowWhite.opacity(0.88),
                        shade: snowBlue.opacity(0.40),
                        seed: seed &+ 40)
    }

    // MARK: - Edges

    private func paintLeftSeracs(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A cluster of ice towers cropped by the left edge, tall enough to
        // frame the whole height of the cabinet.
        let towers: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.03, 0.868, 0.190, 0.728),
            (0.105, 0.892, 0.130, 0.550),
            (0.195, 0.910, 0.095, 0.385)
        ]
        for (index, tower) in towers.enumerated() {
            let baseY = tower.1
            let width = tower.2
            let height = tower.3
            var body = Path()
            body.move(to: brush.p(tower.0 - width * 0.5, baseY))
            body.addLine(to: brush.p(tower.0 - width * 0.34, baseY - height * 0.62))
            body.addLine(to: brush.p(tower.0 - width * 0.10, baseY - height * 0.86))
            body.addLine(to: brush.p(tower.0 + width * 0.14, baseY - height))
            body.addLine(to: brush.p(tower.0 + width * 0.36, baseY - height * 0.70))
            body.addLine(to: brush.p(tower.0 + width * 0.5, baseY - height * 0.20))
            body.addLine(to: brush.p(tower.0 + width * 0.42, baseY))
            body.closeSubpath()
            context.fill(body, with: .linearGradient(
                Gradient(colors: [snowWhite, iceBlue, iceDeep.opacity(0.9)]),
                startPoint: brush.p(tower.0 - width * 0.5, baseY - height),
                endPoint: brush.p(tower.0 + width * 0.5, baseY)))
            context.stroke(body, with: .color(crevasse.opacity(0.28)), style: brush.joined(brush.lw(1.2)))

            // Internal facets: straight, bright and clearly crystalline.
            for facet in 0..<3 {
                var line = Path()
                let offset = CGFloat(facet) * width * 0.20 - width * 0.20
                line.move(to: brush.p(tower.0 + offset, baseY - height * 0.90))
                line.addLine(to: brush.p(tower.0 + offset * 0.4, baseY - height * 0.06))
                context.stroke(line,
                               with: .color(facet.isMultiple(of: 2)
                                            ? Color.white.opacity(0.42)
                                            : crevasse.opacity(0.20)),
                               style: brush.stroke(brush.lw(1.3)))
            }
            _ = index
        }
        // A wide ellipse over the feet, not a peaked mound that only covers
        // a sliver at the top. Drawn last so it sits on the ice.
        let bank = CGRect(x: brush.rx(-0.12),
                          y: brush.ry(0.872),
                          width: brush.rx(0.50),
                          height: brush.ry(0.145))
        context.fill(Path(ellipseIn: bank), with: .linearGradient(
            Gradient(colors: [snowWhite, snowShade, snowBlue.opacity(0.85)]),
            startPoint: CGPoint(x: bank.midX, y: bank.minY),
            endPoint: CGPoint(x: bank.midX, y: bank.maxY)))
    }

    private func paintRightCliff(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        func cubic(_ t: CGFloat, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u*u*u*a.x + 3*u*u*t*b.x + 3*u*t*t*c.x + t*t*t*d.x,
                           y: u*u*u*a.y + 3*u*u*t*b.y + 3*u*t*t*c.y + t*t*t*d.y)
        }
        let lipA = brush.p(0.800, 0.330)
        let lipC1 = brush.p(0.816, 0.424)
        let lipC2 = brush.p(0.862, 0.500)
        let lipB = brush.p(0.870, 0.560)

        // Solid ice behind the fringe so the glacier skyline cannot cut
        // through the hanging teeth.
        var curtain = Path()
        curtain.move(to: brush.p(0.772, 0.318))
        curtain.addLine(to: lipA)
        curtain.addCurve(to: cubic(0.48, lipA, lipC1, lipC2, lipB),
                         control1: lipC1, control2: brush.p(0.828, 0.455))
        curtain.addLine(to: brush.p(0.768, 0.468))
        curtain.closeSubpath()
        context.fill(curtain, with: .color(iceBlue))

        var wall = Path()
        wall.move(to: brush.p(1.04, -0.02))
        wall.addLine(to: brush.p(0.845, 0.055))
        wall.addCurve(to: lipA,
                      control1: brush.p(0.792, 0.145),
                      control2: brush.p(0.784, 0.245))
        let teeth = 8
        for index in 0..<teeth {
            let t0 = CGFloat(index) / CGFloat(teeth) * 0.48
            let t1 = CGFloat(index + 1) / CGFloat(teeth) * 0.48
            let a = cubic(t0, lipA, lipC1, lipC2, lipB)
            let b = cubic(t1, lipA, lipC1, lipC2, lipB)
            let mid = cubic((t0 + t1) * 0.5, lipA, lipC1, lipC2, lipB)
            let length = brush.ry(habitatNoise(601 &+ index, 121, 0.045, 0.095))
            if index == 0 { wall.addLine(to: a) }
            wall.addLine(to: CGPoint(x: mid.x - brush.rx(0.018), y: mid.y + length))
            wall.addLine(to: b)
        }
        wall.addCurve(to: brush.p(1.04, 0.760),
                      control1: brush.p(0.880, 0.640),
                      control2: brush.p(0.958, 0.716))
        wall.closeSubpath()
        context.fill(wall, with: .linearGradient(
            Gradient(colors: [snowWhite, iceBlue, iceDeep]),
            startPoint: brush.p(0.80, 0.10),
            endPoint: brush.p(1.02, 0.72)))

        for index in 0..<3 {
            var facet = Path()
            let x = 0.918 + CGFloat(index) * 0.032
            facet.move(to: brush.p(x, 0.068))
            facet.addLine(to: brush.p(x + 0.010, 0.360 + CGFloat(index) * 0.04))
            context.stroke(facet,
                           with: .color(index.isMultiple(of: 2)
                                        ? Color.white.opacity(0.24)
                                        : crevasse.opacity(0.12)),
                           style: brush.stroke(brush.lw(1.1)))
        }

        brush.snowMound(in: &context,
                        center: brush.p(0.930, 0.058),
                        width: brush.rx(0.28),
                        height: brush.ry(0.055),
                        snow: snowWhite,
                        shade: snowShade,
                        seed: 602)
    }

    private func paintTopOverhang(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // One filled mass: the hanging teeth are the bottom edge of the
        // cornice, so they cannot sit in a gap under a separate lip.
        let lipStart = brush.p(-0.04, 0.168)
        let lipMid = brush.p(0.230, 0.142)
        let c1 = brush.p(0.050, 0.164)
        let c2 = brush.p(0.135, 0.156)
        let c3 = brush.p(0.330, 0.108)
        let c4 = brush.p(0.415, 0.050)
        func cubic(_ t: CGFloat, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u*u*u*a.x + 3*u*u*t*b.x + 3*u*t*t*c.x + t*t*t*d.x,
                           y: u*u*u*a.y + 3*u*u*t*b.y + 3*u*t*t*c.y + t*t*t*d.y)
        }

        var cornice = Path()
        cornice.move(to: brush.p(-0.04, -0.02))
        cornice.addLine(to: brush.p(0.48, -0.02))
        cornice.addCurve(to: lipMid, control1: c4, control2: c3)
        let teeth = 11
        for index in 0..<teeth {
            let t0 = CGFloat(index) / CGFloat(teeth)
            let t1 = CGFloat(index + 1) / CGFloat(teeth)
            let a = cubic(t0, lipMid, c2, c1, lipStart)
            let b = cubic(t1, lipMid, c2, c1, lipStart)
            let mid = cubic((t0 + t1) * 0.5, lipMid, c2, c1, lipStart)
            let length = brush.ry(habitatNoise(701 &+ index, 121, 0.048, 0.110))
            if index == 0 { cornice.addLine(to: a) }
            cornice.addLine(to: CGPoint(x: mid.x, y: mid.y + length))
            cornice.addLine(to: b)
        }
        cornice.closeSubpath()
        context.fill(cornice, with: .linearGradient(
            Gradient(colors: [snowWhite, snowShade, iceBlue]),
            startPoint: brush.p(0.16, 0),
            endPoint: brush.p(0.16, 0.24)))
    }

    private func paintForeground(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        let shards: [(CGFloat, CGFloat, CGFloat)] = [
            (0.050, 1.005, 0.046), (0.175, 1.022, 0.036),
            (0.910, 0.995, 0.050), (0.780, 1.020, 0.038)
        ]
        for shard in shards {
            let base = brush.p(shard.0, shard.1)
            let size = brush.rx(shard.2)
            var spike = Path()
            spike.move(to: CGPoint(x: base.x - size * 0.50, y: base.y))
            spike.addLine(to: CGPoint(x: base.x - size * 0.10, y: base.y - size * 1.28))
            spike.addLine(to: CGPoint(x: base.x + size * 0.28, y: base.y - size * 0.78))
            spike.addLine(to: CGPoint(x: base.x + size * 0.55, y: base.y))
            spike.closeSubpath()
            context.fill(spike, with: .linearGradient(
                Gradient(colors: [snowWhite, iceBlue]),
                startPoint: CGPoint(x: base.x - size, y: base.y - size),
                endPoint: CGPoint(x: base.x + size, y: base.y)))
        }

        // A quiet, almost flat drift. A scalloped top read as kringels
        // under the shards.
        var bank = Path()
        bank.move(to: brush.p(-0.02, 1.04))
        bank.addLine(to: brush.p(-0.02, 0.972))
        bank.addQuadCurve(to: brush.p(1.02, 0.968),
                          control: brush.p(0.50, 0.984))
        bank.addLine(to: brush.p(1.02, 1.04))
        bank.closeSubpath()
        context.fill(bank, with: .linearGradient(
            Gradient(colors: [snowWhite, snowBlue.opacity(0.92)]),
            startPoint: brush.p(0.5, 0.96),
            endPoint: brush.p(0.5, 1.03)))
    }
}
