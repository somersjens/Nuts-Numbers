//
//  FrogPondHabitat.swift
//  Nuts & Numbers
//
//  Early-morning marsh. Mist over a still pond, cattails closing both sides,
//  willows hanging into the top of the frame and a weathered jetty on the
//  right. The open water in the middle is the quiet zone.
//

import SwiftUI

struct FrogPondHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let skyTop = Color(red: 0.50, green: 0.74, blue: 0.80)
    private let skyLow = Color(red: 0.95, green: 0.90, blue: 0.68)
    private let willowDark = Color(red: 0.19, green: 0.34, blue: 0.23)
    private let willowMid = Color(red: 0.29, green: 0.47, blue: 0.25)
    private let willowLight = Color(red: 0.48, green: 0.64, blue: 0.28)
    private let reedGreen = Color(red: 0.34, green: 0.50, blue: 0.21)
    private let reedLight = Color(red: 0.60, green: 0.69, blue: 0.29)
    private let cattail = Color(red: 0.44, green: 0.27, blue: 0.12)
    private let waterTop = Color(red: 0.52, green: 0.68, blue: 0.62)
    private let waterMid = Color(red: 0.19, green: 0.41, blue: 0.42)
    private let waterDeep = Color(red: 0.07, green: 0.21, blue: 0.25)
    private let padGreen = Color(red: 0.25, green: 0.51, blue: 0.24)
    private let padRim = Color(red: 0.42, green: 0.63, blue: 0.25)
    private let mud = Color(red: 0.27, green: 0.23, blue: 0.15)
    private let wood = Color(red: 0.52, green: 0.42, blue: 0.29)
    private let woodLight = Color(red: 0.72, green: 0.62, blue: 0.46)
    private let woodDeep = Color(red: 0.28, green: 0.21, blue: 0.14)

    var body: some View {
        Canvas { context, size in
            let brush = HabitatBrush(size: size, isPad: isPad)
            paintSky(brush, in: &context)
            paintFarBank(brush, in: &context)
            paintDistantTrees(brush, in: &context)
            paintWater(brush, in: &context)
            paintReflections(brush, in: &context)
            paintDuckweed(brush, in: &context)
            paintSunkenLog(brush, in: &context)
            paintJetty(brush, in: &context)
            paintLilyPads(brush, in: &context)
            paintCattailStands(brush, in: &context)
            paintWillowCanopy(brush, in: &context)
            paintNearBank(brush, in: &context)
        }
        .overlay {
            LinearGradient(colors: [.white.opacity(0.075),
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
                            .init(color: Color(red: 0.74, green: 0.86, blue: 0.80), location: 0.26),
                            .init(color: skyLow, location: 0.46)
                        ]),
                        startPoint: brush.p(0.4, 0),
                        endPoint: brush.p(0.6, 0.50)))

        brush.sun(in: &context,
                  center: brush.p(0.30, 0.245),
                  radius: brush.rx(0.062),
                  core: Color(red: 1.0, green: 0.97, blue: 0.82).opacity(0.58),
                  glow: Color(red: 1.0, green: 0.92, blue: 0.62).opacity(0.30),
                  glowSpread: 4.0)

        for (index, cloud) in [(0.16, 0.105, 0.30, 0.040),
                               (0.66, 0.140, 0.26, 0.034),
                               (0.92, 0.085, 0.22, 0.030)].enumerated() {
            brush.cloud(in: &context,
                        center: brush.p(cloud.0, cloud.1),
                        width: brush.rx(cloud.2),
                        height: brush.ry(cloud.3),
                        color: Color.white.opacity(0.62),
                        shade: Color(red: 0.86, green: 0.88, blue: 0.86).opacity(0.45),
                        seed: index &* 19)
        }
    }

    private func paintDistantTrees(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Shoreline willows sit in the far bank. Crowns overlap the soil line
        // so nothing reads as a floating ball of leaves in the sky.
        brush.hazeBand(in: &context, top: 0.400, bottom: 0.495, color: Color.white.opacity(0.22))
        let trees: [(CGFloat, CGFloat, CGFloat)] = [
            (0.03, 0.512, 0.095), (0.13, 0.516, 0.072), (0.235, 0.510, 0.088),
            (0.345, 0.518, 0.060), (0.455, 0.514, 0.078), (0.575, 0.516, 0.058),
            (0.695, 0.508, 0.090), (0.815, 0.514, 0.068), (0.925, 0.510, 0.092)
        ]
        for (index, tree) in trees.enumerated() {
            let base = brush.p(tree.0, tree.1 + 0.012)
            brush.trunk(in: &context,
                        base: base,
                        top: CGPoint(x: base.x + brush.rx(habitatNoise(index, 8, -0.006, 0.006)),
                                     y: base.y - brush.ry(tree.2 * 0.55)),
                        baseWidth: brush.rx(0.018 + tree.2 * 0.06),
                        topWidth: brush.rx(0.007),
                        bark: willowDark.opacity(0.85),
                        barkLight: Color(red: 0.36, green: 0.30, blue: 0.20).opacity(0.80),
                        grain: 2,
                        seed: 100 &+ index &* 7)
            brush.crown(in: &context,
                        center: brush.p(tree.0, tree.1 - tree.2 * 0.18),
                        width: brush.rx(tree.2 * 1.15),
                        height: brush.ry(tree.2 * 0.95),
                        colors: [willowMid.opacity(0.82),
                                 willowLight.opacity(0.70),
                                 willowDark.opacity(0.78)],
                        seed: 100 &+ index &* 7,
                        lobes: 5)
        }
    }

    private func paintFarBank(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var bank = Path()
        bank.move(to: brush.p(0, 0.500))
        bank.addCurve(to: brush.p(0.46, 0.516),
                      control1: brush.p(0.14, 0.492),
                      control2: brush.p(0.30, 0.522))
        bank.addCurve(to: brush.p(1, 0.498),
                      control1: brush.p(0.66, 0.510),
                      control2: brush.p(0.84, 0.520))
        bank.addLine(to: brush.p(1, 0.560))
        bank.addLine(to: brush.p(0, 0.560))
        bank.closeSubpath()
        context.fill(bank, with: .linearGradient(
            Gradient(colors: [Color(red: 0.42, green: 0.50, blue: 0.28),
                              Color(red: 0.24, green: 0.32, blue: 0.19)]),
            startPoint: brush.p(0.5, 0.495),
            endPoint: brush.p(0.5, 0.555)))

        // Far reed fringe: many small stands so the shoreline never becomes
        // a single flat stripe.
        for index in 0..<26 {
            let x = -0.01 + CGFloat(index) / 25 * 1.02 + habitatNoise(index, 3, -0.012, 0.012)
            brush.reedStand(in: &context,
                            base: brush.p(x, 0.536 + habitatNoise(index, 4, -0.003, 0.004)),
                            height: brush.ry(habitatNoise(index, 5, 0.022, 0.042)),
                            spread: brush.rx(0.024),
                            count: 4,
                            stem: reedGreen.opacity(0.72),
                            stemLight: reedLight.opacity(0.66),
                            headColor: index.isMultiple(of: 5) ? cattail.opacity(0.7) : nil,
                            seed: 200 &+ index)
        }
    }

    // MARK: - Water

    private func paintWater(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var pond = Path()
        pond.move(to: brush.p(0, 0.545))
        pond.addQuadCurve(to: brush.p(1, 0.540), control: brush.p(0.5, 0.562))
        pond.addLine(to: brush.p(1, 1))
        pond.addLine(to: brush.p(0, 1))
        pond.closeSubpath()
        context.fill(pond, with: .linearGradient(
            Gradient(stops: [
                .init(color: waterTop, location: 0),
                .init(color: Color(red: 0.32, green: 0.54, blue: 0.50), location: 0.26),
                .init(color: waterMid, location: 0.60),
                .init(color: waterDeep, location: 1)
            ]),
            startPoint: brush.p(0.5, 0.545),
            endPoint: brush.p(0.5, 1)))

        // A pale wedge of reflected sky keeps the middle bright but soft.
        var sheen = Path()
        sheen.move(to: brush.p(0.30, 0.552))
        sheen.addLine(to: brush.p(0.68, 0.552))
        sheen.addQuadCurve(to: brush.p(0.52, 0.905), control: brush.p(0.66, 0.740))
        sheen.addQuadCurve(to: brush.p(0.30, 0.552), control: brush.p(0.30, 0.730))
        sheen.closeSubpath()
        context.fill(sheen, with: .linearGradient(
            Gradient(colors: [Color(red: 0.94, green: 0.92, blue: 0.74).opacity(0.30), .clear]),
            startPoint: brush.p(0.5, 0.55),
            endPoint: brush.p(0.5, 0.92)))
    }

    private func paintReflections(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Vertical smears under the far bank read as reflected reeds; the
        // horizontal breaks stop them from becoming a striped pattern.
        for index in 0..<30 {
            let x = habitatNoise(index, 11, 0.01, 0.99)
            let length = habitatNoise(index, 12, 0.030, 0.085)
            var smear = Path()
            smear.move(to: brush.p(x, 0.552))
            smear.addQuadCurve(to: brush.p(x + habitatNoise(index, 13, -0.010, 0.010), 0.552 + length),
                               control: brush.p(x + habitatNoise(index, 14, -0.014, 0.014), 0.552 + length * 0.5))
            context.stroke(smear,
                           with: .color(willowDark.opacity(habitatNoise(index, 15, 0.10, 0.26))),
                           style: brush.stroke(brush.lw(habitatNoise(index, 16, 1.0, 2.4))))
        }

        brush.waterGlints(in: &context,
                          bounds: CGRect(x: brush.rx(0.06), y: brush.ry(0.60),
                                         width: brush.rx(0.88), height: brush.ry(0.34)),
                          count: 8,
                          color: Color.white.opacity(0.55),
                          seed: 21)
    }

    private func paintDuckweed(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Drifts of tiny floating leaves gather along the edges and in the
        // corners, exactly where still water actually collects them.
        let drifts: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.10, 0.640, 0.30, 0.055), (0.90, 0.690, 0.28, 0.060),
            (0.20, 0.880, 0.36, 0.085), (0.80, 0.945, 0.34, 0.080),
            (0.58, 0.605, 0.20, 0.032)
        ]
        for (index, drift) in drifts.enumerated() {
            brush.groundPatch(in: &context,
                              center: brush.p(drift.0, drift.1),
                              width: brush.rx(drift.2),
                              height: brush.ry(drift.3),
                              color: Color(red: 0.42, green: 0.60, blue: 0.26).opacity(0.34),
                              seed: 300 &+ index &* 9)
            for speck in 0..<16 {
                let point = brush.p(drift.0 + habitatNoise(index &* 40 &+ speck, 17, -0.5, 0.5) * drift.2,
                                    drift.1 + habitatNoise(index &* 40 &+ speck, 18, -0.5, 0.5) * drift.3)
                let radius = brush.rx(habitatNoise(index &* 40 &+ speck, 19, 0.003, 0.007))
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius * 0.7,
                                                    width: radius * 2, height: radius * 1.4)),
                             with: .color(Color(red: 0.52, green: 0.72, blue: 0.30).opacity(0.72)))
            }
        }
    }

    private func paintSunkenLog(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A branch breaking the surface at an angle, half sunk, with the
        // submerged part visibly dimmed by the water.
        let above = brush.p(0.185, 0.700)
        let below = brush.p(0.435, 0.762)
        brush.log(in: &context,
                  from: above,
                  to: below,
                  thickness: brush.ry(0.034),
                  bark: Color(red: 0.34, green: 0.28, blue: 0.19),
                  barkLight: Color(red: 0.58, green: 0.50, blue: 0.34),
                  core: Color(red: 0.70, green: 0.58, blue: 0.36))
        var submerged = Path()
        submerged.move(to: CGPoint(x: brush.rx(0.435), y: brush.ry(0.762)))
        submerged.addLine(to: CGPoint(x: brush.rx(0.575), y: brush.ry(0.800)))
        context.stroke(submerged,
                       with: .color(waterDeep.opacity(0.52)),
                       style: brush.stroke(brush.ry(0.030)))

        // Waterline scum and a few reflections underneath.
        var line = Path()
        line.move(to: CGPoint(x: brush.rx(0.16), y: brush.ry(0.712)))
        line.addQuadCurve(to: CGPoint(x: brush.rx(0.47), y: brush.ry(0.774)),
                          control: CGPoint(x: brush.rx(0.32), y: brush.ry(0.750)))
        context.stroke(line, with: .color(Color.white.opacity(0.30)), style: brush.stroke(brush.lw(1.3)))

        for index in 0..<3 {
            brush.grassTuft(in: &context,
                            base: brush.p(0.225 + CGFloat(index) * 0.055, 0.706 + CGFloat(index) * 0.014),
                            height: brush.ry(0.040),
                            width: brush.rx(0.042),
                            colors: [reedGreen, reedLight],
                            bladeCount: 6,
                            seed: 400 &+ index,
                            shadow: 0)
        }
    }

    private func paintJetty(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A short plank walkway running out of the right bank. Old, uneven and
        // clearly built for standing over the water.
        let posts: [(CGFloat, CGFloat, CGFloat)] = [
            (0.720, 0.790, 0.115), (0.845, 0.735, 0.095), (0.960, 0.695, 0.082)
        ]
        for (index, post) in posts.enumerated() {
            let top = brush.p(post.0, post.1 - post.2)
            let bottom = brush.p(post.0, post.1)
            brush.plank(in: &context,
                        from: top,
                        to: bottom,
                        thickness: brush.rx(0.028),
                        wood: wood,
                        woodLight: woodLight,
                        woodDeep: woodDeep)
            // Waterline stain and a small ripple collar.
            var collar = Path()
            collar.move(to: CGPoint(x: bottom.x - brush.rx(0.038), y: bottom.y - brush.ry(0.006)))
            collar.addQuadCurve(to: CGPoint(x: bottom.x + brush.rx(0.038), y: bottom.y - brush.ry(0.006)),
                                control: CGPoint(x: bottom.x, y: bottom.y + brush.ry(0.010)))
            context.stroke(collar, with: .color(Color.white.opacity(0.34)), style: brush.stroke(brush.lw(1.2)))
            _ = index
        }

        let deckStart = brush.p(0.690, 0.690)
        let deckEnd = brush.p(1.02, 0.598)
        brush.plank(in: &context,
                    from: deckStart,
                    to: deckEnd,
                    thickness: brush.ry(0.030),
                    wood: wood,
                    woodLight: woodLight,
                    woodDeep: woodDeep)
        for index in 0..<7 {
            let t = CGFloat(index) / 6
            let x = deckStart.x + (deckEnd.x - deckStart.x) * t
            let y = deckStart.y + (deckEnd.y - deckStart.y) * t
            var seam = Path()
            seam.move(to: CGPoint(x: x, y: y - brush.ry(0.015)))
            seam.addLine(to: CGPoint(x: x, y: y + brush.ry(0.015)))
            context.stroke(seam, with: .color(woodDeep.opacity(0.55)), style: brush.stroke(brush.lw(0.9)))
        }

        // A coil of old rope on the deck adds a human-scale detail.
        let coilCenter = brush.p(0.905, 0.628)
        for index in 0..<3 {
            let radius = brush.rx(0.016 + CGFloat(index) * 0.007)
            context.stroke(Path(ellipseIn: CGRect(x: coilCenter.x - radius,
                                                  y: coilCenter.y - radius * 0.42,
                                                  width: radius * 2,
                                                  height: radius * 0.84)),
                           with: .color(Color(red: 0.74, green: 0.66, blue: 0.44)),
                           style: brush.stroke(brush.lw(1.5)))
        }
    }

    private func paintLilyPads(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Three clusters: two near the banks and one small, low-contrast group
        // in the middle distance.
        let pads: [(CGFloat, CGFloat, CGFloat, Double, Bool)] = [
            (0.120, 0.780, 0.072, 0.4, true), (0.215, 0.822, 0.058, 2.1, false),
            (0.075, 0.870, 0.086, 1.2, false), (0.255, 0.905, 0.070, 3.0, true),
            (0.760, 0.860, 0.080, 2.6, false), (0.870, 0.905, 0.092, 0.8, true),
            (0.665, 0.928, 0.064, 1.8, false),
            (0.455, 0.640, 0.036, 0.9, false), (0.545, 0.665, 0.030, 2.4, false)
        ]
        for (index, pad) in pads.enumerated() {
            let center = brush.p(pad.0, pad.1)
            let radius = brush.rx(pad.2)
            // The pad's own soft shadow in the water below it.
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.9,
                                                y: center.y - radius * 0.10,
                                                width: radius * 1.8,
                                                height: radius * 0.52)),
                         with: .color(waterDeep.opacity(0.30)))
            brush.lilyPad(in: &context,
                          center: center,
                          radius: radius,
                          color: padGreen,
                          rim: padRim,
                          rotation: pad.3)
            if pad.4 {
                let bloomBase = CGPoint(x: center.x + radius * 0.4, y: center.y - radius * 0.12)
                for petalIndex in 0..<7 {
                    let angle = -Double.pi * 0.92 + Double(petalIndex) * 0.32
                    brush.leaf(in: &context,
                               center: CGPoint(x: bloomBase.x + CGFloat(cos(angle)) * radius * 0.22,
                                               y: bloomBase.y + CGFloat(sin(angle)) * radius * 0.22),
                               length: radius * 0.52,
                               angle: angle,
                               color: index.isMultiple(of: 2)
                                    ? Color(red: 0.98, green: 0.80, blue: 0.86)
                                    : Color(red: 0.98, green: 0.94, blue: 0.86),
                               vein: 0)
                }
                let heart = radius * 0.18
                context.fill(Path(ellipseIn: CGRect(x: bloomBase.x - heart * 0.5,
                                                    y: bloomBase.y - heart * 0.5,
                                                    width: heart,
                                                    height: heart)),
                             with: .color(Color(red: 0.98, green: 0.84, blue: 0.30)))
            }
        }
    }

    // MARK: - Edges

    private func paintCattailStands(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Tall stands closing both sides from the water up past the mid-frame.
        let stands: [(CGFloat, CGFloat, CGFloat, CGFloat, Int)] = [
            (0.020, 0.760, 0.330, 0.130, 11), (0.115, 0.700, 0.255, 0.100, 9),
            (0.190, 0.640, 0.185, 0.075, 7),
            (0.985, 0.735, 0.300, 0.120, 10), (0.895, 0.672, 0.230, 0.095, 8),
            (0.812, 0.618, 0.165, 0.070, 6)
        ]
        for (index, stand) in stands.enumerated() {
            brush.reedStand(in: &context,
                            base: brush.p(stand.0, stand.1),
                            height: brush.ry(stand.2),
                            spread: brush.rx(stand.3),
                            count: stand.4,
                            stem: reedGreen,
                            stemLight: reedLight,
                            headColor: cattail,
                            seed: 500 &+ index &* 13)
            // Broad basal leaves arching out of each clump.
            for leafIndex in 0..<4 {
                let side: CGFloat = leafIndex.isMultiple(of: 2) ? 1 : -1
                brush.frond(in: &context,
                            base: brush.p(stand.0, stand.1),
                            length: brush.ry(stand.2 * 0.55),
                            angle: -.pi / 2 + Double(side) * (0.34 + Double(leafIndex) * 0.10),
                            curl: side * 0.30,
                            color: reedGreen,
                            tipColor: reedLight,
                            leaflets: 0)
            }
        }

        // Mossy boulders where the stands meet the water.
        brush.rock(in: &context, center: brush.p(0.145, 0.790), radius: brush.rx(0.062),
                   light: Color(red: 0.52, green: 0.54, blue: 0.46),
                   dark: Color(red: 0.20, green: 0.24, blue: 0.20), seed: 601)
        brush.rock(in: &context, center: brush.p(0.845, 0.812), radius: brush.rx(0.050),
                   light: Color(red: 0.50, green: 0.52, blue: 0.44),
                   dark: Color(red: 0.18, green: 0.22, blue: 0.19), seed: 602)
        for point in [brush.p(0.145, 0.762), brush.p(0.845, 0.788)] {
            var cushion = Path()
            cushion.move(to: CGPoint(x: point.x - brush.rx(0.036), y: point.y))
            cushion.addQuadCurve(to: CGPoint(x: point.x + brush.rx(0.032), y: point.y - brush.ry(0.004)),
                                 control: CGPoint(x: point.x, y: point.y - brush.ry(0.028)))
            cushion.addQuadCurve(to: CGPoint(x: point.x - brush.rx(0.036), y: point.y),
                                 control: CGPoint(x: point.x, y: point.y + brush.ry(0.008)))
            cushion.closeSubpath()
            context.fill(cushion, with: .color(Color(red: 0.34, green: 0.50, blue: 0.20).opacity(0.80)))
        }
    }

    private func paintWillowCanopy(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Willow boughs entering from both top corners with long drooping
        // strands. They fill the top of the frame without blocking the rope.
        let boughs: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.02, 0.040, 0.16, 0.010, 0.38, 0.070, 0.024),
            (-0.02, 0.180, 0.12, 0.140, 0.26, 0.185, 0.016),
            (1.02, 0.055, 0.84, 0.015, 0.62, 0.080, 0.022),
            (1.02, 0.200, 0.88, 0.160, 0.74, 0.205, 0.015)
        ]
        for bough in boughs {
            var path = Path()
            path.move(to: brush.p(bough.0, bough.1))
            path.addQuadCurve(to: brush.p(bough.4, bough.5), control: brush.p(bough.2, bough.3))
            context.stroke(path,
                           with: .linearGradient(Gradient(colors: [Color(red: 0.34, green: 0.26, blue: 0.16),
                                                                   Color(red: 0.52, green: 0.42, blue: 0.26)]),
                                                 startPoint: brush.p(bough.0, bough.1),
                                                 endPoint: brush.p(bough.4, bough.5)),
                           style: brush.stroke(brush.rx(bough.6)))
        }

        for (boughIndex, bough) in boughs.enumerated() {
            let start = (x: bough.0, y: bough.1)
            let control = (x: bough.2, y: bough.3)
            let end = (x: bough.4, y: bough.5)
            for sample in 0..<6 {
                let t = 0.12 + CGFloat(sample) / 6 * 0.80
                let oneX = start.x + (control.x - start.x) * t
                let oneY = start.y + (control.y - start.y) * t
                let twoX = control.x + (end.x - control.x) * t
                let twoY = control.y + (end.y - control.y) * t
                let x = oneX + (twoX - oneX) * t
                let top = oneY + (twoY - oneY) * t
                let length = habitatNoise(boughIndex &* 10 &+ sample, 32, 0.10, 0.22)
                let drift: CGFloat = bough.0 < 0.5 ? 0.018 : -0.018
                var strand = Path()
                strand.move(to: brush.p(x, top))
                strand.addCurve(to: brush.p(x + drift, top + length),
                                control1: brush.p(x - drift * 0.5, top + length * 0.34),
                                control2: brush.p(x + drift * 1.3, top + length * 0.72))
                context.stroke(strand,
                               with: .color(willowMid.opacity(0.80)),
                               style: brush.stroke(brush.lw(1.3)))
                for leafIndex in 0..<4 {
                    let lt = CGFloat(leafIndex + 1) / 5
                    let point = brush.p(x + drift * lt * lt, top + length * lt)
                    brush.leaf(in: &context,
                               center: point,
                               length: brush.ry(0.024),
                               angle: .pi / 2 + Double(drift) * 6 + Double(leafIndex) * 0.16,
                               color: (leafIndex.isMultiple(of: 2) ? willowLight : willowMid).opacity(0.88),
                               vein: 0)
                }
            }
        }

        // Denser leaf masses right at the top edge hold the corners together.
        for (index, mass) in [(0.04, 0.020, 0.26, 0.13), (0.20, 0.000, 0.22, 0.11),
                              (0.96, 0.025, 0.26, 0.13), (0.80, 0.005, 0.22, 0.11)].enumerated() {
            brush.crown(in: &context,
                        center: brush.p(mass.0, mass.1),
                        width: brush.rx(mass.2),
                        height: brush.ry(mass.3),
                        colors: [willowMid, willowLight, willowDark],
                        seed: 700 &+ index &* 11,
                        lobes: 5)
        }
    }

    private func paintNearBank(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Muddy near shore across the bottom edge, with marsh flowers and a
        // silhouette reed fringe so the lower frame has real depth.
        var shore = Path()
        shore.move(to: brush.p(-0.02, 1.02))
        shore.addCurve(to: brush.p(0.34, 0.952),
                       control1: brush.p(0.06, 0.980),
                       control2: brush.p(0.20, 0.944))
        shore.addCurve(to: brush.p(0.70, 0.968),
                       control1: brush.p(0.46, 0.960),
                       control2: brush.p(0.58, 0.978))
        shore.addCurve(to: brush.p(1.02, 0.940),
                       control1: brush.p(0.82, 0.958),
                       control2: brush.p(0.94, 0.930))
        shore.addLine(to: brush.p(1.02, 1.04))
        shore.closeSubpath()
        context.fill(shore, with: .linearGradient(
            Gradient(colors: [Color(red: 0.36, green: 0.31, blue: 0.20), mud]),
            startPoint: brush.p(0.5, 0.94),
            endPoint: brush.p(0.5, 1.0)))

        for index in 0..<9 {
            brush.rock(in: &context,
                       center: brush.p(habitatNoise(index, 41, 0.03, 0.97),
                                       habitatNoise(index, 42, 0.955, 1.005)),
                       radius: brush.rx(habitatNoise(index, 43, 0.014, 0.032)),
                       light: Color(red: 0.48, green: 0.46, blue: 0.38),
                       dark: Color(red: 0.18, green: 0.18, blue: 0.14),
                       seed: 800 &+ index,
                       flatten: 0.58)
        }

        for index in 0..<7 {
            brush.reedStand(in: &context,
                            base: brush.p(0.03 + CGFloat(index) * 0.055, 1.01),
                            height: brush.ry(habitatNoise(index, 44, 0.10, 0.19)),
                            spread: brush.rx(0.048),
                            count: 5,
                            stem: Color(red: 0.14, green: 0.24, blue: 0.12),
                            stemLight: Color(red: 0.24, green: 0.36, blue: 0.15),
                            headColor: index.isMultiple(of: 3) ? Color(red: 0.26, green: 0.16, blue: 0.08) : nil,
                            seed: 900 &+ index)
            brush.reedStand(in: &context,
                            base: brush.p(0.62 + CGFloat(index) * 0.062, 1.02),
                            height: brush.ry(habitatNoise(index, 45, 0.11, 0.21)),
                            spread: brush.rx(0.052),
                            count: 5,
                            stem: Color(red: 0.13, green: 0.23, blue: 0.12),
                            stemLight: Color(red: 0.23, green: 0.35, blue: 0.15),
                            headColor: index.isMultiple(of: 2) ? Color(red: 0.25, green: 0.15, blue: 0.08) : nil,
                            seed: 950 &+ index)
        }

        // Marsh marigolds along the waterline.
        for index in 0..<5 {
            brush.flower(in: &context,
                         base: brush.p(0.36 + CGFloat(index) * 0.052, 0.985),
                         height: brush.ry(0.052 + CGFloat(index % 2) * 0.012),
                         stem: Color(red: 0.22, green: 0.38, blue: 0.16),
                         petal: Color(red: 0.98, green: 0.82, blue: 0.24),
                         heart: Color(red: 0.85, green: 0.56, blue: 0.12),
                         petals: 6,
                         seed: 1000 &+ index,
                         lean: index.isMultiple(of: 2) ? 0.08 : -0.06)
        }

        // A big near lily pad cropped by the bottom-right corner.
        brush.lilyPad(in: &context,
                      center: brush.p(0.93, 1.005),
                      radius: brush.rx(0.19),
                      color: Color(red: 0.19, green: 0.42, blue: 0.20),
                      rim: Color(red: 0.32, green: 0.52, blue: 0.21),
                      rotation: 2.4)
    }
}
