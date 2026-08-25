//
//  OctopusReefHabitat.swift
//  Nuts & Numbers
//
//  A deep coral reef: the surface far overhead, a drop-off fading into blue,
//  bommies closing both sides, a rock arch above and a swept sand channel down
//  the middle. Everything is drawn from paths and gradients; no bitmaps.
//

import SwiftUI

struct OctopusReefHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let surface = Color(red: 0.62, green: 0.92, blue: 0.96)
    private let shallow = Color(red: 0.20, green: 0.66, blue: 0.82)
    private let mid = Color(red: 0.08, green: 0.42, blue: 0.66)
    private let deep = Color(red: 0.03, green: 0.20, blue: 0.42)
    private let abyss = Color(red: 0.02, green: 0.12, blue: 0.28)
    private let sand = Color(red: 0.84, green: 0.82, blue: 0.70)
    private let sandShade = Color(red: 0.56, green: 0.56, blue: 0.52)
    private let reefRock = Color(red: 0.34, green: 0.36, blue: 0.42)
    private let reefRockLight = Color(red: 0.52, green: 0.54, blue: 0.58)
    private let coralPink = Color(red: 0.93, green: 0.46, blue: 0.55)
    private let coralOrange = Color(red: 0.96, green: 0.58, blue: 0.28)
    private let coralPurple = Color(red: 0.62, green: 0.42, blue: 0.82)
    private let coralTeal = Color(red: 0.30, green: 0.78, blue: 0.72)


    var body: some View {
        Canvas { context, size in
            let brush = HabitatBrush(size: size, isPad: isPad)
            paintWaterColumn(brush, in: &context)
            paintSurface(brush, in: &context)
            paintLightShafts(brush, in: &context)
            paintDropOff(brush, in: &context)
            paintDistantSchool(brush, in: &context)
            paintSeabed(brush, in: &context)
            paintSandChannel(brush, in: &context)
            paintBehindBommies(brush, in: &context)
            paintRockArch(brush, in: &context)
            paintLeftBommie(brush, in: &context)
            paintRightBommie(brush, in: &context)
            paintDen(brush, in: &context)
            paintKelpFringe(brush, in: &context)
            paintSeabedLife(brush, in: &context)
            paintForeground(brush, in: &context)
            paintDepthWash(brush, in: &context)
        }
        .overlay {
            LinearGradient(colors: [.white.opacity(0.06),
                                    .clear,
                                    character.deepColor.opacity(0.08)],
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
                            .init(color: surface, location: 0),
                            .init(color: shallow, location: 0.16),
                            .init(color: mid, location: 0.44),
                            .init(color: deep, location: 0.74),
                            .init(color: abyss, location: 1)
                        ]),
                        startPoint: brush.p(0.5, 0),
                        endPoint: brush.p(0.5, 1)))

        // A cooler wash down the right so the column is not flat.
        context.fill(Path(CGRect(origin: .zero, size: brush.size)),
                     with: .radialGradient(
                        Gradient(colors: [Color(red: 0.40, green: 0.86, blue: 0.94).opacity(0.22), .clear]),
                        center: brush.p(0.34, 0.02),
                        startRadius: 0,
                        endRadius: brush.rx(0.95)))
    }

    private func paintSurface(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // The underside of the surface, seen from below: a rippled ceiling of
        // light. Everything else in the scene hangs beneath it.
        var ceiling = Path()
        ceiling.move(to: brush.p(-0.02, 0))
        ceiling.addLine(to: brush.p(1.02, 0))
        ceiling.addLine(to: brush.p(1.02, 0.070))
        var x: CGFloat = 1.02
        var index = 0
        while x > -0.02 {
            let next = x - 0.085
            ceiling.addQuadCurve(to: brush.p(next, 0.070 + habitatNoise(index, 1, -0.014, 0.014)),
                                 control: brush.p(x - 0.0425, 0.070 + habitatNoise(index, 2, -0.026, 0.026)))
            x = next
            index += 1
        }
        ceiling.closeSubpath()
        context.fill(ceiling, with: .linearGradient(
            Gradient(colors: [Color(red: 0.86, green: 0.98, blue: 1.0).opacity(0.92),
                              surface.opacity(0.35)]),
            startPoint: brush.p(0.5, 0),
            endPoint: brush.p(0.5, 0.085)))

        // Bright caustic seams tracking along the underside.
        for seam in 0..<7 {
            let y = 0.030 + CGFloat(seam) * 0.010
            var path = Path()
            path.move(to: brush.p(-0.02, y))
            for step in 0..<9 {
                let t = CGFloat(step + 1) / 9
                path.addQuadCurve(to: brush.p(-0.02 + t * 1.04, y + habitatNoise(seam &* 10 &+ step, 3, -0.010, 0.010)),
                                  control: brush.p(-0.02 + (t - 0.05) * 1.04,
                                                   y + habitatNoise(seam &* 10 &+ step, 4, -0.018, 0.018)))
            }
            context.stroke(path,
                           with: .color(Color.white.opacity(habitatNoise(seam, 5, 0.10, 0.26))),
                           style: brush.stroke(brush.lw(1.4)))
        }
    }

    private func paintLightShafts(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Columns widen and lean as they sink, so the light reads as coming
        // from one point on the surface rather than from the frame edge.
        let shafts: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
            (0.195, 0.235, 0.075, 0.215, 0.68, 0.11),
            (0.345, 0.372, 0.268, 0.372, 0.60, 0.08),
            (0.520, 0.560, 0.470, 0.640, 0.74, 0.12),
            (0.688, 0.712, 0.660, 0.808, 0.56, 0.07),
            (0.830, 0.862, 0.800, 0.965, 0.66, 0.09),
            (0.075, 0.098, 0.010, 0.104, 0.50, 0.06)
        ]
        for shaft in shafts {
            brush.lightShaft(in: &context,
                             topLeft: shaft.0,
                             topRight: shaft.1,
                             bottomLeft: shaft.2,
                             bottomRight: shaft.3,
                             topY: brush.ry(0.06),
                             bottomY: brush.ry(shaft.4),
                             color: Color(red: 0.80, green: 0.98, blue: 1.0).opacity(shaft.5))
        }
    }

    private func paintDropOff(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A reef wall running away to the left, dissolving into blue. It gives
        // the scene a horizon without needing a sky.
        var wall = Path()
        wall.move(to: brush.p(-0.02, 0.520))
        wall.addCurve(to: brush.p(0.30, 0.575),
                      control1: brush.p(0.08, 0.500),
                      control2: brush.p(0.20, 0.548))
        wall.addCurve(to: brush.p(0.62, 0.600),
                      control1: brush.p(0.42, 0.598),
                      control2: brush.p(0.52, 0.586))
        wall.addCurve(to: brush.p(1.02, 0.556),
                      control1: brush.p(0.78, 0.616),
                      control2: brush.p(0.92, 0.572))
        wall.addLine(to: brush.p(1.02, 0.72))
        wall.addLine(to: brush.p(-0.02, 0.72))
        wall.closeSubpath()
        context.fill(wall, with: .linearGradient(
            Gradient(colors: [Color(red: 0.16, green: 0.44, blue: 0.60).opacity(0.62),
                              Color(red: 0.06, green: 0.26, blue: 0.46).opacity(0.40)]),
            startPoint: brush.p(0.5, 0.50),
            endPoint: brush.p(0.5, 0.70)))

        // Coral heads along the rim, small and hazy.
        for index in 0..<20 {
            let x = -0.02 + CGFloat(index) / 19 * 1.04
            let y = 0.556 + habitatNoise(index, 11, -0.030, 0.020)
            let radius = brush.rx(habitatNoise(index, 12, 0.020, 0.048))
            var head = Path()
            head.move(to: CGPoint(x: brush.rx(x) - radius, y: brush.ry(y) + radius * 0.3))
            head.addCurve(to: CGPoint(x: brush.rx(x) + radius, y: brush.ry(y) + radius * 0.3),
                          control1: CGPoint(x: brush.rx(x) - radius * 0.7, y: brush.ry(y) - radius * 1.1),
                          control2: CGPoint(x: brush.rx(x) + radius * 0.7, y: brush.ry(y) - radius * 1.1))
            head.closeSubpath()
            context.fill(head, with: .color(Color(red: 0.12, green: 0.36, blue: 0.54).opacity(0.55)))
        }
        brush.hazeBand(in: &context, top: 0.470, bottom: 0.620,
                       color: Color(red: 0.34, green: 0.72, blue: 0.86).opacity(0.28))
    }

    private func paintDistantSchool(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A baitball hanging in the blue on the upper left. Specks only: drawn
        // fish here would sit frozen next to the swimming ones in the motion
        // layer and read as stuck in the water.
        for index in 0..<42 {
            let angle = Double(habitatNoise(index, 21)) * 2 * .pi
            let radius = CGFloat(habitatNoise(index, 22)) * 0.5 + 0.02
            let center = brush.p(0.255 + CGFloat(cos(angle)) * radius * 0.30,
                                 0.315 + CGFloat(sin(angle)) * radius * 0.22)
            let size = brush.rx(habitatNoise(index, 23, 0.004, 0.010))
            context.fill(Path(ellipseIn: CGRect(x: center.x - size, y: center.y - size * 0.55,
                                                width: size * 2.2, height: size * 1.1)),
                         with: .color(Color(red: 0.10, green: 0.32, blue: 0.50)
                            .opacity(0.22 + Double(habitatNoise(index, 24, 0, 0.18)))))
        }
    }

    // MARK: - Seabed

    private func paintSeabed(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var bed = Path()
        bed.move(to: brush.p(-0.02, 0.688))
        bed.addCurve(to: brush.p(0.34, 0.716),
                     control1: brush.p(0.10, 0.700),
                     control2: brush.p(0.22, 0.706))
        bed.addCurve(to: brush.p(0.70, 0.702),
                     control1: brush.p(0.48, 0.728),
                     control2: brush.p(0.58, 0.694))
        bed.addCurve(to: brush.p(1.02, 0.734),
                     control1: brush.p(0.84, 0.712),
                     control2: brush.p(0.94, 0.740))
        bed.addLine(to: brush.p(1.02, 1.04))
        bed.addLine(to: brush.p(-0.02, 1.04))
        bed.closeSubpath()
        context.fill(bed, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.56, green: 0.68, blue: 0.68), location: 0),
                .init(color: Color(red: 0.74, green: 0.76, blue: 0.68), location: 0.28),
                .init(color: sand, location: 0.62),
                .init(color: Color(red: 0.70, green: 0.68, blue: 0.58), location: 1)
            ]),
            startPoint: brush.p(0.5, 0.69),
            endPoint: brush.p(0.5, 1)))

        brush.surfaceStrokes(in: &context,
                             bounds: CGRect(x: 0, y: brush.ry(0.720),
                                            width: brush.w, height: brush.ry(0.280)),
                             count: 26,
                             color: sandShade.opacity(0.26),
                             highlight: Color.white.opacity(0.20),
                             lengthRange: 0.04...0.15,
                             seed: 400)
    }

    private func paintSandChannel(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Same vanishing recipe as the lion wash: pinch to a point on the
        // seabed horizon so the two cabinets share a path into the distance.
        var channel = Path()
        channel.move(to: brush.p(0.490, 0.718))
        channel.addCurve(to: brush.p(0.300, 1.04),
                         control1: brush.p(0.430, 0.82),
                         control2: brush.p(0.305, 0.93))
        channel.addLine(to: brush.p(0.720, 1.04))
        channel.addCurve(to: brush.p(0.530, 0.718),
                         control1: brush.p(0.715, 0.93),
                         control2: brush.p(0.590, 0.82))
        channel.closeSubpath()
        context.fill(channel, with: .linearGradient(
            Gradient(colors: [Color(red: 0.90, green: 0.86, blue: 0.72).opacity(0.08),
                              Color(red: 0.84, green: 0.80, blue: 0.66).opacity(0.40)]),
            startPoint: brush.p(0.51, 0.718),
            endPoint: brush.p(0.51, 1.0)))

        context.drawLayer { inner in
            inner.clip(to: channel)
            for index in 0..<11 {
                let t = CGFloat(index) / 10
                let y = 0.780 + t * t * 0.240
                let half = 0.022 + t * 0.18
                var ripple = Path()
                ripple.move(to: brush.p(0.50 - half, y))
                ripple.addQuadCurve(to: brush.p(0.50 + half, y + habitatNoise(index, 31, -0.006, 0.006)),
                                    control: brush.p(0.50, y - 0.010 - t * 0.008))
                inner.stroke(ripple,
                             with: .color(Color.white.opacity(0.14 + Double(t) * 0.10)),
                             style: brush.stroke(brush.lw(1.0 + t * 1.1)))
            }
        }

        brush.pebbleBeds(in: &context,
                         bounds: CGRect(x: brush.rx(0.30), y: brush.ry(0.780),
                                        width: brush.rx(0.42), height: brush.ry(0.220)),
                         color: Color(red: 0.46, green: 0.46, blue: 0.42).opacity(0.40),
                         highlight: Color.white.opacity(0.22),
                         clusters: 10,
                         seed: 450)
    }

    // MARK: - Structure

    private func paintRockArch(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Hanging life is drawn first, with roots inside the forthcoming
        // ledge. The rock then covers the holdfasts so nothing sits on top
        // of the stone or grows up into it.
        let hang: [(CGFloat, CGFloat, CGFloat, Color)] = [
            (0.130, 0.082, 0.112, coralOrange),
            (0.188, 0.122, 0.092, coralPurple),
            (0.236, 0.148, 0.074, coralOrange),
            (0.754, 0.148, 0.076, coralOrange),
            (0.816, 0.138, 0.110, coralPink),
            (0.874, 0.108, 0.092, coralPurple)
        ]
        for (index, item) in hang.enumerated() {
            brush.gorgonian(in: &context,
                            root: brush.p(item.0, item.1),
                            length: brush.ry(item.2),
                            color: item.3,
                            seed: 430 &+ index &* 5,
                            hanging: true)
        }

        var ledge = Path()
        ledge.move(to: brush.p(-0.02, 0.030))
        ledge.addCurve(to: brush.p(0.26, 0.185),
                       control1: brush.p(0.08, 0.090),
                       control2: brush.p(0.16, 0.170))
        ledge.addCurve(to: brush.p(0.50, 0.128),
                       control1: brush.p(0.35, 0.198),
                       control2: brush.p(0.43, 0.164))
        ledge.addCurve(to: brush.p(0.78, 0.196),
                       control1: brush.p(0.60, 0.098),
                       control2: brush.p(0.70, 0.166))
        ledge.addCurve(to: brush.p(1.02, 0.108),
                       control1: brush.p(0.88, 0.220),
                       control2: brush.p(0.96, 0.170))
        ledge.addLine(to: brush.p(1.02, -0.02))
        ledge.addLine(to: brush.p(-0.02, -0.02))
        ledge.closeSubpath()
        context.fill(ledge, with: .linearGradient(
            Gradient(colors: [reefRockLight.opacity(0.90), reefRock.opacity(0.96),
                              Color(red: 0.16, green: 0.22, blue: 0.32)]),
            startPoint: brush.p(0.5, 0),
            endPoint: brush.p(0.5, 0.20)))

        var lip = Path()
        lip.move(to: brush.p(-0.02, 0.030))
        lip.addCurve(to: brush.p(0.26, 0.185),
                     control1: brush.p(0.08, 0.090),
                     control2: brush.p(0.16, 0.170))
        lip.addCurve(to: brush.p(0.50, 0.128),
                     control1: brush.p(0.35, 0.198),
                     control2: brush.p(0.43, 0.164))
        lip.addCurve(to: brush.p(0.78, 0.196),
                     control1: brush.p(0.60, 0.098),
                     control2: brush.p(0.70, 0.166))
        lip.addCurve(to: brush.p(1.02, 0.108),
                     control1: brush.p(0.88, 0.220),
                     control2: brush.p(0.96, 0.170))
        context.stroke(lip, with: .color(Color(red: 0.10, green: 0.14, blue: 0.22).opacity(0.55)),
                       style: brush.stroke(brush.lw(2.2)))
    }

    private func paintBehindBommies(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Pink and purple sit on the sand behind the towers: in front of the
        // channel wash, tucked under the rock so they peek at the inner flanks
        // instead of occupying the open middle.
        brush.seaFan(in: &context,
                     base: brush.p(0.208, 0.776),
                     height: brush.ry(0.100),
                     color: coralPink.opacity(0.72),
                     seed: 37)
        brush.branchCoral(in: &context,
                          base: brush.p(0.186, 0.818),
                          height: brush.ry(0.092),
                          color: coralPurple.opacity(0.76),
                          thickness: brush.lw(1.8),
                          seed: 29)
        brush.starfish(in: &context,
                       center: brush.p(0.078, 0.872),
                       radius: brush.rx(0.032),
                       color: Color(red: 0.62, green: 0.48, blue: 0.86),
                       shade: Color(red: 0.36, green: 0.24, blue: 0.58),
                       rotation: -0.4)
        brush.seaFan(in: &context,
                     base: brush.p(0.788, 0.780),
                     height: brush.ry(0.096),
                     color: coralPurple.opacity(0.70),
                     seed: 71)
        brush.branchCoral(in: &context,
                          base: brush.p(0.812, 0.822),
                          height: brush.ry(0.088),
                          color: coralPink.opacity(0.76),
                          thickness: brush.lw(1.8),
                          seed: 61)
        brush.urchin(in: &context,
                     center: brush.p(0.805, 0.852),
                     radius: brush.rx(0.024),
                     color: Color(red: 0.22, green: 0.16, blue: 0.30),
                     spine: Color(red: 0.42, green: 0.30, blue: 0.52),
                     seed: 1004)
    }

    private func paintLeftBommie(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A coral tower on the left, built from a rock core with plate, brain
        // and branching colonies growing off it.
        var tower = Path()
        tower.move(to: brush.p(-0.06, 0.860))
        tower.addCurve(to: brush.p(0.055, 0.520),
                       control1: brush.p(-0.02, 0.740),
                       control2: brush.p(0.010, 0.586))
        tower.addCurve(to: brush.p(0.205, 0.596),
                       control1: brush.p(0.105, 0.470),
                       control2: brush.p(0.176, 0.520))
        tower.addCurve(to: brush.p(0.265, 0.860),
                       control1: brush.p(0.232, 0.674),
                       control2: brush.p(0.262, 0.760))
        tower.closeSubpath()
        context.fill(tower, with: .linearGradient(
            Gradient(colors: [reefRockLight, reefRock, Color(red: 0.18, green: 0.24, blue: 0.34)]),
            startPoint: brush.p(0.04, 0.50),
            endPoint: brush.p(0.24, 0.86)))
        brush.contactShadow(in: &context,
                            center: brush.p(0.105, 0.862),
                            width: brush.rx(0.44),
                            height: brush.ry(0.045),
                            opacity: 0.34)

        brush.plateCoral(in: &context,
                         base: brush.p(0.072, 0.600),
                         width: brush.rx(0.215),
                         color: coralOrange.opacity(0.92),
                         shade: Color(red: 0.62, green: 0.30, blue: 0.16),
                         seed: 21)
        brush.plateCoral(in: &context,
                         base: brush.p(0.118, 0.668),
                         width: brush.rx(0.170),
                         color: coralPink.opacity(0.88),
                         shade: Color(red: 0.56, green: 0.20, blue: 0.28),
                         seed: 27)
        brush.brainCoral(in: &context,
                         center: brush.p(0.062, 0.712),
                         radius: brush.rx(0.075),
                         color: Color(red: 0.86, green: 0.72, blue: 0.42),
                         groove: Color(red: 0.52, green: 0.38, blue: 0.20),
                         seed: 23)
        brush.branchCoral(in: &context,
                          base: brush.p(0.040, 0.828),
                          height: brush.ry(0.150),
                          color: coralTeal,
                          thickness: brush.lw(2.3),
                          seed: 31)
        brush.sponge(in: &context,
                     base: brush.p(0.010, 0.790),
                     height: brush.ry(0.105),
                     color: Color(red: 0.84, green: 0.44, blue: 0.32),
                     shade: Color(red: 0.42, green: 0.18, blue: 0.16),
                     tubes: 3,
                     seed: 41)
        brush.anemone(in: &context,
                      base: brush.p(0.140, 0.596),
                      radius: brush.rx(0.048),
                      color: Color(red: 0.88, green: 0.58, blue: 0.62),
                      tip: Color(red: 0.99, green: 0.86, blue: 0.76),
                      tentacles: 15,
                      seed: 43)
    }

    private func paintRightBommie(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var tower = Path()
        tower.move(to: brush.p(1.06, 0.880))
        tower.addCurve(to: brush.p(0.955, 0.470),
                       control1: brush.p(1.03, 0.740),
                       control2: brush.p(0.990, 0.556))
        tower.addCurve(to: brush.p(0.808, 0.594),
                       control1: brush.p(0.912, 0.418),
                       control2: brush.p(0.830, 0.508))
        tower.addCurve(to: brush.p(0.752, 0.880),
                       control1: brush.p(0.788, 0.680),
                       control2: brush.p(0.756, 0.784))
        tower.closeSubpath()
        context.fill(tower, with: .linearGradient(
            Gradient(colors: [reefRockLight, reefRock, Color(red: 0.16, green: 0.22, blue: 0.32)]),
            startPoint: brush.p(0.80, 0.46),
            endPoint: brush.p(1.00, 0.88)))
        brush.contactShadow(in: &context,
                            center: brush.p(0.905, 0.882),
                            width: brush.rx(0.46),
                            height: brush.ry(0.046),
                            opacity: 0.34)

        brush.plateCoral(in: &context,
                         base: brush.p(0.930, 0.560),
                         width: brush.rx(0.200),
                         color: coralTeal.opacity(0.88),
                         shade: Color(red: 0.14, green: 0.44, blue: 0.42),
                         seed: 51)
        brush.plateCoral(in: &context,
                         base: brush.p(0.888, 0.655),
                         width: brush.rx(0.155),
                         color: coralOrange.opacity(0.85),
                         shade: Color(red: 0.60, green: 0.28, blue: 0.14),
                         seed: 57)
        brush.brainCoral(in: &context,
                         center: brush.p(0.965, 0.700),
                         radius: brush.rx(0.070),
                         color: Color(red: 0.74, green: 0.80, blue: 0.60),
                         groove: Color(red: 0.38, green: 0.46, blue: 0.30),
                         seed: 59)
        brush.branchCoral(in: &context,
                          base: brush.p(0.982, 0.836),
                          height: brush.ry(0.145),
                          color: Color(red: 0.96, green: 0.78, blue: 0.34),
                          thickness: brush.lw(2.2),
                          seed: 67)
        brush.sponge(in: &context,
                     base: brush.p(0.900, 0.800),
                     height: brush.ry(0.115),
                     color: Color(red: 0.52, green: 0.66, blue: 0.86),
                     shade: Color(red: 0.20, green: 0.30, blue: 0.52),
                     tubes: 3,
                     seed: 73)
        brush.anemone(in: &context,
                      base: brush.p(0.876, 0.620),
                      radius: brush.rx(0.044),
                      color: Color(red: 0.78, green: 0.68, blue: 0.90),
                      tip: Color(red: 0.94, green: 0.90, blue: 1.0),
                      tentacles: 13,
                      seed: 79)
    }

    private func paintDen(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // The octopus' own den: a dark hollow under the left bommie with a
        // midden of shells piled at the entrance. A lived-in detail rather
        // than a decorative hole.
        let mouth = brush.p(0.152, 0.816)
        var hollow = Path()
        hollow.move(to: CGPoint(x: mouth.x - brush.rx(0.062), y: mouth.y + brush.ry(0.038)))
        hollow.addCurve(to: CGPoint(x: mouth.x + brush.rx(0.060), y: mouth.y + brush.ry(0.036)),
                        control1: CGPoint(x: mouth.x - brush.rx(0.068), y: mouth.y - brush.ry(0.048)),
                        control2: CGPoint(x: mouth.x + brush.rx(0.070), y: mouth.y - brush.ry(0.050)))
        hollow.addQuadCurve(to: CGPoint(x: mouth.x - brush.rx(0.062), y: mouth.y + brush.ry(0.038)),
                            control: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.058)))
        hollow.closeSubpath()
        context.fill(hollow, with: .radialGradient(
            Gradient(colors: [Color.black.opacity(0.94), Color(red: 0.04, green: 0.10, blue: 0.20)]),
            center: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.012)),
            startRadius: 0,
            endRadius: brush.rx(0.075)))

        for index in 0..<11 {
            brush.shell(in: &context,
                        center: brush.p(habitatNoise(index, 81, 0.075, 0.235),
                                        habitatNoise(index, 82, 0.852, 0.900)),
                        radius: brush.rx(habitatNoise(index, 83, 0.014, 0.026)),
                        color: index.isMultiple(of: 3)
                            ? Color(red: 0.92, green: 0.88, blue: 0.80)
                            : Color(red: 0.86, green: 0.78, blue: 0.72),
                        shade: Color(red: 0.58, green: 0.50, blue: 0.44))
        }
    }

    private func paintKelpFringe(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Ribbon weed standing along both edges, tall enough to reach into the
        // upper half and tie the bommies to the overhang.
        // Kept to the outer sixth of the frame. The blades this primitive
        // grows scale with the stipe, so tall stands in the middle would put
        // large leaves straight across the drop corridor.
        let stands: [(CGFloat, CGFloat, CGFloat)] = [
            (0.012, 0.930, 0.28), (0.058, 0.950, 0.22), (0.108, 0.925, 0.16),
            (0.892, 0.925, 0.16), (0.942, 0.950, 0.22), (0.994, 0.925, 0.28)
        ]
        for (index, stand) in stands.enumerated() {
            brush.kelp(in: &context,
                       base: brush.p(stand.0, stand.1),
                       height: brush.ry(stand.2),
                       sway: index.isMultiple(of: 2) ? 0.055 : -0.048,
                       color: Color(red: 0.18, green: 0.40, blue: 0.26),
                       blade: Color(red: 0.30, green: 0.56, blue: 0.30),
                       seed: 900 &+ index &* 7)
        }
    }

    private func paintSeabedLife(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Sparse, low life across the open sand: it should populate the floor
        // without cluttering the drop zone.
        brush.starfish(in: &context,
                       center: brush.p(0.335, 0.930),
                       radius: brush.rx(0.055),
                       color: Color(red: 0.95, green: 0.52, blue: 0.30),
                       shade: Color(red: 0.68, green: 0.28, blue: 0.16),
                       rotation: 0.4)

        brush.urchin(in: &context,
                     center: brush.p(0.255, 0.868),
                     radius: brush.rx(0.026),
                     color: Color(red: 0.22, green: 0.16, blue: 0.30),
                     spine: Color(red: 0.42, green: 0.30, blue: 0.52),
                     seed: 1000)

        // Sea grass tufts rooted in the sand at the channel edges.
        for index in 0..<9 {
            let x = index < 5
                ? 0.230 + CGFloat(index) * 0.026
                : 0.640 + CGFloat(index - 5) * 0.028
            brush.grassTuft(in: &context,
                            base: brush.p(x, 0.818 + habitatNoise(index, 91, -0.008, 0.010)),
                            height: brush.ry(habitatNoise(index, 92, 0.060, 0.105)),
                            width: brush.rx(0.048),
                            colors: [Color(red: 0.20, green: 0.42, blue: 0.32),
                                     Color(red: 0.28, green: 0.54, blue: 0.36),
                                     Color(red: 0.42, green: 0.68, blue: 0.42)],
                            bladeCount: 7,
                            seed: 1100 &+ index,
                            shadow: 0.18)
        }

        // A giant clam wedged into the sand, its mantle the brightest accent
        // on the floor.
        let clam = brush.p(0.470, 0.962)
        let clamWidth = brush.rx(0.115)
        brush.contactShadow(in: &context, center: clam,
                            width: clamWidth * 1.5, height: brush.ry(0.020), opacity: 0.30)
        var shellPath = Path()
        shellPath.move(to: CGPoint(x: clam.x - clamWidth * 0.5, y: clam.y))
        shellPath.addCurve(to: CGPoint(x: clam.x + clamWidth * 0.5, y: clam.y),
                           control1: CGPoint(x: clam.x - clamWidth * 0.42, y: clam.y - brush.ry(0.055)),
                           control2: CGPoint(x: clam.x + clamWidth * 0.42, y: clam.y - brush.ry(0.055)))
        shellPath.addQuadCurve(to: CGPoint(x: clam.x - clamWidth * 0.5, y: clam.y),
                               control: CGPoint(x: clam.x, y: clam.y + brush.ry(0.022)))
        shellPath.closeSubpath()
        context.fill(shellPath, with: .linearGradient(
            Gradient(colors: [Color(red: 0.88, green: 0.86, blue: 0.78), Color(red: 0.60, green: 0.58, blue: 0.52)]),
            startPoint: CGPoint(x: clam.x, y: clam.y - brush.ry(0.055)),
            endPoint: CGPoint(x: clam.x, y: clam.y)))
        var mantle = Path()
        mantle.move(to: CGPoint(x: clam.x - clamWidth * 0.40, y: clam.y - brush.ry(0.014)))
        for step in 0..<9 {
            let t = CGFloat(step + 1) / 9
            mantle.addQuadCurve(to: CGPoint(x: clam.x - clamWidth * 0.40 + clamWidth * 0.80 * t,
                                            y: clam.y - brush.ry(0.014)),
                                control: CGPoint(x: clam.x - clamWidth * 0.40 + clamWidth * 0.80 * (t - 0.055),
                                                 y: clam.y - brush.ry(step.isMultiple(of: 2) ? 0.026 : 0.006)))
        }
        context.stroke(mantle,
                       with: .linearGradient(
                        Gradient(colors: [Color(red: 0.24, green: 0.76, blue: 0.72),
                                          Color(red: 0.36, green: 0.44, blue: 0.86)]),
                        startPoint: CGPoint(x: clam.x - clamWidth * 0.5, y: clam.y),
                        endPoint: CGPoint(x: clam.x + clamWidth * 0.5, y: clam.y)),
                       style: brush.stroke(brush.ry(0.016)))
    }

    private func paintForeground(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Dark, out-of-focus coral cropping the bottom corners. Low contrast
        // and heavily shadowed so it frames without competing.
        for corner in 0..<2 {
            let anchor: CGFloat = corner == 0 ? -0.04 : 1.04
            let direction: CGFloat = corner == 0 ? 1 : -1
            var mass = Path()
            mass.move(to: brush.p(anchor, 1.05))
            mass.addCurve(to: brush.p(anchor + direction * 0.10, 0.905),
                          control1: brush.p(anchor + direction * 0.02, 1.00),
                          control2: brush.p(anchor + direction * 0.03, 0.940))
            mass.addCurve(to: brush.p(anchor + direction * 0.26, 0.965),
                          control1: brush.p(anchor + direction * 0.17, 0.885),
                          control2: brush.p(anchor + direction * 0.23, 0.918))
            mass.addCurve(to: brush.p(anchor + direction * 0.34, 1.05),
                          control1: brush.p(anchor + direction * 0.29, 0.998),
                          control2: brush.p(anchor + direction * 0.33, 1.02))
            mass.closeSubpath()
            context.fill(mass, with: .linearGradient(
                Gradient(colors: [Color(red: 0.10, green: 0.20, blue: 0.30).opacity(0.88),
                                  Color(red: 0.03, green: 0.09, blue: 0.18).opacity(0.95)]),
                startPoint: brush.p(anchor, 0.90),
                endPoint: brush.p(anchor, 1.05)))

            for index in 0..<4 {
                brush.branchCoral(in: &context,
                                  base: brush.p(anchor + direction * (0.06 + CGFloat(index) * 0.070), 1.010),
                                  height: brush.ry(0.135 + habitatNoise(index, 95, 0, 0.070)),
                                  color: Color(red: 0.09, green: 0.19, blue: 0.30).opacity(0.92),
                                  thickness: brush.lw(3.0),
                                  seed: 1200 &+ corner &* 40 &+ index)
            }
        }
    }

    private func paintDepthWash(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Blue scatter over the whole scene, strongest in the distance. This
        // is what makes the reef feel like it is genuinely underwater.
        context.fill(Path(CGRect(origin: .zero, size: brush.size)),
                     with: .radialGradient(
                        Gradient(colors: [Color(red: 0.20, green: 0.62, blue: 0.80).opacity(0.26),
                                          .clear]),
                        center: brush.p(0.48, 0.560),
                        startRadius: 0,
                        endRadius: brush.rx(0.66)))
        context.fill(Path(CGRect(origin: .zero, size: brush.size)),
                     with: .linearGradient(
                        Gradient(colors: [.clear, Color(red: 0.02, green: 0.10, blue: 0.24).opacity(0.30)]),
                        startPoint: brush.p(0.5, 0.62),
                        endPoint: brush.p(0.5, 1.0)))
    }
}
