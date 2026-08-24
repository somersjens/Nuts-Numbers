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

        // High cirrus: long, thin, wind-stretched strokes.
        for index in 0..<7 {
            let y = 0.075 + CGFloat(index) * 0.038
            let x = habitatNoise(index, 3, 0.02, 0.40)
            let length = habitatNoise(index, 4, 0.30, 0.60)
            var streak = Path()
            streak.move(to: brush.p(x, y))
            streak.addCurve(to: brush.p(min(1.02, x + length), y + habitatNoise(index, 5, -0.012, 0.012)),
                            control1: brush.p(x + length * 0.32, y - 0.014),
                            control2: brush.p(x + length * 0.70, y + 0.012))
            context.stroke(streak,
                           with: .color(Color.white.opacity(index.isMultiple(of: 2) ? 0.30 : 0.18)),
                           style: brush.stroke(brush.lw(1.6 + CGFloat(index % 3) * 0.8)))
        }

        // Pale aurora ribbons hanging in the upper sky. Kept faint so the
        // scene still reads as daylight.
        for index in 0..<3 {
            var ribbon = Path()
            let y = 0.055 + CGFloat(index) * 0.048
            ribbon.move(to: brush.p(0.04, y + 0.030))
            ribbon.addCurve(to: brush.p(0.96, y + 0.020),
                            control1: brush.p(0.30, y - 0.048),
                            control2: brush.p(0.66, y + 0.075))
            context.stroke(ribbon,
                           with: .linearGradient(
                            Gradient(colors: [.clear,
                                              Color(red: 0.58, green: 0.94, blue: 0.80).opacity(0.16),
                                              Color(red: 0.70, green: 0.82, blue: 0.98).opacity(0.10),
                                              .clear]),
                            startPoint: brush.p(0, y),
                            endPoint: brush.p(1, y)),
                           style: brush.stroke(brush.ry(0.030 - CGFloat(index) * 0.006)))
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
                                            width: brush.w, height: brush.ry(0.33)),
                             count: 26,
                             color: snowBlue.opacity(0.42),
                             highlight: Color.white.opacity(0.65),
                             lengthRange: 0.05...0.17,
                             seed: 51)

        // Broad, soft drifts.
        let drifts: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.16, 0.700, 0.34, 0.055), (0.78, 0.720, 0.32, 0.060),
            (0.36, 0.830, 0.40, 0.085), (0.88, 0.900, 0.36, 0.090)
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
        for index in 0..<9 {
            let x = habitatNoise(index, 21, 0.05, 0.95)
            let y = habitatNoise(index, 22, 0.680, 0.960)
            let length = habitatNoise(index, 23, 0.04, 0.12)
            var crack = Path()
            crack.move(to: brush.p(x, y))
            crack.addLine(to: brush.p(x + length * 0.6, y + 0.014))
            crack.addLine(to: brush.p(x + length, y - 0.008))
            context.stroke(crack,
                           with: .color(crevasse.opacity(0.22)),
                           style: brush.stroke(brush.lw(1.1)))
        }

        // Snow-capped boulders poking through the shelf.
        let stones: [(CGFloat, CGFloat, CGFloat)] = [
            (0.235, 0.712, 0.032), (0.700, 0.688, 0.026), (0.135, 0.905, 0.056), (0.615, 0.958, 0.048)
        ]
        for (index, stone) in stones.enumerated() {
            let center = brush.p(stone.0, stone.1)
            let radius = brush.rx(stone.2)
            brush.rock(in: &context, center: center, radius: radius,
                       light: rock, dark: rockDark, seed: 300 &+ index)
            var cap = Path()
            cap.move(to: CGPoint(x: center.x - radius * 0.86, y: center.y - radius * 0.18))
            cap.addQuadCurve(to: CGPoint(x: center.x + radius * 0.80, y: center.y - radius * 0.22),
                             control: CGPoint(x: center.x, y: center.y - radius * 0.92))
            cap.addQuadCurve(to: CGPoint(x: center.x - radius * 0.86, y: center.y - radius * 0.18),
                             control: CGPoint(x: center.x, y: center.y - radius * 0.02))
            cap.closeSubpath()
            context.fill(cap, with: .linearGradient(
                Gradient(colors: [snowWhite, snowShade]),
                startPoint: CGPoint(x: center.x, y: center.y - radius),
                endPoint: CGPoint(x: center.x, y: center.y)))
        }
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

        // Broken ice blocks pushed up around the near rim.
        for index in 0..<7 {
            let angle = .pi * 0.13 + Double(index) / 6 * .pi * 0.74
                + Double(habitatNoise(index, 30, -0.09, 0.09))
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * brush.rx(0.190),
                                y: center.y + CGFloat(sin(angle)) * brush.ry(0.076))
            let size = brush.rx(habitatNoise(index, 31, 0.020, 0.038))
            var block = Path()
            block.move(to: CGPoint(x: point.x - size, y: point.y + size * 0.30))
            block.addLine(to: CGPoint(x: point.x - size * 0.60, y: point.y - size * 0.55))
            block.addLine(to: CGPoint(x: point.x + size * 0.75, y: point.y - size * 0.30))
            block.addLine(to: CGPoint(x: point.x + size * 0.95, y: point.y + size * 0.36))
            block.closeSubpath()
            context.fill(block, with: .linearGradient(
                Gradient(colors: [snowWhite, iceBlue.opacity(0.85)]),
                startPoint: CGPoint(x: point.x - size, y: point.y - size),
                endPoint: CGPoint(x: point.x + size, y: point.y + size)))
            context.stroke(block, with: .color(crevasse.opacity(0.25)), style: brush.joined(brush.lw(0.8)))
        }
    }

    private func paintRookery(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Pebble nests: shallow scrapes ringed with small stones, plus the
        // tracks leading between them. Unmistakably a penguin colony.
        let nests: [(CGFloat, CGFloat, CGFloat)] = [
            (0.175, 0.808, 0.062), (0.290, 0.870, 0.052), (0.815, 0.842, 0.058)
        ]
        for (index, nest) in nests.enumerated() {
            let center = brush.p(nest.0, nest.1)
            let radius = brush.rx(nest.2)
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.42,
                                                width: radius * 2, height: radius * 0.84)),
                         with: .color(snowBlue.opacity(0.42)))
            for stoneIndex in 0..<14 {
                let angle = Double(stoneIndex) / 14 * 2 * .pi
                    + Double(habitatNoise(index &* 30 &+ stoneIndex, 41)) * 0.4
                let distance = radius * habitatNoise(index &* 30 &+ stoneIndex, 42, 0.78, 1.06)
                let point = CGPoint(x: center.x + CGFloat(cos(angle)) * distance,
                                    y: center.y + CGFloat(sin(angle)) * distance * 0.42)
                let pebble = brush.rx(habitatNoise(index &* 30 &+ stoneIndex, 43, 0.007, 0.014))
                context.fill(Path(ellipseIn: CGRect(x: point.x - pebble, y: point.y - pebble * 0.7,
                                                    width: pebble * 2, height: pebble * 1.4)),
                             with: .color(stoneIndex.isMultiple(of: 3)
                                          ? Color(red: 0.46, green: 0.44, blue: 0.44)
                                          : Color(red: 0.30, green: 0.30, blue: 0.33)))
            }
        }

        // Two-toed tracks walking away from the dive hole.
        for track in 0..<2 {
            let startX: CGFloat = track == 0 ? 0.360 : 0.660
            let startY: CGFloat = track == 0 ? 0.885 : 0.930
            let drift: CGFloat = track == 0 ? -0.055 : 0.075
            for step in 0..<7 {
                let t = CGFloat(step) / 6
                let point = brush.p(startX + drift * t, startY + t * 0.055)
                let side: CGFloat = step.isMultiple(of: 2) ? -1 : 1
                for toe in 0..<3 {
                    let angle = -Double.pi * 0.5 + Double(toe - 1) * 0.42
                    var print = Path()
                    print.move(to: CGPoint(x: point.x + side * brush.rx(0.012), y: point.y))
                    print.addLine(to: CGPoint(x: point.x + side * brush.rx(0.012)
                                              + CGFloat(cos(angle)) * brush.rx(0.014),
                                              y: point.y + CGFloat(sin(angle)) * brush.ry(0.012)))
                    context.stroke(print,
                                   with: .color(snowBlue.opacity(0.55)),
                                   style: brush.stroke(brush.lw(1.0)))
                }
            }
        }
    }

    // MARK: - Edges

    private func paintLeftSeracs(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A cluster of ice towers cropped by the left edge, tall enough to
        // frame the whole height of the cabinet.
        let towers: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.03, 0.780, 0.190, 0.640),
            (0.105, 0.812, 0.130, 0.470),
            (0.195, 0.845, 0.095, 0.320)
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
        // Snow banked against the feet of the towers.
        brush.snowMound(in: &context,
                        center: brush.p(0.075, 0.812),
                        width: brush.rx(0.36),
                        height: brush.ry(0.075),
                        snow: snowWhite,
                        shade: snowShade,
                        seed: 501)
    }

    private func paintRightCliff(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A cropped ice wall with an undercut and a fringe of icicles.
        var wall = Path()
        wall.move(to: brush.p(1.04, -0.02))
        wall.addLine(to: brush.p(0.845, 0.055))
        wall.addCurve(to: brush.p(0.800, 0.330),
                      control1: brush.p(0.792, 0.145),
                      control2: brush.p(0.784, 0.245))
        wall.addCurve(to: brush.p(0.870, 0.560),
                      control1: brush.p(0.816, 0.424),
                      control2: brush.p(0.862, 0.500))
        wall.addCurve(to: brush.p(1.04, 0.760),
                      control1: brush.p(0.880, 0.640),
                      control2: brush.p(0.958, 0.716))
        wall.closeSubpath()
        context.fill(wall, with: .linearGradient(
            Gradient(colors: [snowWhite, iceBlue, iceDeep]),
            startPoint: brush.p(0.80, 0.10),
            endPoint: brush.p(1.02, 0.72)))
        context.stroke(wall, with: .color(crevasse.opacity(0.24)), style: brush.joined(brush.lw(1.3)))

        for index in 0..<5 {
            var seam = Path()
            let y = 0.120 + CGFloat(index) * 0.115
            seam.move(to: brush.p(0.810 + CGFloat(index % 2) * 0.014, y))
            seam.addQuadCurve(to: brush.p(1.03, y + 0.055),
                              control: brush.p(0.92, y + 0.010))
            context.stroke(seam,
                           with: .color(index.isMultiple(of: 2)
                                        ? Color.white.opacity(0.42)
                                        : crevasse.opacity(0.22)),
                           style: brush.stroke(brush.lw(1.3)))
        }

        brush.icicles(in: &context,
                      from: brush.p(0.812, 0.322),
                      to: brush.p(1.02, 0.372),
                      count: 11,
                      maxLength: brush.ry(0.115),
                      color: Color.white.opacity(0.92),
                      tip: iceBlue.opacity(0.75),
                      seed: 601)

        // Snow shoulder on top of the wall.
        brush.snowMound(in: &context,
                        center: brush.p(0.930, 0.058),
                        width: brush.rx(0.28),
                        height: brush.ry(0.055),
                        snow: snowWhite,
                        shade: snowShade,
                        seed: 602)
    }

    private func paintTopOverhang(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A snow cornice hanging into the top-left of the frame, with icicles.
        var cornice = Path()
        cornice.move(to: brush.p(-0.02, -0.02))
        cornice.addLine(to: brush.p(0.44, -0.02))
        cornice.addCurve(to: brush.p(0.235, 0.108),
                         control1: brush.p(0.40, 0.062),
                         control2: brush.p(0.320, 0.098))
        cornice.addCurve(to: brush.p(-0.02, 0.145),
                         control1: brush.p(0.150, 0.118),
                         control2: brush.p(0.060, 0.108))
        cornice.closeSubpath()
        context.fill(cornice, with: .linearGradient(
            Gradient(colors: [snowWhite, snowShade, iceBlue.opacity(0.8)]),
            startPoint: brush.p(0.2, 0),
            endPoint: brush.p(0.2, 0.15)))

        var lip = Path()
        lip.move(to: brush.p(-0.02, 0.145))
        lip.addCurve(to: brush.p(0.235, 0.108),
                     control1: brush.p(0.060, 0.108),
                     control2: brush.p(0.150, 0.118))
        lip.addCurve(to: brush.p(0.44, -0.02),
                     control1: brush.p(0.320, 0.098),
                     control2: brush.p(0.40, 0.062))
        context.stroke(lip, with: .color(Color.white.opacity(0.75)), style: brush.joined(brush.lw(1.8)))

        brush.icicles(in: &context,
                      from: brush.p(-0.01, 0.140),
                      to: brush.p(0.245, 0.104),
                      count: 10,
                      maxLength: brush.ry(0.105),
                      color: Color.white.opacity(0.90),
                      tip: iceBlue.opacity(0.70),
                      seed: 701)
    }

    private func paintForeground(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A near snow bank across the bottom, with wind scallops and a few
        // ice shards catching the low light.
        var bank = Path()
        bank.move(to: brush.p(-0.02, 1.04))
        bank.addCurve(to: brush.p(0.32, 0.918),
                      control1: brush.p(0.06, 0.968),
                      control2: brush.p(0.19, 0.912))
        bank.addCurve(to: brush.p(0.68, 0.946),
                      control1: brush.p(0.45, 0.924),
                      control2: brush.p(0.57, 0.958))
        bank.addCurve(to: brush.p(1.02, 0.900),
                      control1: brush.p(0.80, 0.934),
                      control2: brush.p(0.93, 0.888))
        bank.addLine(to: brush.p(1.02, 1.04))
        bank.closeSubpath()
        context.fill(bank, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.95), snowBlue.opacity(0.92)]),
            startPoint: brush.p(0.5, 0.90),
            endPoint: brush.p(0.5, 1.02)))

        for index in 0..<9 {
            let x = 0.02 + CGFloat(index) * 0.115
            var scallop = Path()
            scallop.move(to: brush.p(x, 0.975 + habitatNoise(index, 51, -0.012, 0.012)))
            scallop.addQuadCurve(to: brush.p(x + 0.085, 0.975 + habitatNoise(index, 52, -0.010, 0.010)),
                                 control: brush.p(x + 0.042, 0.948))
            context.stroke(scallop,
                           with: .color(snowBlue.opacity(0.42)),
                           style: brush.stroke(brush.lw(1.5)))
            var lit = context
            lit.translateBy(x: 0, y: -brush.lw(1.4))
            lit.stroke(scallop, with: .color(Color.white.opacity(0.75)), style: brush.stroke(brush.lw(1.0)))
        }

        let shards: [(CGFloat, CGFloat, CGFloat)] = [
            (0.055, 0.985, 0.048), (0.185, 1.005, 0.038),
            (0.905, 0.965, 0.052), (0.775, 1.000, 0.040)
        ]
        for (index, shard) in shards.enumerated() {
            let base = brush.p(shard.0, shard.1)
            let size = brush.rx(shard.2)
            var spike = Path()
            spike.move(to: CGPoint(x: base.x - size * 0.6, y: base.y))
            spike.addLine(to: CGPoint(x: base.x - size * 0.15, y: base.y - size * 1.5))
            spike.addLine(to: CGPoint(x: base.x + size * 0.35, y: base.y - size * 0.9))
            spike.addLine(to: CGPoint(x: base.x + size * 0.7, y: base.y))
            spike.closeSubpath()
            context.fill(spike, with: .linearGradient(
                Gradient(colors: [Color.white, iceBlue.opacity(0.85)]),
                startPoint: CGPoint(x: base.x - size, y: base.y - size),
                endPoint: CGPoint(x: base.x + size, y: base.y)))
            context.stroke(spike, with: .color(crevasse.opacity(0.22)), style: brush.joined(brush.lw(0.8)))
            _ = index
        }
    }
}
