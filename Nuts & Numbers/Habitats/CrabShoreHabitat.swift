//
//  CrabShoreHabitat.swift
//  Nuts & Numbers
//
//  Sunlit tidal shallows: a bright sand flat between two coral bommies, with
//  the surface visible overhead. Deliberately warmer and shallower than the
//  octopus reef so the two underwater cabinets never read as the same place.
//

import SwiftUI

struct CrabShoreHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let surfaceLight = Color(red: 0.78, green: 0.96, blue: 0.96)
    private let waterTop = Color(red: 0.30, green: 0.78, blue: 0.86)
    private let waterMid = Color(red: 0.12, green: 0.57, blue: 0.71)
    private let waterHaze = Color(red: 0.46, green: 0.76, blue: 0.78)
    private let sandLight = Color(red: 0.91, green: 0.82, blue: 0.58)
    private let sandMid = Color(red: 0.76, green: 0.64, blue: 0.42)
    private let sandDeep = Color(red: 0.42, green: 0.35, blue: 0.24)
    private let rockLight = Color(red: 0.54, green: 0.58, blue: 0.50)
    private let rockDark = Color(red: 0.18, green: 0.25, blue: 0.28)
    private let weed = Color(red: 0.17, green: 0.48, blue: 0.34)
    private let weedLight = Color(red: 0.40, green: 0.68, blue: 0.36)
    private let coralPink = Color(red: 0.94, green: 0.47, blue: 0.44)
    private let coralOrange = Color(red: 0.95, green: 0.63, blue: 0.29)
    private let coralPurple = Color(red: 0.60, green: 0.40, blue: 0.76)

    var body: some View {
        Canvas { context, size in
            let brush = HabitatBrush(size: size, isPad: isPad)
            paintWaterColumn(brush, in: &context)
            paintSurface(brush, in: &context)
            paintFarWater(brush, in: &context)
            paintSeabed(brush, in: &context)
            paintTideChannel(brush, in: &context)
            paintSandTexture(brush, in: &context)
            paintSandCaustics(brush, in: &context)
            paintCrabFlat(brush, in: &context)
            paintLeftBommie(brush, in: &context)
            paintRightLedge(brush, in: &context)
            paintSeagrassMeadow(brush, in: &context)
            paintDriftwood(brush, in: &context)
            paintUpperDrift(brush, in: &context)
            paintForeground(brush, in: &context)
        }
        .overlay {
            LinearGradient(colors: [.white.opacity(0.07),
                                    .clear,
                                    character.deepColor.opacity(0.05)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Water

    private func paintWaterColumn(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        context.fill(Path(CGRect(origin: .zero, size: brush.size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: surfaceLight, location: 0),
                            .init(color: waterTop, location: 0.16),
                            .init(color: waterMid, location: 0.42),
                            .init(color: waterHaze, location: 0.60),
                            .init(color: sandMid.opacity(0.9), location: 1)
                        ]),
                        startPoint: brush.p(0.30, 0),
                        endPoint: brush.p(0.66, 1)))

        // Wide, very soft columns of brighter water. They give the volume a
        // direction without adding a single hard edge behind the gameplay.
        for index in 0..<4 {
            let center = brush.p(0.12 + CGFloat(index) * 0.27, 0.26 + CGFloat(index % 2) * 0.08)
            let rect = CGRect(x: center.x - brush.rx(0.14),
                              y: center.y - brush.ry(0.28),
                              width: brush.rx(0.28),
                              height: brush.ry(0.56))
            context.fill(Path(ellipseIn: rect),
                         with: .radialGradient(
                            Gradient(colors: [Color(red: 0.62, green: 0.95, blue: 0.92).opacity(0.10), .clear]),
                            center: center,
                            startRadius: 0,
                            endRadius: rect.height * 0.5))
        }
    }

    private func paintSurface(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Underside of the water, seen from below: a rolling ceiling with a
        // bright refracted band where the sun enters.
        var ceiling = Path()
        ceiling.move(to: brush.p(0, 0))
        ceiling.addLine(to: brush.p(1, 0))
        ceiling.addLine(to: brush.p(1, 0.052))
        var x: CGFloat = 1
        var toggle = false
        while x > 0 {
            let next = max(0, x - 0.1)
            ceiling.addQuadCurve(to: brush.p(next, 0.052),
                                 control: brush.p((x + next) * 0.5, toggle ? 0.074 : 0.030))
            toggle.toggle()
            x = next
        }
        ceiling.closeSubpath()
        context.fill(ceiling, with: .linearGradient(
            Gradient(colors: [surfaceLight.opacity(0.85), surfaceLight.opacity(0.20)]),
            startPoint: brush.p(0, 0),
            endPoint: brush.p(0, 0.075)))

        // Crest highlights riding the same wave rhythm.
        for index in 0..<9 {
            let cx = 0.055 + CGFloat(index) * 0.11
            var crest = Path()
            crest.move(to: brush.p(cx - 0.035, 0.049))
            crest.addQuadCurve(to: brush.p(cx + 0.035, 0.049),
                               control: brush.p(cx, index.isMultiple(of: 2) ? 0.028 : 0.064))
            context.stroke(crest,
                           with: .color(Color.white.opacity(index.isMultiple(of: 2) ? 0.55 : 0.30)),
                           style: brush.stroke(brush.lw(1.5)))
        }

        // Sun seen through the surface, kept off-centre so the hanging crab
        // never sits inside the brightest patch.
        brush.sun(in: &context,
                  center: brush.p(0.235, 0.045),
                  radius: brush.rx(0.075),
                  core: Color.white.opacity(0.55),
                  glow: Color.white.opacity(0.30),
                  glowSpread: 2.6)

        let shafts: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.13, 0.22, 0.01, 0.20, 0.66),
            (0.26, 0.33, 0.24, 0.46, 0.62),
            (0.60, 0.67, 0.62, 0.82, 0.56),
            (0.80, 0.89, 0.86, 1.06, 0.60)
        ]
        for (index, shaft) in shafts.enumerated() {
            brush.lightShaft(in: &context,
                             topLeft: shaft.0,
                             topRight: shaft.1,
                             bottomLeft: shaft.2,
                             bottomRight: shaft.3,
                             topY: brush.ry(0.05),
                             bottomY: brush.ry(shaft.4),
                             color: Color.white.opacity(index.isMultiple(of: 2) ? 0.12 : 0.075))
        }
    }

    private func paintFarWater(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Blue distance haze plus the silhouette of an outer reef bar.
        brush.hazeBand(in: &context, top: 0.36, bottom: 0.52, color: waterHaze.opacity(0.35))

        var bar = Path()
        bar.move(to: brush.p(0, 0.508))
        bar.addCurve(to: brush.p(0.34, 0.470),
                     control1: brush.p(0.10, 0.486),
                     control2: brush.p(0.22, 0.462))
        bar.addCurve(to: brush.p(0.68, 0.488),
                     control1: brush.p(0.46, 0.478),
                     control2: brush.p(0.58, 0.500))
        bar.addCurve(to: brush.p(1, 0.462),
                     control1: brush.p(0.80, 0.474),
                     control2: brush.p(0.92, 0.452))
        bar.addLine(to: brush.p(1, 0.56))
        bar.addLine(to: brush.p(0, 0.56))
        bar.closeSubpath()
        context.fill(bar, with: .linearGradient(
            Gradient(colors: [Color(red: 0.28, green: 0.56, blue: 0.58).opacity(0.55),
                              Color(red: 0.42, green: 0.62, blue: 0.56).opacity(0.28)]),
            startPoint: brush.p(0, 0.45),
            endPoint: brush.p(0, 0.56)))

        // Distant coral heads reduced to soft, desaturated masses.
        let heads: [(CGFloat, CGFloat, CGFloat)] = [
            (0.05, 0.478, 0.055), (0.15, 0.462, 0.040), (0.235, 0.474, 0.048),
            (0.44, 0.470, 0.036), (0.545, 0.482, 0.044),
            (0.72, 0.468, 0.052), (0.86, 0.456, 0.038), (0.965, 0.470, 0.046)
        ]
        for (index, head) in heads.enumerated() {
            brush.branchCoral(in: &context,
                              base: brush.p(head.0, head.1),
                              height: brush.ry(head.2),
                              color: (index.isMultiple(of: 3) ? coralPurple : weed).opacity(0.32),
                              thickness: brush.lw(1.2),
                              seed: index &* 13)
        }

        // Two loose schools far away, small enough to read as depth cues.
        for index in 0..<9 {
            let cluster = index < 5 ? CGFloat(0.14) : CGFloat(0.80)
            let sign: CGFloat = index < 5 ? 1 : -1
            let point = CGPoint(x: brush.rx(cluster + sign * CGFloat(index % 5) * 0.032),
                                y: brush.ry(0.31 + CGFloat((index * 7) % 5) * 0.022))
            brush.fish(in: &context,
                       center: point,
                       length: brush.rx(0.022),
                       color: Color(red: 0.10, green: 0.34, blue: 0.42).opacity(0.34),
                       belly: Color(red: 0.24, green: 0.52, blue: 0.56).opacity(0.28),
                       facingRight: index < 5)
        }
    }

    // MARK: - Seabed

    private func paintSeabed(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var floor = Path()
        floor.move(to: brush.p(0, 0.545))
        floor.addCurve(to: brush.p(0.42, 0.575),
                       control1: brush.p(0.13, 0.520),
                       control2: brush.p(0.27, 0.596))
        floor.addCurve(to: brush.p(1, 0.535),
                       control1: brush.p(0.63, 0.556),
                       control2: brush.p(0.82, 0.588))
        floor.addLine(to: brush.p(1, 1))
        floor.addLine(to: brush.p(0, 1))
        floor.closeSubpath()
        context.fill(floor, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.66, green: 0.72, blue: 0.58), location: 0),
                .init(color: sandLight, location: 0.34),
                .init(color: sandMid, location: 0.72),
                .init(color: sandDeep, location: 1)
            ]),
            startPoint: brush.p(0.5, 0.53),
            endPoint: brush.p(0.5, 1)))

        // Low sand bars stacked toward the viewer give the flat floor relief.
        let bars: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.30, 0.615, 0.62, 0.10), (0.72, 0.672, 0.58, 0.12), (0.24, 0.762, 0.66, 0.13)
        ]
        for (index, bar) in bars.enumerated() {
            var crest = Path()
            crest.move(to: brush.p(bar.0 - bar.2 * 0.5, bar.1 + 0.02))
            crest.addCurve(to: brush.p(bar.0 + bar.2 * 0.5, bar.1 + 0.015),
                           control1: brush.p(bar.0 - bar.2 * 0.2, bar.1 - 0.018),
                           control2: brush.p(bar.0 + bar.2 * 0.18, bar.1 - 0.012))
            crest.addLine(to: brush.p(bar.0 + bar.2 * 0.5, bar.1 + 0.10))
            crest.addLine(to: brush.p(bar.0 - bar.2 * 0.5, bar.1 + 0.10))
            crest.closeSubpath()
            context.fill(crest, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(bar.3), .clear]),
                startPoint: brush.p(0.5, bar.1 - 0.01),
                endPoint: brush.p(0.5, bar.1 + 0.07)))
            _ = index
        }
    }

    private func paintTideChannel(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A shallow drainage channel snaking from the far bar to the near edge.
        // Its darker water is the calmest thing in the middle of the cabinet.
        // Drawn as three nested, progressively darker and narrower washes.
        // Stroking the banks instead would put two hard parallel lines down
        // the middle of the cabinet, which reads as rails rather than water.
        let widths: [(CGFloat, CGFloat, Double)] = [(0.055, 0.190, 0.16),
                                                    (0.038, 0.140, 0.20),
                                                    (0.022, 0.088, 0.22)]
        for (index, band) in widths.enumerated() {
            var channel = Path()
            channel.move(to: brush.p(0.492 - band.0, 0.556))
            channel.addCurve(to: brush.p(0.395 - band.1, 1.04),
                             control1: brush.p(0.520 - band.0 * 1.6, 0.700),
                             control2: brush.p(0.372 - band.1 * 0.7, 0.850))
            channel.addLine(to: brush.p(0.395 + band.1, 1.04))
            channel.addCurve(to: brush.p(0.492 + band.0, 0.556),
                             control1: brush.p(0.470 + band.1 * 0.7, 0.850),
                             control2: brush.p(0.512 + band.0 * 1.6, 0.700))
            channel.closeSubpath()
            context.fill(channel, with: .linearGradient(
                Gradient(colors: [Color(red: 0.36, green: 0.68, blue: 0.70).opacity(band.2 * 0.8),
                                  Color(red: 0.14, green: 0.46, blue: 0.56).opacity(band.2)]),
                startPoint: brush.p(0.5, 0.56),
                endPoint: brush.p(0.5, 1)))
            _ = index
        }

        // Damp sand blotches along the banks, so the edge is a change in
        // wetness rather than a drawn outline.
        for index in 0..<14 {
            let t = habitatNoise(index, 141)
            let depth = 0.580 + t * 0.420
            let halfWidth = 0.062 + t * 0.190
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let x = 0.492 - (0.492 - 0.395) * t + side * halfWidth * habitatNoise(index, 142, 0.80, 1.15)
            brush.groundPatch(in: &context,
                              center: brush.p(x, depth),
                              width: brush.rx(habitatNoise(index, 143, 0.045, 0.105)),
                              height: brush.ry(habitatNoise(index, 144, 0.018, 0.038)),
                              color: Color(red: 0.52, green: 0.48, blue: 0.34).opacity(0.16),
                              seed: 800 &+ index &* 7)
        }
    }

    private func paintSandTexture(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        let patches: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (0.12, 0.60, 0.26, 0.07, Color(red: 0.95, green: 0.87, blue: 0.62).opacity(0.24)),
            (0.62, 0.585, 0.30, 0.06, Color(red: 0.58, green: 0.52, blue: 0.36).opacity(0.16)),
            (0.86, 0.68, 0.28, 0.09, Color(red: 0.94, green: 0.84, blue: 0.58).opacity(0.20)),
            (0.16, 0.80, 0.34, 0.12, Color(red: 0.52, green: 0.44, blue: 0.30).opacity(0.16)),
            (0.74, 0.88, 0.36, 0.13, Color(red: 0.93, green: 0.80, blue: 0.52).opacity(0.18))
        ]
        for (index, patch) in patches.enumerated() {
            brush.groundPatch(in: &context,
                              center: brush.p(patch.0, patch.1),
                              width: brush.rx(patch.2),
                              height: brush.ry(patch.3),
                              color: patch.4,
                              seed: 300 &+ index &* 9)
        }

        // The signature of a tidal flat: dense, perspective-scaled ripples.
        brush.surfaceStrokes(in: &context,
                             bounds: CGRect(x: 0, y: brush.ry(0.565),
                                            width: brush.w, height: brush.ry(0.42)),
                             count: 30,
                             color: Color(red: 0.44, green: 0.36, blue: 0.22).opacity(0.20),
                             highlight: Color.white.opacity(0.17),
                             lengthRange: 0.05...0.16,
                             seed: 41)

        brush.pebbleBeds(in: &context,
                         bounds: CGRect(x: brush.rx(0.04), y: brush.ry(0.60),
                                        width: brush.rx(0.92), height: brush.ry(0.36)),
                         color: Color(red: 0.38, green: 0.33, blue: 0.24).opacity(0.42),
                         highlight: Color.white.opacity(0.24),
                         clusters: 12,
                         seed: 77)
    }

    private func paintSandCaustics(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Light net projected onto the seabed. Interlocking cells look like
        // real caustics, unlike parallel lines which read as a UI pattern.
        for index in 0..<16 {
            let depth = CGFloat(index) / 15
            let y = 0.575 + depth * 0.39
            let x = habitatNoise(index, 201, 0.04, 0.94)
            let size = 0.035 + depth * 0.055
            var cell = Path()
            cell.move(to: brush.p(x, y))
            cell.addCurve(to: brush.p(x + size, y + size * 0.14),
                          control1: brush.p(x + size * 0.32, y - size * 0.24),
                          control2: brush.p(x + size * 0.70, y + size * 0.30))
            cell.addCurve(to: brush.p(x + size * 1.7, y - size * 0.10),
                          control1: brush.p(x + size * 1.2, y - size * 0.05),
                          control2: brush.p(x + size * 1.4, y - size * 0.30))
            context.stroke(cell,
                           with: .color(Color.white.opacity(index.isMultiple(of: 3) ? 0.20 : 0.13)),
                           style: brush.stroke(brush.lw(1.0 + depth * 0.7)))
        }
    }

    /// Burrows, excavated fans and the little sand pellets crabs leave behind.
    /// They are the detail that makes this specifically a crab's beach.
    private func paintCrabFlat(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        let burrows: [(CGFloat, CGFloat, CGFloat)] = [
            (0.205, 0.700, 0.016), (0.815, 0.735, 0.019),
            (0.365, 0.860, 0.021), (0.665, 0.905, 0.024), (0.115, 0.905, 0.020)
        ]
        for (index, burrow) in burrows.enumerated() {
            let center = brush.p(burrow.0, burrow.1)
            let radius = brush.rx(burrow.2)

            // Excavated sand fans out downslope from the entrance.
            var fan = Path()
            fan.move(to: CGPoint(x: center.x - radius * 2.4, y: center.y + radius * 1.5))
            fan.addQuadCurve(to: CGPoint(x: center.x + radius * 2.4, y: center.y + radius * 1.4),
                             control: CGPoint(x: center.x, y: center.y - radius * 0.9))
            fan.addQuadCurve(to: CGPoint(x: center.x - radius * 2.4, y: center.y + radius * 1.5),
                             control: CGPoint(x: center.x, y: center.y + radius * 2.4))
            fan.closeSubpath()
            context.fill(fan, with: .color(Color(red: 0.95, green: 0.87, blue: 0.63).opacity(0.42)))

            let mouth = CGRect(x: center.x - radius, y: center.y - radius * 0.62,
                               width: radius * 2, height: radius * 1.24)
            context.fill(Path(ellipseIn: mouth),
                         with: .radialGradient(
                            Gradient(colors: [Color.black.opacity(0.62),
                                              Color(red: 0.36, green: 0.30, blue: 0.20).opacity(0.5)]),
                            center: CGPoint(x: center.x, y: center.y - radius * 0.1),
                            startRadius: 0,
                            endRadius: radius))
            context.stroke(Path(ellipseIn: mouth.insetBy(dx: -radius * 0.12, dy: -radius * 0.08)),
                           with: .color(Color(red: 0.97, green: 0.90, blue: 0.68).opacity(0.55)),
                           style: brush.stroke(brush.lw(1.1)))

            // Pellet trail: dozens of tiny balls of sifted sand.
            for pellet in 0..<11 {
                let angle = Double(habitatNoise(index &* 31 &+ pellet, 211)) * 2 * .pi
                let distance = radius * habitatNoise(index &* 31 &+ pellet, 212, 1.4, 4.2)
                let px = center.x + CGFloat(cos(angle)) * distance
                let py = center.y + CGFloat(sin(angle)) * distance * 0.55
                let pr = radius * habitatNoise(index &* 31 &+ pellet, 213, 0.14, 0.24)
                context.fill(Path(ellipseIn: CGRect(x: px, y: py, width: pr * 2, height: pr * 1.7)),
                             with: .color(Color(red: 0.97, green: 0.90, blue: 0.68).opacity(0.72)))
            }
        }

        // Sideways crab tracks: paired dashes stepping across the flat.
        for track in 0..<2 {
            let startX: CGFloat = track == 0 ? 0.26 : 0.60
            let startY: CGFloat = track == 0 ? 0.795 : 0.955
            for step in 0..<9 {
                let t = CGFloat(step) / 8
                let x = startX + t * 0.16
                let y = startY - t * 0.035
                for side in [CGFloat(-1), CGFloat(1)] {
                    var mark = Path()
                    let point = brush.p(x, y + side * 0.012)
                    mark.move(to: point)
                    mark.addLine(to: CGPoint(x: point.x + brush.rx(0.006), y: point.y + side * brush.ry(0.004)))
                    context.stroke(mark,
                                   with: .color(Color(red: 0.42, green: 0.35, blue: 0.22).opacity(0.28)),
                                   style: brush.stroke(brush.lw(0.9)))
                }
            }
        }
    }

    // MARK: - Reef structures

    private func paintLeftBommie(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A stacked coral head rising out of the sand at the left edge.
        let stones: [(CGFloat, CGFloat, CGFloat)] = [
            (0.015, 0.760, 0.135), (0.115, 0.700, 0.095), (0.055, 0.635, 0.078),
            (0.175, 0.775, 0.070), (0.012, 0.880, 0.115)
        ]
        for (index, stone) in stones.enumerated() {
            brush.rock(in: &context,
                       center: brush.p(stone.0, stone.1),
                       radius: brush.rx(stone.2),
                       light: rockLight,
                       dark: rockDark,
                       seed: 400 &+ index &* 5)
        }

        brush.brainCoral(in: &context,
                         center: brush.p(0.085, 0.618),
                         radius: brush.rx(0.058),
                         color: Color(red: 0.92, green: 0.76, blue: 0.48),
                         groove: Color(red: 0.62, green: 0.42, blue: 0.28),
                         seed: 12)
        brush.branchCoral(in: &context,
                          base: brush.p(0.155, 0.700),
                          height: brush.ry(0.135),
                          color: coralPink,
                          thickness: brush.lw(2.6),
                          seed: 22)
        brush.branchCoral(in: &context,
                          base: brush.p(0.035, 0.690),
                          height: brush.ry(0.105),
                          color: coralPurple,
                          thickness: brush.lw(2.2),
                          seed: 31)
        brush.sponge(in: &context,
                     base: brush.p(0.205, 0.800),
                     height: brush.ry(0.085),
                     color: coralOrange,
                     shade: Color(red: 0.66, green: 0.33, blue: 0.16),
                     tubes: 3,
                     seed: 41)
        brush.anemone(in: &context,
                      base: brush.p(0.128, 0.660),
                      radius: brush.rx(0.042),
                      color: Color(red: 0.86, green: 0.42, blue: 0.52),
                      tip: Color(red: 0.98, green: 0.84, blue: 0.72),
                      tentacles: 13,
                      seed: 51)
        brush.urchin(in: &context,
                     center: brush.p(0.055, 0.836),
                     radius: brush.rx(0.026),
                     color: Color(red: 0.18, green: 0.12, blue: 0.24),
                     spine: Color(red: 0.30, green: 0.20, blue: 0.34),
                     seed: 61)
        brush.seaFan(in: &context,
                     base: brush.p(0.215, 0.700),
                     height: brush.ry(0.115),
                     color: Color(red: 0.86, green: 0.50, blue: 0.36).opacity(0.85),
                     seed: 71)

        // Weed skirt so the bommie is not a clean object sitting on sand.
        for index in 0..<7 {
            brush.grassTuft(in: &context,
                            base: brush.p(0.02 + CGFloat(index) * 0.032, 0.860 + CGFloat(index % 3) * 0.026),
                            height: brush.ry(0.052),
                            width: brush.rx(0.055),
                            colors: [weed, weedLight, weed.opacity(0.8)],
                            bladeCount: 7,
                            seed: 500 &+ index)
        }
    }

    private func paintRightLedge(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A tilted rock shelf cropped by the right edge, with a shaded undercut.
        var shelf = Path()
        shelf.move(to: brush.p(1.04, 0.500))
        shelf.addCurve(to: brush.p(0.815, 0.612),
                       control1: brush.p(0.955, 0.512),
                       control2: brush.p(0.865, 0.556))
        shelf.addCurve(to: brush.p(0.790, 0.760),
                       control1: brush.p(0.778, 0.652),
                       control2: brush.p(0.772, 0.712))
        shelf.addCurve(to: brush.p(1.04, 0.905),
                       control1: brush.p(0.848, 0.836),
                       control2: brush.p(0.940, 0.884))
        shelf.closeSubpath()
        context.fill(shelf, with: .linearGradient(
            Gradient(colors: [rockLight, rockDark]),
            startPoint: brush.p(0.78, 0.52),
            endPoint: brush.p(1.0, 0.90)))
        context.stroke(shelf, with: .color(Color.black.opacity(0.22)), style: brush.joined(brush.lw(1.2)))

        // Bedding planes make the shelf read as layered stone.
        for index in 0..<4 {
            var seam = Path()
            let y = 0.585 + CGFloat(index) * 0.072
            seam.move(to: brush.p(0.80 + CGFloat(index) * 0.012, y))
            seam.addQuadCurve(to: brush.p(1.03, y + 0.030),
                              control: brush.p(0.91, y - 0.014))
            context.stroke(seam,
                           with: .color(index.isMultiple(of: 2)
                                        ? Color.white.opacity(0.12)
                                        : Color.black.opacity(0.20)),
                           style: brush.stroke(brush.lw(1.2)))
        }

        // Barnacle and mussel crust along the upper edge.
        for index in 0..<18 {
            let t = CGFloat(index) / 17
            let point = brush.p(0.815 + t * 0.20, 0.606 - t * 0.088 + habitatNoise(index, 221, -0.01, 0.01))
            let radius = brush.rx(habitatNoise(index, 222, 0.006, 0.013))
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius * 0.7,
                                                width: radius * 2, height: radius * 1.4)),
                         with: .color(index.isMultiple(of: 3)
                                      ? Color(red: 0.28, green: 0.24, blue: 0.32)
                                      : Color(red: 0.82, green: 0.80, blue: 0.72).opacity(0.85)))
        }

        brush.plateCoral(in: &context,
                         base: brush.p(0.885, 0.665),
                         width: brush.rx(0.185),
                         color: Color(red: 0.88, green: 0.62, blue: 0.36),
                         shade: Color(red: 0.56, green: 0.33, blue: 0.20))
        brush.plateCoral(in: &context,
                         base: brush.p(0.955, 0.760),
                         width: brush.rx(0.150),
                         color: Color(red: 0.72, green: 0.44, blue: 0.62),
                         shade: Color(red: 0.42, green: 0.24, blue: 0.40))
        brush.branchCoral(in: &context,
                          base: brush.p(0.845, 0.775),
                          height: brush.ry(0.115),
                          color: Color(red: 0.42, green: 0.74, blue: 0.62),
                          thickness: brush.lw(2.3),
                          seed: 81)
        brush.starfish(in: &context,
                       center: brush.p(0.905, 0.845),
                       radius: brush.rx(0.045),
                       color: Color(red: 0.94, green: 0.52, blue: 0.30),
                       shade: Color(red: 0.68, green: 0.28, blue: 0.18),
                       rotation: 0.4)
        brush.urchin(in: &context,
                     center: brush.p(0.795, 0.700),
                     radius: brush.rx(0.022),
                     color: Color(red: 0.20, green: 0.14, blue: 0.26),
                     spine: Color(red: 0.34, green: 0.24, blue: 0.38),
                     seed: 91)
    }

    private func paintSeagrassMeadow(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A broken band of seagrass across the mid-distance. It softens the
        // join between sand and reef without crossing the play corridor.
        let clumps: [(CGFloat, CGFloat, CGFloat)] = [
            (0.055, 0.585, 0.052), (0.145, 0.600, 0.040), (0.245, 0.588, 0.034),
            (0.325, 0.605, 0.028), (0.615, 0.596, 0.026), (0.705, 0.610, 0.036),
            (0.795, 0.592, 0.044), (0.895, 0.612, 0.038)
        ]
        for (index, clump) in clumps.enumerated() {
            brush.grassTuft(in: &context,
                            base: brush.p(clump.0, clump.1),
                            height: brush.ry(clump.2),
                            width: brush.rx(clump.2 * 1.5),
                            colors: [weed.opacity(0.85), weedLight.opacity(0.8)],
                            bladeCount: 8,
                            seed: 600 &+ index &* 3,
                            shadow: 0.08)
        }
    }

    private func paintDriftwood(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A half-buried branch, bleached by salt water, with weed growing on
        // the sheltered side. It gives the empty near-left sand a story.
        let start = brush.p(0.135, 0.945)
        let end = brush.p(0.415, 0.895)
        brush.contactShadow(in: &context,
                            center: brush.p(0.275, 0.938),
                            width: brush.rx(0.30),
                            height: brush.ry(0.032),
                            opacity: 0.22)
        brush.log(in: &context,
                  from: start,
                  to: end,
                  thickness: brush.ry(0.030),
                  bark: Color(red: 0.54, green: 0.45, blue: 0.33),
                  barkLight: Color(red: 0.74, green: 0.65, blue: 0.50),
                  core: Color(red: 0.66, green: 0.55, blue: 0.39))
        var stub = Path()
        stub.move(to: brush.p(0.315, 0.912))
        stub.addQuadCurve(to: brush.p(0.352, 0.856), control: brush.p(0.322, 0.880))
        context.stroke(stub,
                       with: .color(Color(red: 0.60, green: 0.51, blue: 0.37)),
                       style: brush.stroke(brush.lw(3.0)))
        for index in 0..<3 {
            brush.grassTuft(in: &context,
                            base: brush.p(0.185 + CGFloat(index) * 0.062, 0.930),
                            height: brush.ry(0.040),
                            width: brush.rx(0.048),
                            colors: [weed, weedLight],
                            bladeCount: 6,
                            seed: 700 &+ index,
                            shadow: 0)
        }
        brush.shell(in: &context,
                    center: brush.p(0.455, 0.930),
                    radius: brush.rx(0.030),
                    color: Color(red: 0.97, green: 0.90, blue: 0.80),
                    shade: Color(red: 0.80, green: 0.64, blue: 0.52))
        brush.shell(in: &context,
                    center: brush.p(0.585, 0.965),
                    radius: brush.rx(0.024),
                    color: Color(red: 0.96, green: 0.84, blue: 0.78),
                    shade: Color(red: 0.74, green: 0.52, blue: 0.48))
    }

    private func paintUpperDrift(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Floating weed rafts hanging just under the surface at both top
        // corners, so the upper third of the tank is inhabited too.
        for side in [false, true] {
            let anchorX: CGFloat = side ? 0.94 : 0.06
            let mirror: CGFloat = side ? -1 : 1
            for index in 0..<4 {
                let base = brush.p(anchorX + mirror * CGFloat(index) * 0.035,
                                   0.058 + CGFloat(index % 2) * 0.016)
                var strand = Path()
                strand.move(to: base)
                strand.addCurve(to: CGPoint(x: base.x + mirror * brush.rx(0.045),
                                            y: base.y + brush.ry(0.135)),
                                control1: CGPoint(x: base.x - mirror * brush.rx(0.030),
                                                  y: base.y + brush.ry(0.055)),
                                control2: CGPoint(x: base.x + mirror * brush.rx(0.070),
                                                  y: base.y + brush.ry(0.095)))
                context.stroke(strand,
                               with: .color(Color(red: 0.36, green: 0.56, blue: 0.34).opacity(0.62)),
                               style: brush.stroke(brush.lw(1.6)))
                for bladeIndex in 0..<4 {
                    let t = CGFloat(bladeIndex + 1) / 5
                    let point = CGPoint(x: base.x + mirror * brush.rx(0.045) * t * t,
                                        y: base.y + brush.ry(0.135) * t)
                    brush.leaf(in: &context,
                               center: point,
                               length: brush.ry(0.030),
                               angle: Double(mirror) * 0.9 + Double(bladeIndex) * 0.5,
                               color: Color(red: 0.44, green: 0.62, blue: 0.34).opacity(0.66),
                               vein: 0)
                }
            }
        }

        // A few small air pockets pressed against the surface.
        for index in 0..<7 {
            let point = brush.p(habitatNoise(index, 231, 0.10, 0.92), 0.062 + habitatNoise(index, 232, 0, 0.014))
            let radius = brush.rx(habitatNoise(index, 233, 0.005, 0.011))
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(Color.white.opacity(0.34)))
        }
    }

    private func paintForeground(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Near rock ledges in both bottom corners, dark enough to frame the
        // scene but never tall enough to reach the answer pile.
        var leftLedge = Path()
        leftLedge.move(to: brush.p(-0.02, 1.02))
        leftLedge.addCurve(to: brush.p(0.10, 0.905),
                           control1: brush.p(-0.01, 0.965),
                           control2: brush.p(0.035, 0.912))
        leftLedge.addCurve(to: brush.p(0.235, 1.02),
                           control1: brush.p(0.165, 0.898),
                           control2: brush.p(0.205, 0.960))
        leftLedge.closeSubpath()
        context.fill(leftLedge, with: .linearGradient(
            Gradient(colors: [rockLight.opacity(0.85), rockDark]),
            startPoint: brush.p(0.05, 0.90),
            endPoint: brush.p(0.12, 1.0)))

        var rightLedge = Path()
        rightLedge.move(to: brush.p(1.02, 1.02))
        rightLedge.addCurve(to: brush.p(0.885, 0.885),
                            control1: brush.p(1.01, 0.955),
                            control2: brush.p(0.945, 0.892))
        rightLedge.addCurve(to: brush.p(0.715, 1.02),
                            control1: brush.p(0.815, 0.878),
                            control2: brush.p(0.752, 0.955))
        rightLedge.closeSubpath()
        context.fill(rightLedge, with: .linearGradient(
            Gradient(colors: [rockLight.opacity(0.80), rockDark]),
            startPoint: brush.p(0.95, 0.88),
            endPoint: brush.p(0.88, 1.0)))

        for index in 0..<5 {
            brush.grassTuft(in: &context,
                            base: brush.p(0.02 + CGFloat(index) * 0.045, 0.985),
                            height: brush.ry(0.095),
                            width: brush.rx(0.085),
                            colors: [Color(red: 0.11, green: 0.36, blue: 0.27),
                                     Color(red: 0.24, green: 0.50, blue: 0.28)],
                            bladeCount: 9,
                            seed: 800 &+ index,
                            shadow: 0)
            brush.grassTuft(in: &context,
                            base: brush.p(0.78 + CGFloat(index) * 0.052, 0.995),
                            height: brush.ry(0.108),
                            width: brush.rx(0.090),
                            colors: [Color(red: 0.10, green: 0.33, blue: 0.26),
                                     Color(red: 0.21, green: 0.47, blue: 0.27)],
                            bladeCount: 9,
                            seed: 850 &+ index,
                            shadow: 0)
        }

        brush.kelp(in: &context,
                   base: brush.p(0.045, 1.0),
                   height: brush.ry(0.40),
                   sway: 0.06,
                   color: Color(red: 0.14, green: 0.36, blue: 0.24),
                   blade: Color(red: 0.24, green: 0.50, blue: 0.28),
                   seed: 121)
        brush.kelp(in: &context,
                   base: brush.p(0.965, 1.0),
                   height: brush.ry(0.46),
                   sway: -0.05,
                   color: Color(red: 0.11, green: 0.32, blue: 0.23),
                   blade: Color(red: 0.21, green: 0.46, blue: 0.27),
                   seed: 131)
    }
}
