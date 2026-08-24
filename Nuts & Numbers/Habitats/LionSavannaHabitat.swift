//
//  LionSavannaHabitat.swift
//  Nuts & Numbers
//
//  Dry-season savanna in the late afternoon: a granite kopje on the right, an
//  escarpment on the horizon, bleached grass across the plain and an umbrella
//  acacia leaning in over the top-left. Deliberately hot and dusty so it never
//  reads as the same place as the elephant's green waterhole.
//

import SwiftUI

struct LionSavannaHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let skyTop = Color(red: 0.36, green: 0.60, blue: 0.86)
    private let skyMid = Color(red: 0.78, green: 0.79, blue: 0.72)
    private let skyHaze = Color(red: 0.97, green: 0.83, blue: 0.52)
    private let ridgeFar = Color(red: 0.60, green: 0.60, blue: 0.63)
    private let ridgeNear = Color(red: 0.48, green: 0.46, blue: 0.42)
    private let grassGold = Color(red: 0.85, green: 0.70, blue: 0.33)
    private let grassPale = Color(red: 0.93, green: 0.83, blue: 0.52)
    private let grassDeep = Color(red: 0.54, green: 0.41, blue: 0.17)
    private let earth = Color(red: 0.62, green: 0.44, blue: 0.24)
    private let earthDeep = Color(red: 0.38, green: 0.25, blue: 0.13)
    private let rock = Color(red: 0.63, green: 0.57, blue: 0.50)
    private let rockShade = Color(red: 0.36, green: 0.31, blue: 0.28)
    private let bark = Color(red: 0.33, green: 0.22, blue: 0.13)
    private let barkLight = Color(red: 0.60, green: 0.45, blue: 0.28)
    private let foliage = Color(red: 0.28, green: 0.37, blue: 0.17)
    private let foliageLight = Color(red: 0.45, green: 0.53, blue: 0.22)

    var body: some View {
        Canvas { context, size in
            let brush = HabitatBrush(size: size, isPad: isPad)
            paintSky(brush, in: &context)
            paintEscarpment(brush, in: &context)
            paintDistantTrees(brush, in: &context)
            paintPlain(brush, in: &context)
            paintPlainTexture(brush, in: &context)
            paintDryWash(brush, in: &context)
            paintTermiteMound(brush, in: &context)
            paintKopje(brush, in: &context)
            paintScrub(brush, in: &context)
            paintAcacia(brush, in: &context)
            paintDeadwood(brush, in: &context)
            paintForeground(brush, in: &context)
            paintHeatWash(brush, in: &context)
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

    // MARK: - Distance

    private func paintSky(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        context.fill(Path(CGRect(origin: .zero, size: brush.size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: skyTop, location: 0),
                            .init(color: Color(red: 0.62, green: 0.72, blue: 0.82), location: 0.24),
                            .init(color: skyMid, location: 0.40),
                            .init(color: skyHaze, location: 0.56)
                        ]),
                        startPoint: brush.p(0.4, 0),
                        endPoint: brush.p(0.6, 0.60)))

        brush.sun(in: &context,
                  center: brush.p(0.735, 0.235),
                  radius: brush.rx(0.082),
                  core: Color(red: 1.0, green: 0.95, blue: 0.74).opacity(0.80),
                  glow: Color(red: 1.0, green: 0.84, blue: 0.44).opacity(0.34),
                  glowSpread: 4.4)

        // Thin, stretched cirrus rather than fat cumulus: it reads as dry air.
        for index in 0..<7 {
            let y = habitatNoise(index, 1, 0.075, 0.330)
            let x = habitatNoise(index, 2, 0.05, 0.95)
            let width = brush.rx(habitatNoise(index, 3, 0.22, 0.44))
            let height = brush.ry(habitatNoise(index, 4, 0.006, 0.014))
            var streak = Path()
            streak.move(to: CGPoint(x: brush.rx(x) - width * 0.5, y: brush.ry(y)))
            streak.addQuadCurve(to: CGPoint(x: brush.rx(x) + width * 0.5, y: brush.ry(y) - height * 0.6),
                                control: CGPoint(x: brush.rx(x), y: brush.ry(y) - height * 2.2))
            streak.addQuadCurve(to: CGPoint(x: brush.rx(x) - width * 0.5, y: brush.ry(y)),
                                control: CGPoint(x: brush.rx(x), y: brush.ry(y) + height * 1.4))
            streak.closeSubpath()
            context.fill(streak, with: .color(Color.white.opacity(habitatNoise(index, 5, 0.20, 0.44))))
        }

        brush.hazeBand(in: &context, top: 0.420, bottom: 0.585,
                       color: Color(red: 1.0, green: 0.90, blue: 0.66).opacity(0.40))
    }

    private func paintEscarpment(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Two flat-topped ridges, the classic Rift Valley silhouette.
        var far = Path()
        far.move(to: brush.p(-0.02, 0.560))
        far.addLine(to: brush.p(0.10, 0.508))
        far.addLine(to: brush.p(0.27, 0.498))
        far.addLine(to: brush.p(0.36, 0.524))
        far.addLine(to: brush.p(0.52, 0.514))
        far.addLine(to: brush.p(0.63, 0.486))
        far.addLine(to: brush.p(0.79, 0.492))
        far.addLine(to: brush.p(0.90, 0.520))
        far.addLine(to: brush.p(1.02, 0.506))
        far.addLine(to: brush.p(1.02, 0.60))
        far.addLine(to: brush.p(-0.02, 0.60))
        far.closeSubpath()
        context.fill(far, with: .linearGradient(
            Gradient(colors: [ridgeFar.opacity(0.62), ridgeFar.opacity(0.28)]),
            startPoint: brush.p(0.5, 0.48),
            endPoint: brush.p(0.5, 0.585)))

        var near = Path()
        near.move(to: brush.p(-0.02, 0.578))
        near.addQuadCurve(to: brush.p(0.22, 0.540), control: brush.p(0.09, 0.542))
        near.addLine(to: brush.p(0.44, 0.548))
        near.addQuadCurve(to: brush.p(0.70, 0.534), control: brush.p(0.57, 0.522))
        near.addQuadCurve(to: brush.p(1.02, 0.556), control: brush.p(0.88, 0.548))
        near.addLine(to: brush.p(1.02, 0.62))
        near.addLine(to: brush.p(-0.02, 0.62))
        near.closeSubpath()
        context.fill(near, with: .linearGradient(
            Gradient(colors: [ridgeNear.opacity(0.52), ridgeNear.opacity(0.22)]),
            startPoint: brush.p(0.5, 0.53),
            endPoint: brush.p(0.5, 0.60)))
    }

    private func paintDistantTrees(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Umbrella crowns shrinking toward the horizon: the cheapest and most
        // convincing depth cue this landscape has.
        for index in 0..<14 {
            let t = CGFloat(index) / 13
            let x = 0.02 + t * 0.96 + habitatNoise(index, 11, -0.026, 0.026)
            let baseY = 0.585 + habitatNoise(index, 12, -0.008, 0.012)
            let scale = habitatNoise(index, 13, 0.020, 0.046)
            let opacity = habitatNoise(index, 14, 0.28, 0.52)

            var trunk = Path()
            trunk.move(to: brush.p(x, baseY))
            trunk.addQuadCurve(to: brush.p(x + scale * 0.16, baseY - scale * 1.5),
                               control: brush.p(x + scale * 0.02, baseY - scale * 0.8))
            context.stroke(trunk,
                           with: .color(bark.opacity(opacity)),
                           style: brush.stroke(brush.lw(1.2)))

            var crown = Path()
            let top = brush.p(x + scale * 0.16, baseY - scale * 1.62)
            crown.move(to: CGPoint(x: top.x - brush.rx(scale * 1.25), y: top.y + brush.ry(scale * 0.22)))
            crown.addQuadCurve(to: CGPoint(x: top.x + brush.rx(scale * 1.25), y: top.y + brush.ry(scale * 0.20)),
                               control: CGPoint(x: top.x, y: top.y - brush.ry(scale * 0.72)))
            crown.addQuadCurve(to: CGPoint(x: top.x - brush.rx(scale * 1.25), y: top.y + brush.ry(scale * 0.22)),
                               control: CGPoint(x: top.x, y: top.y + brush.ry(scale * 0.46)))
            crown.closeSubpath()
            context.fill(crown, with: .color(foliage.opacity(opacity)))
        }
    }

    // MARK: - Plain

    private func paintPlain(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var plain = Path()
        plain.move(to: brush.p(-0.02, 0.588))
        plain.addQuadCurve(to: brush.p(1.02, 0.582), control: brush.p(0.5, 0.602))
        plain.addLine(to: brush.p(1.02, 1.04))
        plain.addLine(to: brush.p(-0.02, 1.04))
        plain.closeSubpath()
        context.fill(plain, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.90, green: 0.79, blue: 0.48), location: 0),
                .init(color: grassGold, location: 0.26),
                .init(color: Color(red: 0.72, green: 0.56, blue: 0.24), location: 0.66),
                .init(color: grassDeep, location: 1)
            ]),
            startPoint: brush.p(0.5, 0.585),
            endPoint: brush.p(0.5, 1)))
    }

    private func paintPlainTexture(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        let patches: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (0.20, 0.640, 0.34, 0.030, grassPale.opacity(0.34)),
            (0.72, 0.652, 0.36, 0.034, grassPale.opacity(0.28)),
            (0.44, 0.720, 0.46, 0.060, earth.opacity(0.22)),
            (0.86, 0.800, 0.34, 0.070, grassDeep.opacity(0.26)),
            (0.14, 0.860, 0.38, 0.085, earth.opacity(0.24)),
            (0.56, 0.940, 0.50, 0.095, grassDeep.opacity(0.28))
        ]
        for (index, patch) in patches.enumerated() {
            brush.groundPatch(in: &context,
                              center: brush.p(patch.0, patch.1),
                              width: brush.rx(patch.2),
                              height: brush.ry(patch.3),
                              color: patch.4,
                              seed: 200 &+ index &* 17)
        }

        brush.surfaceStrokes(in: &context,
                             bounds: brush.box(0.5, 0.8025, 1.04, 0.395),
                             count: 34,
                             color: grassPale.opacity(0.34),
                             highlight: Color.white.opacity(0.16),
                             lengthRange: 0.020...0.075,
                             seed: 300)
        brush.surfaceStrokes(in: &context,
                             bounds: brush.box(0.5, 0.840, 1.04, 0.320),
                             count: 22,
                             color: earthDeep.opacity(0.20),
                             highlight: nil,
                             lengthRange: 0.016...0.060,
                             seed: 360)

        // Stubble: short paired flicks of dry grass, denser toward the viewer.
        for index in 0..<90 {
            let depth = habitatNoise(index, 41)
            let y = 0.610 + depth * depth * 0.39
            let x = habitatNoise(index, 42, -0.01, 1.01)
            let height = brush.ry(0.008 + depth * 0.028)
            let point = brush.p(x, y)
            for side in 0..<2 {
                let lean = CGFloat(side == 0 ? -1 : 1) * brush.rx(habitatNoise(index, 43 + side, 0.002, 0.012))
                var blade = Path()
                blade.move(to: point)
                blade.addQuadCurve(to: CGPoint(x: point.x + lean, y: point.y - height),
                                   control: CGPoint(x: point.x + lean * 0.2, y: point.y - height * 0.6))
                context.stroke(blade,
                               with: .color(index.isMultiple(of: 3)
                                            ? grassDeep.opacity(0.42)
                                            : grassPale.opacity(0.46)),
                               style: brush.stroke(brush.lw(0.9)))
            }
        }
    }

    private func paintDryWash(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A sandy watercourse crossing the plain. It gives the eye a path into
        // the scene and keeps the middle of the cabinet low in contrast.
        var wash = Path()
        wash.move(to: brush.p(0.415, 0.600))
        wash.addCurve(to: brush.p(0.300, 0.800),
                      control1: brush.p(0.400, 0.670),
                      control2: brush.p(0.318, 0.735))
        wash.addCurve(to: brush.p(0.360, 1.04),
                      control1: brush.p(0.282, 0.878),
                      control2: brush.p(0.318, 0.962))
        wash.addLine(to: brush.p(0.640, 1.04))
        wash.addCurve(to: brush.p(0.560, 0.795),
                      control1: brush.p(0.612, 0.948),
                      control2: brush.p(0.566, 0.872))
        wash.addCurve(to: brush.p(0.500, 0.600),
                      control1: brush.p(0.552, 0.720),
                      control2: brush.p(0.508, 0.658))
        wash.closeSubpath()
        context.fill(wash, with: .linearGradient(
            Gradient(colors: [Color(red: 0.90, green: 0.80, blue: 0.58).opacity(0.55),
                              Color(red: 0.80, green: 0.66, blue: 0.42).opacity(0.72)]),
            startPoint: brush.p(0.45, 0.60),
            endPoint: brush.p(0.5, 1)))
        context.stroke(wash, with: .color(earthDeep.opacity(0.20)), style: brush.stroke(brush.lw(1.2)))

        // The bed is braided with pale sand bars, not with parallel lines:
        // long even strokes down the middle of a channel read as tyre tracks.
        let bars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.418, 0.690, 0.052, 0.060), (0.492, 0.760, 0.070, 0.048),
            (0.398, 0.858, 0.058, 0.070), (0.520, 0.900, 0.062, 0.055),
            (0.452, 0.985, 0.080, 0.050)
        ]
        for (index, bar) in bars.enumerated() {
            var sandBar = Path()
            sandBar.move(to: brush.p(bar.0 - bar.2 * 0.5, bar.1))
            sandBar.addQuadCurve(to: brush.p(bar.0 + bar.2 * 0.5, bar.1 - bar.3 * 0.18),
                                 control: brush.p(bar.0, bar.1 - bar.3 * 0.62))
            sandBar.addQuadCurve(to: brush.p(bar.0 - bar.2 * 0.5, bar.1),
                                 control: brush.p(bar.0 + habitatNoise(index, 61, -0.01, 0.01),
                                                  bar.1 + bar.3 * 0.38))
            sandBar.closeSubpath()
            context.fill(sandBar,
                         with: .color(Color(red: 0.93, green: 0.85, blue: 0.66)
                            .opacity(0.42 + habitatNoise(index, 62, 0, 0.16))))
            context.stroke(sandBar,
                           with: .color(Color(red: 0.66, green: 0.53, blue: 0.33).opacity(0.20)),
                           style: brush.stroke(brush.lw(0.7)))
        }

        // Short scour marks between the bars, all pointing downstream but each
        // one different in length and curve.
        for index in 0..<9 {
            let x = 0.400 + habitatNoise(index, 63, 0, 0.210)
            let y = 0.640 + habitatNoise(index, 64, 0, 0.360)
            let length = habitatNoise(index, 65, 0.030, 0.075)
            var scour = Path()
            scour.move(to: brush.p(x, y))
            scour.addQuadCurve(to: brush.p(x + habitatNoise(index, 66, -0.012, 0.020), y + length),
                               control: brush.p(x - 0.010, y + length * 0.5))
            context.stroke(scour,
                           with: .color(Color(red: 0.64, green: 0.51, blue: 0.31).opacity(0.22)),
                           style: brush.stroke(brush.lw(0.8)))
        }
        brush.pebbleBeds(in: &context,
                         bounds: brush.box(0.450, 0.860, 0.30, 0.280),
                         color: Color(red: 0.60, green: 0.52, blue: 0.40),
                         highlight: Color(red: 0.88, green: 0.82, blue: 0.68),
                         clusters: 14,
                         seed: 500)
    }

    private func paintTermiteMound(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A weathered mound on the left horizon line, with its own small shade
        // bush. Real savanna landmarks, not abstract decoration.
        let base = brush.p(0.115, 0.688)
        let height = brush.ry(0.185)
        let width = brush.rx(0.115)

        brush.contactShadow(in: &context,
                            center: CGPoint(x: base.x + width * 0.18, y: base.y + brush.ry(0.006)),
                            width: width * 2.3,
                            height: brush.ry(0.026),
                            opacity: 0.28)

        var mound = Path()
        mound.move(to: CGPoint(x: base.x - width, y: base.y))
        mound.addCurve(to: CGPoint(x: base.x - width * 0.18, y: base.y - height),
                       control1: CGPoint(x: base.x - width * 0.84, y: base.y - height * 0.34),
                       control2: CGPoint(x: base.x - width * 0.46, y: base.y - height * 0.72))
        mound.addCurve(to: CGPoint(x: base.x + width * 0.30, y: base.y - height * 0.72),
                       control1: CGPoint(x: base.x + width * 0.02, y: base.y - height * 1.06),
                       control2: CGPoint(x: base.x + width * 0.20, y: base.y - height * 0.92))
        mound.addCurve(to: CGPoint(x: base.x + width, y: base.y),
                       control1: CGPoint(x: base.x + width * 0.52, y: base.y - height * 0.44),
                       control2: CGPoint(x: base.x + width * 0.78, y: base.y - height * 0.20))
        mound.closeSubpath()
        context.fill(mound, with: .linearGradient(
            Gradient(colors: [Color(red: 0.76, green: 0.55, blue: 0.32),
                              earth,
                              earthDeep]),
            startPoint: CGPoint(x: base.x - width, y: base.y - height),
            endPoint: CGPoint(x: base.x + width, y: base.y)))

        // The shaded flank is a single soft mass rather than a set of lines;
        // evenly spaced runnels converging on the crown made the mound read as
        // a tipi with poles.
        var shade = Path()
        shade.move(to: CGPoint(x: base.x - width * 0.18, y: base.y - height))
        shade.addCurve(to: CGPoint(x: base.x + width, y: base.y),
                       control1: CGPoint(x: base.x + width * 0.30, y: base.y - height * 0.78),
                       control2: CGPoint(x: base.x + width * 0.80, y: base.y - height * 0.22))
        shade.addLine(to: CGPoint(x: base.x + width * 0.10, y: base.y))
        shade.addCurve(to: CGPoint(x: base.x - width * 0.18, y: base.y - height),
                       control1: CGPoint(x: base.x + width * 0.02, y: base.y - height * 0.42),
                       control2: CGPoint(x: base.x - width * 0.10, y: base.y - height * 0.74))
        shade.closeSubpath()
        context.fill(shade, with: .linearGradient(
            Gradient(colors: [earthDeep.opacity(0.34), earthDeep.opacity(0.08)]),
            startPoint: CGPoint(x: base.x + width, y: base.y),
            endPoint: CGPoint(x: base.x - width * 0.10, y: base.y)))

        // A handful of erosion scars, unevenly placed and only running part of
        // the way down, the way rain actually cuts a mound.
        for index in 0..<5 {
            let start = habitatNoise(index, 47, -0.62, 0.62)
            let top = habitatNoise(index, 48, 0.42, 0.86)
            let drift = habitatNoise(index, 49, -0.18, 0.22)
            let bottom = habitatNoise(index, 50, 0.02, 0.34)
            let flank = 1 - abs(start) * 0.55
            var scar = Path()
            scar.move(to: CGPoint(x: base.x + start * width * flank, y: base.y - height * top))
            scar.addQuadCurve(to: CGPoint(x: base.x + (start + drift) * width,
                                          y: base.y - height * bottom),
                              control: CGPoint(x: base.x + (start + drift * 0.3) * width,
                                               y: base.y - height * (top + bottom) * 0.5))
            context.stroke(scar,
                           with: .color(index.isMultiple(of: 3)
                                        ? Color(red: 0.86, green: 0.68, blue: 0.42).opacity(0.26)
                                        : earthDeep.opacity(0.24)),
                           style: brush.stroke(brush.lw(1.0)))
        }

        // Small chimney spires on the crown.
        for index in 0..<3 {
            var spire = Path()
            let x = base.x - width * 0.30 + CGFloat(index) * width * 0.26
            let top = base.y - height * (1.02 + habitatNoise(index, 51, 0, 0.14))
            spire.move(to: CGPoint(x: x - width * 0.09, y: base.y - height * 0.80))
            spire.addQuadCurve(to: CGPoint(x: x, y: top),
                               control: CGPoint(x: x - width * 0.05, y: base.y - height * 0.94))
            spire.addQuadCurve(to: CGPoint(x: x + width * 0.09, y: base.y - height * 0.80),
                               control: CGPoint(x: x + width * 0.05, y: base.y - height * 0.94))
            spire.closeSubpath()
            context.fill(spire, with: .color(Color(red: 0.70, green: 0.50, blue: 0.28)))
        }
    }

    private func paintKopje(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // The lion's lookout: stacked granite boulders on the right, rising
        // out of the plain and taking that whole edge of the frame.
        brush.contactShadow(in: &context,
                            center: brush.p(0.845, 0.795),
                            width: brush.rx(0.62),
                            height: brush.ry(0.055),
                            opacity: 0.32)

        var mass = Path()
        mass.move(to: brush.p(0.598, 0.788))
        mass.addCurve(to: brush.p(0.700, 0.612),
                      control1: brush.p(0.606, 0.712),
                      control2: brush.p(0.640, 0.640))
        mass.addCurve(to: brush.p(0.836, 0.520),
                      control1: brush.p(0.744, 0.590),
                      control2: brush.p(0.784, 0.528))
        mass.addCurve(to: brush.p(1.02, 0.596),
                      control1: brush.p(0.912, 0.514),
                      control2: brush.p(0.970, 0.548))
        mass.addLine(to: brush.p(1.02, 0.800))
        mass.closeSubpath()
        context.fill(mass, with: .linearGradient(
            Gradient(colors: [Color(red: 0.72, green: 0.66, blue: 0.58), rock, rockShade]),
            startPoint: brush.p(0.70, 0.52),
            endPoint: brush.p(0.95, 0.80)))

        // Individual boulders read as separate stones stacked on the mass.
        let boulders: [(CGFloat, CGFloat, CGFloat, CGFloat, Int)] = [
            (0.836, 0.556, 0.115, 0.070, 3),
            (0.930, 0.610, 0.100, 0.062, 7),
            (0.742, 0.648, 0.098, 0.058, 11),
            (0.878, 0.688, 0.130, 0.076, 15),
            (0.672, 0.722, 0.090, 0.050, 19),
            (0.780, 0.756, 0.140, 0.070, 23),
            (0.972, 0.744, 0.110, 0.062, 27)
        ]
        for boulder in boulders {
            brush.rock(in: &context,
                       center: brush.p(boulder.0, boulder.1),
                       radius: brush.rx(boulder.2 * 0.5),
                       light: Color(red: 0.80, green: 0.74, blue: 0.66),
                       dark: rockShade,
                       seed: 600 &+ boulder.4,
                       flatten: 0.82,
                       seated: false)
        }

        // Weathering cracks and lichen blotches over the stack.
        for index in 0..<12 {
            let start = brush.p(habitatNoise(index, 61, 0.63, 1.00),
                                habitatNoise(index, 62, 0.545, 0.780))
            var crack = Path()
            crack.move(to: start)
            crack.addQuadCurve(to: CGPoint(x: start.x + brush.rx(habitatNoise(index, 63, -0.040, 0.040)),
                                           y: start.y + brush.ry(habitatNoise(index, 64, 0.020, 0.060))),
                               control: CGPoint(x: start.x + brush.rx(habitatNoise(index, 65, -0.020, 0.020)),
                                                y: start.y + brush.ry(0.018)))
            context.stroke(crack,
                           with: .color(Color.black.opacity(0.22)),
                           style: brush.stroke(brush.lw(1.1)))
        }
        for index in 0..<14 {
            let point = brush.p(habitatNoise(index, 71, 0.63, 1.00),
                                habitatNoise(index, 72, 0.535, 0.775))
            let radius = brush.rx(habitatNoise(index, 73, 0.008, 0.022))
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius * 0.7,
                                                width: radius * 2, height: radius * 1.4)),
                         with: .color(index.isMultiple(of: 3)
                                      ? Color(red: 0.72, green: 0.72, blue: 0.42).opacity(0.26)
                                      : Color(red: 0.86, green: 0.66, blue: 0.34).opacity(0.20)))
        }

        // A fig rooted in a crevice, the way kopjes always carry one.
        var figTrunk = Path()
        figTrunk.move(to: brush.p(0.905, 0.600))
        figTrunk.addCurve(to: brush.p(0.938, 0.470),
                          control1: brush.p(0.898, 0.556),
                          control2: brush.p(0.924, 0.512))
        context.stroke(figTrunk,
                       with: .color(Color(red: 0.68, green: 0.62, blue: 0.50)),
                       style: brush.stroke(brush.rx(0.016)))
        for index in 0..<3 {
            var root = Path()
            root.move(to: brush.p(0.905, 0.600))
            root.addQuadCurve(to: brush.p(0.858 + CGFloat(index) * 0.048, 0.690),
                              control: brush.p(0.880 + CGFloat(index) * 0.030, 0.640))
            context.stroke(root,
                           with: .color(Color(red: 0.66, green: 0.60, blue: 0.48).opacity(0.85)),
                           style: brush.stroke(brush.lw(2.0)))
        }
        for (index, mass) in [(0.905, 0.432, 0.130, 0.070),
                              (0.985, 0.462, 0.115, 0.062),
                              (0.852, 0.478, 0.100, 0.055)].enumerated() {
            brush.crown(in: &context,
                        center: brush.p(mass.0, mass.1),
                        width: brush.rx(mass.2),
                        height: brush.ry(mass.3),
                        colors: [foliageLight, foliage, Color(red: 0.20, green: 0.28, blue: 0.13)],
                        seed: 700 &+ index &* 9,
                        lobes: 5)
        }
    }

    private func paintScrub(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Thorn bushes at the foot of the kopje and out on the plain.
        let bushes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.632, 0.792, 0.130, 0.062),
            (0.560, 0.700, 0.090, 0.042),
            (0.256, 0.716, 0.105, 0.048),
            (0.038, 0.760, 0.120, 0.056)
        ]
        for (index, bush) in bushes.enumerated() {
            let center = brush.p(bush.0, bush.1)
            brush.contactShadow(in: &context,
                                center: CGPoint(x: center.x, y: center.y + brush.ry(bush.3 * 0.5)),
                                width: brush.rx(bush.2 * 1.5),
                                height: brush.ry(bush.3 * 0.42),
                                opacity: 0.24)
            brush.crown(in: &context,
                        center: center,
                        width: brush.rx(bush.2),
                        height: brush.ry(bush.3),
                        colors: [Color(red: 0.46, green: 0.46, blue: 0.22),
                                 Color(red: 0.32, green: 0.34, blue: 0.16),
                                 Color(red: 0.22, green: 0.24, blue: 0.12)],
                        seed: 800 &+ index &* 11,
                        lobes: 6)
            // Bare thorn twigs. They grow up out of a stem near the base
            // instead of radiating from the centre, which is what turned the
            // earlier version into a sea urchin.
            let stem = CGPoint(x: center.x + brush.rx(bush.2 * 0.06),
                               y: center.y + brush.ry(bush.3 * 0.42))
            for twig in 0..<6 {
                let lean = habitatNoise(index &* 7 &+ twig, 71, -1.05, 1.05)
                let reach = habitatNoise(index &* 7 &+ twig, 72, 0.55, 1.10)
                let tip = CGPoint(x: stem.x + CGFloat(sin(lean)) * brush.rx(bush.2 * 0.72) * reach,
                                  y: stem.y - CGFloat(cos(lean)) * brush.ry(bush.3 * 1.35) * reach)
                var branch = Path()
                branch.move(to: stem)
                branch.addQuadCurve(to: tip,
                                    control: CGPoint(x: (stem.x + tip.x) * 0.5 - brush.rx(bush.2 * 0.06),
                                                     y: (stem.y + tip.y) * 0.5))
                context.stroke(branch,
                               with: .color(Color(red: 0.42, green: 0.34, blue: 0.20).opacity(0.50)),
                               style: brush.stroke(brush.lw(twig.isMultiple(of: 2) ? 1.0 : 0.7)))
            }
        }

        // Aloes: rosettes of thick leaves with a red flower spike.
        for index in 0..<3 {
            let base = brush.p([CGFloat(0.196), 0.700, 0.905][index],
                               [CGFloat(0.905), 0.660, 0.828][index])
            let radius = brush.rx(index == 0 ? 0.052 : 0.036)
            brush.contactShadow(in: &context, center: base,
                                width: radius * 2.4, height: radius * 0.6, opacity: 0.24)
            for leafIndex in 0..<9 {
                let angle = Double(leafIndex) / 9 * 2 * .pi - .pi / 2
                brush.leaf(in: &context,
                           center: CGPoint(x: base.x + CGFloat(cos(angle)) * radius * 0.5,
                                           y: base.y + CGFloat(sin(angle)) * radius * 0.32 - radius * 0.16),
                           length: radius * 1.5,
                           angle: angle,
                           color: leafIndex.isMultiple(of: 2)
                                ? Color(red: 0.42, green: 0.55, blue: 0.36)
                                : Color(red: 0.31, green: 0.44, blue: 0.28),
                           vein: 0.10)
            }
            var spike = Path()
            spike.move(to: CGPoint(x: base.x, y: base.y - radius * 0.3))
            spike.addQuadCurve(to: CGPoint(x: base.x + radius * 0.2, y: base.y - radius * 2.1),
                               control: CGPoint(x: base.x - radius * 0.1, y: base.y - radius * 1.2))
            context.stroke(spike,
                           with: .color(Color(red: 0.36, green: 0.46, blue: 0.28)),
                           style: brush.stroke(brush.lw(1.4)))
            context.fill(Path(ellipseIn: CGRect(x: base.x + radius * 0.05, y: base.y - radius * 2.5,
                                                width: radius * 0.34, height: radius * 0.75)),
                         with: .color(Color(red: 0.90, green: 0.36, blue: 0.18)))
        }
    }

    private func paintAcacia(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // The umbrella acacia leaning in from the left. Its canopy closes the
        // top of the frame and casts the shade the plain is missing.
        var trunk = Path()
        trunk.move(to: brush.p(-0.06, 0.840))
        trunk.addCurve(to: brush.p(0.128, 0.395),
                       control1: brush.p(0.028, 0.760),
                       control2: brush.p(0.086, 0.560))
        context.stroke(trunk,
                       with: .linearGradient(Gradient(colors: [bark, barkLight]),
                                             startPoint: brush.p(0.0, 0.8),
                                             endPoint: brush.p(0.16, 0.4)),
                       style: brush.stroke(brush.rx(0.052)))

        // Bark fissures run the length of the trunk. Short evenly spaced marks
        // across the lean read as the rungs of a ladder.
        for index in 0..<5 {
            let lateral = habitatNoise(index, 81, -0.016, 0.016)
            let from = habitatNoise(index, 82, 0.00, 0.30)
            let to = habitatNoise(index, 83, 0.55, 0.98)
            func trunkPoint(_ t: CGFloat, _ offset: CGFloat) -> CGPoint {
                brush.p(-0.055 + t * 0.185 + offset, 0.836 - t * 0.430)
            }
            var fissure = Path()
            fissure.move(to: trunkPoint(from, lateral))
            fissure.addQuadCurve(to: trunkPoint(to, lateral * 0.5),
                                 control: trunkPoint((from + to) * 0.5, lateral * 1.4))
            context.stroke(fissure,
                           with: .color(index.isMultiple(of: 2)
                                        ? Color.black.opacity(0.18)
                                        : Color.white.opacity(0.10)),
                           style: brush.stroke(brush.lw(1.0)))
        }

        // Branch structure: limbs that fork off the trunk at different heights
        // and taper, rather than four equal bars leaving the same point.
        let limbs: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.122, 0.430, 0.400, 0.292, -0.045, 0.017),
            (0.126, 0.408, 0.048, 0.246, 0.030, 0.013),
            (0.112, 0.470, 0.298, 0.368, -0.028, 0.015),
            (0.128, 0.392, 0.232, 0.238, -0.038, 0.011)
        ]
        for limb in limbs {
            let start = brush.p(limb.0, limb.1)
            let end = brush.p(limb.2, limb.3)
            let control = brush.p((limb.0 + limb.2) * 0.5, (limb.1 + limb.3) * 0.5 + limb.4)
            let thick = brush.rx(limb.5)
            let normal = CGVector(dx: -(end.y - start.y), dy: end.x - start.x)
            let length = max(1, hypot(normal.dx, normal.dy))
            let unit = CGVector(dx: normal.dx / length, dy: normal.dy / length)
            var branch = Path()
            branch.move(to: CGPoint(x: start.x - unit.dx * thick * 0.5,
                                    y: start.y - unit.dy * thick * 0.5))
            branch.addQuadCurve(to: end, control: CGPoint(x: control.x - unit.dx * thick * 0.4,
                                                          y: control.y - unit.dy * thick * 0.4))
            branch.addQuadCurve(to: CGPoint(x: start.x + unit.dx * thick * 0.5,
                                            y: start.y + unit.dy * thick * 0.5),
                                control: CGPoint(x: control.x + unit.dx * thick * 0.4,
                                                 y: control.y + unit.dy * thick * 0.4))
            branch.closeSubpath()
            context.fill(branch, with: .color(barkLight.opacity(0.92)))

            // One fork per limb, so the crown is carried by real structure.
            var fork = Path()
            let forkBase = CGPoint(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5 + brush.ry(limb.4 * 0.4))
            fork.move(to: forkBase)
            fork.addQuadCurve(to: CGPoint(x: forkBase.x + (end.x - start.x) * 0.28,
                                          y: forkBase.y - brush.ry(0.055)),
                              control: CGPoint(x: forkBase.x + (end.x - start.x) * 0.10,
                                               y: forkBase.y - brush.ry(0.020)))
            context.stroke(fork,
                           with: .color(barkLight.opacity(0.80)),
                           style: brush.stroke(thick * 0.42))
        }

        // The flat canopy itself: overlapping soft slabs, not a single blob.
        let canopy: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.155, 0.250, 0.44, 0.115, 0.0),
            (0.330, 0.212, 0.40, 0.105, 0.0),
            (0.062, 0.315, 0.32, 0.090, 0.0),
            (0.255, 0.150, 0.34, 0.088, 0.0),
            (0.430, 0.278, 0.26, 0.070, 0.0)
        ]
        for (index, slab) in canopy.enumerated() {
            let center = brush.p(slab.0, slab.1)
            let halfWidth = brush.rx(slab.2 * 0.5)
            let halfHeight = brush.ry(slab.3 * 0.5)
            var shape = Path()
            shape.move(to: CGPoint(x: center.x - halfWidth, y: center.y + halfHeight * 0.55))
            shape.addCurve(to: CGPoint(x: center.x + halfWidth, y: center.y + halfHeight * 0.50),
                           control1: CGPoint(x: center.x - halfWidth * 0.55, y: center.y - halfHeight * 1.35),
                           control2: CGPoint(x: center.x + halfWidth * 0.60, y: center.y - halfHeight * 1.30))
            shape.addQuadCurve(to: CGPoint(x: center.x - halfWidth, y: center.y + halfHeight * 0.55),
                               control: CGPoint(x: center.x, y: center.y + halfHeight * 1.30))
            shape.closeSubpath()
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [foliageLight, foliage, Color(red: 0.19, green: 0.26, blue: 0.12)]),
                startPoint: CGPoint(x: center.x - halfWidth, y: center.y - halfHeight),
                endPoint: CGPoint(x: center.x + halfWidth * 0.4, y: center.y + halfHeight)))

            // Leaflet clumps along the sunlit upper edge.
            for clump in 0..<9 {
                let t = CGFloat(clump) / 8
                let point = CGPoint(x: center.x - halfWidth + t * halfWidth * 2,
                                    y: center.y - halfHeight * (0.55 - abs(t - 0.5) * 0.9))
                let radius = brush.rx(habitatNoise(index &* 20 &+ clump, 81, 0.014, 0.030))
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius * 0.6,
                                                    width: radius * 2, height: radius * 1.2)),
                             with: .color(foliageLight.opacity(0.55)))
            }
        }

        // Seed pods hanging from the underside of the canopy slabs.
        for (index, slab) in canopy.enumerated() {
            for pod in 0..<2 {
                let t = habitatNoise(index &* 5 &+ pod, 91, -0.32, 0.32)
                let anchor = brush.p(slab.0 + t * slab.2 * 0.42, slab.1 + slab.3 * 0.42)
                var hang = Path()
                hang.move(to: anchor)
                hang.addQuadCurve(to: CGPoint(x: anchor.x + brush.rx(habitatNoise(index &* 5 &+ pod, 93, -0.010, 0.010)),
                                              y: anchor.y + brush.ry(0.038)),
                                  control: CGPoint(x: anchor.x + brush.rx(0.008), y: anchor.y + brush.ry(0.016)))
                context.stroke(hang,
                               with: .color(Color(red: 0.56, green: 0.42, blue: 0.22).opacity(0.80)),
                               style: brush.stroke(brush.lw(1.6)))
            }
        }
    }

    private func paintDeadwood(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A sun-bleached fallen limb across the near right. Weathered grey
        // wood is the natural companion to dry grass and granite.
        brush.log(in: &context,
                  from: brush.p(0.575, 0.905),
                  to: brush.p(0.985, 0.862),
                  thickness: brush.ry(0.052),
                  bark: Color(red: 0.60, green: 0.55, blue: 0.46),
                  barkLight: Color(red: 0.82, green: 0.78, blue: 0.68),
                  core: Color(red: 0.72, green: 0.64, blue: 0.50))

        for index in 0..<3 {
            let root = brush.p(0.600 + CGFloat(index) * 0.030, 0.898)
            var stub = Path()
            stub.move(to: root)
            stub.addQuadCurve(to: CGPoint(x: root.x - brush.rx(0.055 - CGFloat(index) * 0.012),
                                          y: root.y - brush.ry(0.070 + CGFloat(index) * 0.020)),
                              control: CGPoint(x: root.x - brush.rx(0.020), y: root.y - brush.ry(0.045)))
            context.stroke(stub,
                           with: .color(Color(red: 0.70, green: 0.65, blue: 0.55)),
                           style: brush.stroke(brush.lw(3.0)))
        }
    }

    private func paintForeground(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Tall bleached tussocks cropping the bottom edge.
        for index in 0..<7 {
            brush.grassTuft(in: &context,
                            base: brush.p(-0.01 + CGFloat(index) * 0.046, 1.015),
                            height: brush.ry(0.155 + CGFloat(index % 3) * 0.038),
                            width: brush.rx(0.110),
                            colors: [grassDeep, Color(red: 0.72, green: 0.56, blue: 0.24), grassPale],
                            bladeCount: 12,
                            seed: 1000 &+ index,
                            shadow: 0)
            brush.grassTuft(in: &context,
                            base: brush.p(0.700 + CGFloat(index) * 0.052, 1.020),
                            height: brush.ry(0.165 + CGFloat(index % 3) * 0.034),
                            width: brush.rx(0.115),
                            colors: [grassDeep, Color(red: 0.70, green: 0.54, blue: 0.22), grassPale],
                            bladeCount: 12,
                            seed: 1050 &+ index,
                            shadow: 0)
        }

        // Seed heads on tall stalks, the last thing between viewer and plain.
        for index in 0..<11 {
            let base = brush.p(habitatNoise(index, 101, 0.0, 1.0), 1.005)
            let height = brush.ry(habitatNoise(index, 102, 0.16, 0.28))
            let lean = brush.rx(habitatNoise(index, 103, -0.034, 0.034))
            let tip = CGPoint(x: base.x + lean, y: base.y - height)
            var stalk = Path()
            stalk.move(to: base)
            stalk.addQuadCurve(to: tip, control: CGPoint(x: base.x + lean * 0.2, y: base.y - height * 0.6))
            context.stroke(stalk,
                           with: .color(Color(red: 0.72, green: 0.58, blue: 0.28)),
                           style: brush.stroke(brush.lw(1.1)))
            var head = Path()
            head.move(to: tip)
            head.addQuadCurve(to: CGPoint(x: tip.x + brush.rx(0.006), y: tip.y + height * 0.20),
                              control: CGPoint(x: tip.x + brush.rx(0.014), y: tip.y + height * 0.09))
            head.addQuadCurve(to: tip,
                              control: CGPoint(x: tip.x - brush.rx(0.010), y: tip.y + height * 0.10))
            head.closeSubpath()
            context.fill(head, with: .color(Color(red: 0.90, green: 0.82, blue: 0.54).opacity(0.85)))
        }

        // Two stones and a scatter of gravel to weight the lower left corner.
        brush.rock(in: &context,
                   center: brush.p(0.075, 0.975),
                   radius: brush.rx(0.075),
                   light: Color(red: 0.82, green: 0.76, blue: 0.68),
                   dark: rockShade,
                   seed: 1100,
                   flatten: 0.62)
        brush.rock(in: &context,
                   center: brush.p(0.192, 1.005),
                   radius: brush.rx(0.060),
                   light: Color(red: 0.76, green: 0.70, blue: 0.62),
                   dark: rockShade,
                   seed: 1120,
                   flatten: 0.58)
        brush.pebbleBeds(in: &context,
                         bounds: brush.box(0.120, 0.975, 0.34, 0.090),
                         color: Color(red: 0.52, green: 0.45, blue: 0.35),
                         highlight: Color(red: 0.86, green: 0.79, blue: 0.64),
                         clusters: 9,
                         seed: 1140)
    }

    private func paintHeatWash(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A warm veil over the far plain so the horizon dissolves into the
        // haze rather than ending on a hard line.
        // The veil fades in as well as out. Starting it at full strength put a
        // visible horizontal seam across the plain.
        var veil = Path()
        veil.move(to: brush.p(-0.02, 0.505))
        veil.addLine(to: brush.p(1.02, 0.505))
        veil.addLine(to: brush.p(1.02, 0.735))
        veil.addLine(to: brush.p(-0.02, 0.735))
        veil.closeSubpath()
        let warm = Color(red: 1.0, green: 0.90, blue: 0.66)
        context.fill(veil, with: .linearGradient(
            Gradient(stops: [.init(color: .clear, location: 0.0),
                             .init(color: warm.opacity(0.26), location: 0.34),
                             .init(color: warm.opacity(0.16), location: 0.62),
                             .init(color: .clear, location: 1.0)]),
            startPoint: brush.p(0.5, 0.505),
            endPoint: brush.p(0.5, 0.735)))
    }
}
