//
//  DogAgilityHabitat.swift
//  Nuts & Numbers
//
//  A full agility ground: mown competition turf with an A-frame, weave poles,
//  a tunnel, jumps, a tyre and a seesaw laid out in depth, ringed by a fence
//  and a line of bunting on poles that stand in the ring.
//

import SwiftUI

struct DogAgilityHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let skyTop = Color(red: 0.34, green: 0.67, blue: 0.94)
    private let skyLow = Color(red: 0.87, green: 0.94, blue: 0.96)
    private let treeDark = Color(red: 0.18, green: 0.38, blue: 0.23)
    private let treeLight = Color(red: 0.33, green: 0.55, blue: 0.26)
    private let turf = Color(red: 0.36, green: 0.68, blue: 0.28)
    private let turfLight = Color(red: 0.55, green: 0.80, blue: 0.33)
    private let turfDeep = Color(red: 0.19, green: 0.44, blue: 0.19)
    private let equipBlue = Color(red: 0.18, green: 0.45, blue: 0.80)
    private let equipYellow = Color(red: 0.98, green: 0.80, blue: 0.16)
    private let equipRed = Color(red: 0.88, green: 0.24, blue: 0.20)
    private let equipWhite = Color(red: 0.96, green: 0.96, blue: 0.94)
    private let dirt = Color(red: 0.56, green: 0.44, blue: 0.28)
    private let post = Color(red: 0.80, green: 0.78, blue: 0.72)

    var body: some View {
        Canvas { context, size in
            let brush = HabitatBrush(size: size, isPad: isPad)
            paintSky(brush, in: &context)
            paintTreeLine(brush, in: &context)
            paintRingFence(brush, in: &context)
            paintTurf(brush, in: &context)
            paintMownStripes(brush, in: &context)
            paintWornGround(brush, in: &context)
            paintWeavePoles(brush, in: &context)
            paintAFrame(brush, in: &context)
            paintSeesaw(brush, in: &context)
            paintTyreJump(brush, in: &context)
            paintRingDressing(brush, in: &context)
            paintBunting(brush, in: &context)
            paintTunnel(brush, in: &context)
            paintHurdles(brush, in: &context)
            paintForeground(brush, in: &context)
        }
        .overlay {
            LinearGradient(colors: [.white.opacity(0.07),
                                    .clear,
                                    character.deepColor.opacity(0.045)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Background

    private func paintSky(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        context.fill(Path(CGRect(origin: .zero, size: brush.size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: skyTop, location: 0),
                            .init(color: Color(red: 0.62, green: 0.84, blue: 0.96), location: 0.28),
                            .init(color: skyLow, location: 0.50)
                        ]),
                        startPoint: brush.p(0.4, 0),
                        endPoint: brush.p(0.6, 0.54)))

        brush.sun(in: &context,
                  center: brush.p(0.845, 0.175),
                  radius: brush.rx(0.062),
                  core: Color(red: 1.0, green: 0.98, blue: 0.84).opacity(0.72),
                  glow: Color(red: 1.0, green: 0.95, blue: 0.70).opacity(0.30),
                  glowSpread: 3.6)

        for (index, cloud) in [(0.22, 0.130, 0.32, 0.050),
                               (0.58, 0.085, 0.28, 0.042),
                               (0.90, 0.290, 0.26, 0.040),
                               (0.06, 0.320, 0.22, 0.034)].enumerated() {
            brush.cloud(in: &context,
                        center: brush.p(cloud.0, cloud.1),
                        width: brush.rx(cloud.2),
                        height: brush.ry(cloud.3),
                        color: Color.white.opacity(0.90),
                        shade: Color(red: 0.80, green: 0.87, blue: 0.94).opacity(0.68),
                        seed: index &* 21)
        }
    }

    private func paintTreeLine(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var band = Path()
        band.move(to: brush.p(-0.02, 0.545))
        band.addQuadCurve(to: brush.p(1.02, 0.538), control: brush.p(0.5, 0.556))
        band.addLine(to: brush.p(1.02, 0.60))
        band.addLine(to: brush.p(-0.02, 0.60))
        band.closeSubpath()
        context.fill(band, with: .color(treeDark.opacity(0.45)))

        for index in 0..<14 {
            let x = -0.01 + CGFloat(index) / 13 * 1.02 + habitatNoise(index, 3, -0.016, 0.016)
            let height = habitatNoise(index, 4, 0.078, 0.145)
            let baseY: CGFloat = 0.560
            brush.trunk(in: &context,
                        base: brush.p(x, baseY),
                        top: brush.p(x + habitatNoise(index, 8, -0.008, 0.008), baseY - height * 0.48),
                        baseWidth: brush.rx(0.016),
                        topWidth: brush.rx(0.007),
                        bark: Color(red: 0.32, green: 0.24, blue: 0.16).opacity(0.80),
                        barkLight: Color(red: 0.48, green: 0.38, blue: 0.24).opacity(0.72),
                        grain: 2,
                        seed: 100 &+ index)
            brush.crown(in: &context,
                        center: brush.p(x, baseY - height * 0.58),
                        width: brush.rx(height * 1.05),
                        height: brush.ry(height * 0.85),
                        colors: [treeDark.opacity(0.88), treeLight.opacity(0.76), treeDark.opacity(0.80)],
                        seed: 100 &+ index &* 5,
                        lobes: 4)
        }
        brush.hazeBand(in: &context, top: 0.480, bottom: 0.560, color: Color.white.opacity(0.18))
    }

    private func paintRingFence(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Low ring rope on stakes running along the back of the course.
        let baseY: CGFloat = 0.612
        for index in 0..<16 {
            let x = -0.01 + CGFloat(index) / 15 * 1.02
            var stake = Path()
            stake.move(to: brush.p(x, baseY))
            stake.addLine(to: brush.p(x, baseY - 0.042))
            context.stroke(stake, with: .color(post.opacity(0.92)), style: brush.stroke(brush.lw(1.6)))
            brush.contactShadow(in: &context,
                                center: brush.p(x, baseY + 0.002),
                                width: brush.rx(0.020),
                                height: brush.ry(0.010),
                                opacity: 0.22)
        }
        for row in 0..<2 {
            let y = baseY - 0.038 + CGFloat(row) * 0.018
            for index in 0..<15 {
                let x0 = -0.01 + CGFloat(index) / 15 * 1.02
                let x1 = -0.01 + CGFloat(index + 1) / 15 * 1.02
                var rope = Path()
                rope.move(to: brush.p(x0, y))
                rope.addQuadCurve(to: brush.p(x1, y), control: brush.p((x0 + x1) * 0.5, y + 0.006))
                context.stroke(rope,
                               with: .color(row == 0 ? equipWhite.opacity(0.9) : equipBlue.opacity(0.65)),
                               style: brush.stroke(brush.lw(1.1)))
            }
        }
    }

    // MARK: - Turf

    private func paintTurf(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var field = Path()
        field.move(to: brush.p(-0.02, 0.600))
        field.addQuadCurve(to: brush.p(1.02, 0.594), control: brush.p(0.5, 0.616))
        field.addLine(to: brush.p(1.02, 1.04))
        field.addLine(to: brush.p(-0.02, 1.04))
        field.closeSubpath()
        context.fill(field, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.50, green: 0.76, blue: 0.34), location: 0),
                .init(color: turf, location: 0.32),
                .init(color: Color(red: 0.27, green: 0.55, blue: 0.24), location: 0.76),
                .init(color: turfDeep, location: 1)
            ]),
            startPoint: brush.p(0.5, 0.60),
            endPoint: brush.p(0.5, 1)))
    }

    private func paintMownStripes(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Mower bands converging on a vanishing point behind the ring. This
        // single device does most of the work of making the field feel deep.
        let vanish = brush.p(0.50, 0.575)
        for index in 0..<11 {
            guard index.isMultiple(of: 2) else { continue }
            let leftT = CGFloat(index) / 10
            let rightT = CGFloat(index + 1) / 10
            var band = Path()
            band.move(to: vanish)
            band.addLine(to: brush.p(-0.6 + leftT * 2.2, 1.04))
            band.addLine(to: brush.p(-0.6 + rightT * 2.2, 1.04))
            band.closeSubpath()
            context.fill(band, with: .linearGradient(
                Gradient(colors: [turfLight.opacity(0.18), turfLight.opacity(0.30)]),
                startPoint: vanish,
                endPoint: brush.p(0.5, 1)))
        }

        // Fine blade texture on top of the bands.
        for index in 0..<40 {
            let depth = habitatNoise(index, 11)
            let point = brush.p(habitatNoise(index, 12, 0.01, 0.99), 0.620 + depth * depth * 0.37)
            var blade = Path()
            blade.move(to: point)
            blade.addQuadCurve(to: CGPoint(x: point.x + brush.rx(habitatNoise(index, 13, -0.010, 0.010)),
                                           y: point.y - brush.ry(0.010 + depth * 0.020)),
                               control: CGPoint(x: point.x, y: point.y - brush.ry(0.008)))
            context.stroke(blade,
                           with: .color(index.isMultiple(of: 3)
                                        ? turfLight.opacity(0.55)
                                        : turfDeep.opacity(0.38)),
                           style: brush.stroke(brush.lw(0.9)))
        }

        // White boundary line curving across the near field.
        var line = Path()
        line.move(to: brush.p(-0.02, 0.706))
        line.addCurve(to: brush.p(1.02, 0.690),
                      control1: brush.p(0.30, 0.736),
                      control2: brush.p(0.72, 0.660))
        context.stroke(line, with: .color(Color.white.opacity(0.42)), style: brush.stroke(brush.lw(1.8)))
    }

    private func paintWornGround(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Bare patches where dogs land and turn. They are the honest sign of
        // a course that is actually used.
        let patches: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.155, 0.790, 0.22, 0.055), (0.680, 0.760, 0.20, 0.048),
            (0.480, 0.905, 0.30, 0.075), (0.885, 0.930, 0.26, 0.070),
            (0.310, 0.700, 0.16, 0.032)
        ]
        for (index, patch) in patches.enumerated() {
            brush.groundPatch(in: &context,
                              center: brush.p(patch.0, patch.1),
                              width: brush.rx(patch.2),
                              height: brush.ry(patch.3),
                              color: dirt.opacity(0.34),
                              seed: 200 &+ index &* 13)
            brush.groundPatch(in: &context,
                              center: brush.p(patch.0 + 0.02, patch.1 + 0.008),
                              width: brush.rx(patch.2 * 0.55),
                              height: brush.ry(patch.3 * 0.5),
                              color: Color(red: 0.42, green: 0.32, blue: 0.20).opacity(0.30),
                              seed: 250 &+ index &* 13)
        }

        // Paw prints crossing the near turf.
        for index in 0..<7 {
            let t = CGFloat(index) / 6
            let point = brush.p(0.24 + t * 0.30, 0.955 - t * 0.075)
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let pad = brush.rx(0.010)
            context.fill(Path(ellipseIn: CGRect(x: point.x + side * pad - pad,
                                                y: point.y - pad * 0.7,
                                                width: pad * 1.8, height: pad * 1.3)),
                         with: .color(dirt.opacity(0.42)))
            for toe in 0..<3 {
                let angle = -Double.pi * 0.5 + Double(toe - 1) * 0.5
                context.fill(Path(ellipseIn: CGRect(x: point.x + side * pad + CGFloat(cos(angle)) * pad * 1.2 - pad * 0.32,
                                                    y: point.y + CGFloat(sin(angle)) * pad * 0.9 - pad * 0.30,
                                                    width: pad * 0.64, height: pad * 0.56)),
                             with: .color(dirt.opacity(0.42)))
            }
        }
    }

    // MARK: - Equipment

    private func paintWeavePoles(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Twelve poles running away from the viewer. Slim and pale so they
        // add course detail without crowding the play corridor.
        for index in 0..<12 {
            let t = CGFloat(index) / 11
            let x = 0.545 + t * 0.275
            let baseY = 0.668 - t * 0.030
            let height = 0.082 - t * 0.020
            brush.contactShadow(in: &context,
                                center: brush.p(x, baseY),
                                width: brush.rx(0.022),
                                height: brush.ry(0.010),
                                opacity: 0.24)
            var pole = Path()
            pole.move(to: brush.p(x, baseY))
            pole.addLine(to: brush.p(x + 0.004, baseY - height))
            context.stroke(pole, with: .color(equipWhite.opacity(0.92)), style: brush.stroke(brush.lw(2.2 - t)))
            // Two coloured bands per pole.
            for band in 0..<2 {
                var stripe = Path()
                let y = baseY - height * (0.34 + CGFloat(band) * 0.34)
                stripe.move(to: brush.p(x + 0.002, y))
                stripe.addLine(to: brush.p(x + 0.003, y - height * 0.14))
                context.stroke(stripe,
                               with: .color(band == 0 ? equipBlue : equipRed),
                               style: brush.stroke(brush.lw(2.2 - t)))
            }
        }
    }

    private func paintAFrame(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Set well back of the near tyre jump, so the two obstacles read as
        // separate pieces of the course rather than one stacked pile.
        let apexLeft = brush.p(0.072, 0.488)
        let apexRight = brush.p(0.154, 0.494)
        let backFoot = brush.p(-0.05, 0.612)
        let backTop = brush.p(0.032, 0.606)
        let frontFoot = brush.p(0.252, 0.646)
        let frontTop = brush.p(0.176, 0.652)

        brush.contactShadow(in: &context,
                            center: brush.p(0.100, 0.654),
                            width: brush.rx(0.40),
                            height: brush.ry(0.042),
                            opacity: 0.28)

        var farPanel = Path()
        farPanel.move(to: apexLeft)
        farPanel.addLine(to: apexRight)
        farPanel.addLine(to: backTop)
        farPanel.addLine(to: backFoot)
        farPanel.closeSubpath()
        context.fill(farPanel, with: .linearGradient(
            Gradient(colors: [Color(red: 0.16, green: 0.38, blue: 0.66), Color(red: 0.10, green: 0.26, blue: 0.48)]),
            startPoint: apexLeft,
            endPoint: backFoot))

        var nearPanel = Path()
        nearPanel.move(to: apexRight)
        nearPanel.addLine(to: apexLeft)
        nearPanel.addLine(to: frontTop)
        nearPanel.addLine(to: frontFoot)
        nearPanel.closeSubpath()
        context.fill(nearPanel, with: .linearGradient(
            Gradient(colors: [equipBlue, Color(red: 0.14, green: 0.34, blue: 0.62)]),
            startPoint: apexRight,
            endPoint: frontFoot))

        // Yellow contact zone at the bottom of the near ramp.
        let contactT: CGFloat = 0.70
        var contact = Path()
        contact.move(to: CGPoint(x: apexLeft.x + (frontTop.x - apexLeft.x) * contactT,
                                 y: apexLeft.y + (frontTop.y - apexLeft.y) * contactT))
        contact.addLine(to: CGPoint(x: apexRight.x + (frontFoot.x - apexRight.x) * contactT,
                                    y: apexRight.y + (frontFoot.y - apexRight.y) * contactT))
        contact.addLine(to: frontFoot)
        contact.addLine(to: frontTop)
        contact.closeSubpath()
        context.fill(contact, with: .color(equipYellow))

        // Anti-slip slats across both ramps.
        for index in 1..<8 {
            let t = CGFloat(index) / 8
            var slat = Path()
            slat.move(to: CGPoint(x: apexLeft.x + (frontTop.x - apexLeft.x) * t,
                                  y: apexLeft.y + (frontTop.y - apexLeft.y) * t))
            slat.addLine(to: CGPoint(x: apexRight.x + (frontFoot.x - apexRight.x) * t,
                                     y: apexRight.y + (frontFoot.y - apexRight.y) * t))
            context.stroke(slat,
                           with: .color(t > 0.72 ? Color(red: 0.72, green: 0.56, blue: 0.10).opacity(0.7)
                                                 : Color.white.opacity(0.30)),
                           style: brush.stroke(brush.lw(1.3)))
        }
        for index in 1..<7 {
            let t = CGFloat(index) / 7
            var slat = Path()
            slat.move(to: CGPoint(x: apexLeft.x + (backFoot.x - apexLeft.x) * t,
                                  y: apexLeft.y + (backFoot.y - apexLeft.y) * t))
            slat.addLine(to: CGPoint(x: apexRight.x + (backTop.x - apexRight.x) * t,
                                     y: apexRight.y + (backTop.y - apexRight.y) * t))
            context.stroke(slat, with: .color(Color.white.opacity(0.18)), style: brush.stroke(brush.lw(1.1)))
        }

        var ridge = Path()
        ridge.move(to: apexLeft)
        ridge.addLine(to: apexRight)
        context.stroke(ridge, with: .color(Color.white.opacity(0.55)), style: brush.stroke(brush.lw(2.0)))
    }

    private func paintTunnel(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Fabric tube with a dark near mouth. The body runs off the right
        // edge so the far opening never has to be finished.
        let samples: [(CGFloat, CGFloat, CGFloat)] = [
            (1.22, 0.780, 0.070), (1.10, 0.795, 0.078), (0.980, 0.818, 0.088),
            (0.880, 0.848, 0.098), (0.800, 0.880, 0.104), (0.742, 0.918, 0.108)
        ]
        brush.contactShadow(in: &context,
                            center: brush.p(0.860, 0.920),
                            width: brush.rx(0.42),
                            height: brush.ry(0.055),
                            opacity: 0.30)

        func samplePoint(_ sample: (CGFloat, CGFloat, CGFloat)) -> (CGPoint, CGFloat) {
            (brush.p(sample.0, sample.1), brush.rx(sample.2))
        }
        func offset(at index: Int, along samples: [(CGFloat, CGFloat, CGFloat)]) -> CGVector {
            let prev = brush.p(samples[max(0, index - 1)].0, samples[max(0, index - 1)].1)
            let next = brush.p(samples[min(samples.count - 1, index + 1)].0,
                               samples[min(samples.count - 1, index + 1)].1)
            let dx = next.x - prev.x
            let dy = next.y - prev.y
            let length = max(0.0001, hypot(dx, dy))
            return CGVector(dx: -dy / length, dy: dx / length)
        }

        var body = Path()
        for (index, sample) in samples.enumerated() {
            let (center, radius) = samplePoint(sample)
            let n = offset(at: index, along: samples)
            let top = CGPoint(x: center.x + n.dx * radius, y: center.y + n.dy * radius)
            if index == 0 { body.move(to: top) } else { body.addLine(to: top) }
        }
        for (index, sample) in samples.enumerated().reversed() {
            let (center, radius) = samplePoint(sample)
            let n = offset(at: index, along: samples)
            body.addLine(to: CGPoint(x: center.x - n.dx * radius * 0.92,
                                     y: center.y - n.dy * radius * 0.92))
        }
        body.closeSubpath()
        context.fill(body, with: .linearGradient(
            Gradient(colors: [Color(red: 0.22, green: 0.50, blue: 0.86),
                              Color(red: 0.10, green: 0.26, blue: 0.52)]),
            startPoint: brush.p(0.96, 0.780),
            endPoint: brush.p(0.74, 0.950)))

        // Ribs as fabric bands across the tube, not stacked full ellipses.
        for (index, sample) in samples.enumerated() {
            guard index > 0, index < samples.count - 1 else { continue }
            let (center, radius) = samplePoint(sample)
            let n = offset(at: index, along: samples)
            var rib = Path()
            rib.move(to: CGPoint(x: center.x + n.dx * radius * 0.88,
                                 y: center.y + n.dy * radius * 0.88))
            rib.addLine(to: CGPoint(x: center.x - n.dx * radius * 0.82,
                                    y: center.y - n.dy * radius * 0.82))
            context.stroke(rib,
                           with: .color((index.isMultiple(of: 2) ? Color.white : Color.black).opacity(0.22)),
                           style: brush.stroke(brush.lw(2.4)))
        }

        // Stitching along the side seam.
        var seam = Path()
        seam.move(to: brush.p(1.16, 0.792))
        seam.addCurve(to: brush.p(0.760, 0.930),
                      control1: brush.p(0.96, 0.830),
                      control2: brush.p(0.82, 0.880))
        context.stroke(seam, with: .color(Color.black.opacity(0.18)),
                       style: StrokeStyle(lineWidth: brush.lw(1.0), dash: [brush.lw(3.5), brush.lw(2.5)]))

        // Sheen along the ridge.
        var ridge = Path()
        ridge.move(to: brush.p(1.20, 0.780 - 0.062))
        ridge.addCurve(to: brush.p(0.742, 0.918 - 0.098),
                       control1: brush.p(0.98, 0.790),
                       control2: brush.p(0.84, 0.850))
        context.stroke(ridge, with: .color(Color.white.opacity(0.28)), style: brush.stroke(brush.lw(2.0)))

        // Near mouth: stacked rings receding into the tube.
        let mouth = brush.p(0.742, 0.918)
        let mouthR = brush.rx(0.108)
        let mouthRect = CGRect(x: mouth.x - mouthR, y: mouth.y - mouthR * 0.92,
                               width: mouthR * 2, height: mouthR * 1.72)
        context.fill(Path(ellipseIn: mouthRect),
                     with: .radialGradient(
                        Gradient(colors: [Color.black.opacity(0.92),
                                          Color(red: 0.05, green: 0.12, blue: 0.26)]),
                        center: mouth,
                        startRadius: 0,
                        endRadius: mouthR))
        for ring in 1...3 {
            let inset = CGFloat(ring) * 0.16
            context.stroke(Path(ellipseIn: mouthRect.insetBy(dx: mouthR * inset, dy: mouthR * inset * 0.85)),
                           with: .color(Color.white.opacity(0.08 + Double(3 - ring) * 0.04)),
                           style: brush.stroke(brush.lw(1.1)))
        }
        context.stroke(Path(ellipseIn: mouthRect),
                       with: .color(Color(red: 0.22, green: 0.22, blue: 0.24)),
                       style: brush.stroke(brush.lw(3.4)))
        context.stroke(Path(ellipseIn: mouthRect),
                       with: .color(equipYellow.opacity(0.92)),
                       style: brush.stroke(brush.lw(2.2)))
    }

    private func paintHurdles(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // One remaining jump, kept clear of the tyre so they read as two
        // separate pieces of kit rather than a fused left-hand cluster.
        let jumps: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.430, 0.958, 0.190, 0.125)
        ]
        for jump in jumps {
            let baseY = jump.1
            let halfWidth = jump.2 * 0.5
            let height = jump.3
            brush.contactShadow(in: &context,
                                center: brush.p(jump.0, baseY + 0.006),
                                width: brush.rx(jump.2 * 1.1),
                                height: brush.ry(height * 0.20),
                                opacity: 0.26)

            for side in [CGFloat(-1), CGFloat(1)] {
                let x = jump.0 + side * halfWidth
                var upright = Path()
                upright.move(to: brush.p(x, baseY))
                upright.addLine(to: brush.p(x, baseY - height))
                context.stroke(upright, with: .color(Color.black.opacity(0.18)),
                               style: brush.stroke(brush.lw(3.4)))
                context.stroke(upright, with: .color(equipWhite), style: brush.stroke(brush.lw(2.4)))
                // Foot plate.
                var foot = Path()
                foot.move(to: brush.p(x - 0.024, baseY))
                foot.addLine(to: brush.p(x + 0.024, baseY))
                context.stroke(foot, with: .color(post), style: brush.stroke(brush.lw(2.2)))
                // Wing panel on the outer side of each upright.
                var wing = Path()
                wing.move(to: brush.p(x, baseY))
                wing.addLine(to: brush.p(x + side * 0.022, baseY))
                wing.addLine(to: brush.p(x + side * 0.022, baseY - height * 0.58))
                wing.addLine(to: brush.p(x, baseY - height * 0.70))
                wing.closeSubpath()
                context.fill(wing, with: .color(equipRed.opacity(0.88)))
                context.stroke(wing, with: .color(Color.white.opacity(0.40)), style: brush.joined(brush.lw(0.9)))
            }

            for bar in 0..<2 {
                let y = baseY - height * (0.46 + CGFloat(bar) * 0.36)
                var pole = Path()
                pole.move(to: brush.p(jump.0 - halfWidth, y))
                pole.addLine(to: brush.p(jump.0 + halfWidth, y))
                context.stroke(pole, with: .color(Color.black.opacity(0.16)),
                               style: brush.stroke(brush.lw(3.6)))
                context.stroke(pole, with: .color(equipWhite), style: brush.stroke(brush.lw(2.6)))
                // Striping keeps the bars readable against the grass.
                for stripe in 0..<3 {
                    let t = CGFloat(stripe) / 3
                    var mark = Path()
                    mark.move(to: brush.p(jump.0 - halfWidth + jump.2 * (t + 0.08), y))
                    mark.addLine(to: brush.p(jump.0 - halfWidth + jump.2 * (t + 0.20), y))
                    context.stroke(mark,
                                   with: .color(bar == 0 ? equipRed : equipBlue),
                                   style: brush.stroke(brush.lw(2.6)))
                }
            }
        }
    }

    private func paintTyreJump(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A hoop slung in a frame, standing on the left of the near field.
        let center = brush.p(0.105, 0.785)
        let radius = brush.rx(0.078)
        let frameBottom = brush.ry(0.885)

        brush.contactShadow(in: &context,
                            center: CGPoint(x: center.x, y: frameBottom + brush.ry(0.006)),
                            width: radius * 3.2,
                            height: brush.ry(0.030),
                            opacity: 0.28)

        for side in [CGFloat(-1), CGFloat(1)] {
            var upright = Path()
            upright.move(to: CGPoint(x: center.x + side * radius * 1.55, y: frameBottom))
            upright.addLine(to: CGPoint(x: center.x + side * radius * 1.55, y: center.y - radius * 1.45))
            context.stroke(upright, with: .color(Color.black.opacity(0.18)), style: brush.stroke(brush.lw(3.6)))
            context.stroke(upright, with: .color(equipWhite), style: brush.stroke(brush.lw(2.6)))
        }
        var header = Path()
        header.move(to: CGPoint(x: center.x - radius * 1.55, y: center.y - radius * 1.42))
        header.addLine(to: CGPoint(x: center.x + radius * 1.55, y: center.y - radius * 1.42))
        context.stroke(header, with: .color(equipWhite), style: brush.stroke(brush.lw(2.6)))

        // Suspension straps.
        for side in [CGFloat(-1), CGFloat(1)] {
            var strap = Path()
            strap.move(to: CGPoint(x: center.x + side * radius * 1.5, y: center.y - radius * 1.40))
            strap.addLine(to: CGPoint(x: center.x + side * radius * 0.92, y: center.y - radius * 0.42))
            context.stroke(strap, with: .color(Color(red: 0.30, green: 0.30, blue: 0.32)),
                           style: brush.stroke(brush.lw(1.4)))
        }

        let tyreRect = CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: tyreRect.offsetBy(dx: radius * 0.06, dy: radius * 0.08)),
                       with: .color(Color.black.opacity(0.24)),
                       style: StrokeStyle(lineWidth: radius * 0.42))
        context.stroke(Path(ellipseIn: tyreRect),
                       with: .color(equipRed),
                       style: StrokeStyle(lineWidth: radius * 0.36))
        // Two white quadrant markings, as on real tyre jumps.
        for quadrant in 0..<2 {
            var arc = Path()
            arc.addArc(center: center,
                       radius: radius,
                       startAngle: .degrees(Double(quadrant) * 180 + 20),
                       endAngle: .degrees(Double(quadrant) * 180 + 70),
                       clockwise: false)
            context.stroke(arc, with: .color(equipWhite), style: StrokeStyle(lineWidth: radius * 0.36))
        }
        context.stroke(Path(ellipseIn: tyreRect.insetBy(dx: radius * 0.20, dy: radius * 0.20)),
                       with: .color(Color.black.opacity(0.28)),
                       style: brush.stroke(brush.lw(1.2)))
    }

    private func paintSeesaw(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Mid-field, 1.5× the previous run. The A-frame is drawn first so the
        // plank covers the near foot; the fulcrum never sits on top of the board.
        let pivot = brush.p(0.495, 0.730)
        let low = brush.p(0.243, 0.800)
        let high = brush.p(0.747, 0.660)
        let thickness = brush.ry(0.028)
        let dx = high.x - low.x
        let dy = high.y - low.y
        let span = max(1, hypot(dx, dy))
        let nx = -dy / span
        let ny = dx / span
        brush.contactShadow(in: &context,
                            center: brush.p(0.495, 0.778),
                            width: brush.rx(0.52),
                            height: brush.ry(0.032),
                            opacity: 0.28)

        let farFoot = CGPoint(x: pivot.x - brush.rx(0.036), y: pivot.y + brush.ry(0.058))
        let nearFoot = CGPoint(x: pivot.x + brush.rx(0.022), y: pivot.y + brush.ry(0.030))
        let fulcrum = CGPoint(x: pivot.x + nx * thickness * 0.55,
                              y: pivot.y + ny * thickness * 0.55)
        for foot in [farFoot, nearFoot] {
            context.fill(Path(roundedRect: CGRect(x: foot.x - brush.rx(0.024),
                                                  y: foot.y - brush.ry(0.007),
                                                  width: brush.rx(0.048),
                                                  height: brush.ry(0.014)),
                              cornerRadius: brush.ry(0.003)),
                         with: .color(Color(red: 0.22, green: 0.22, blue: 0.24)))
            var leg = Path()
            leg.move(to: foot)
            leg.addLine(to: fulcrum)
            context.stroke(leg, with: .color(Color.black.opacity(0.22)),
                           style: brush.stroke(brush.lw(4.6)))
            context.stroke(leg, with: .color(Color(red: 0.32, green: 0.32, blue: 0.34)),
                           style: brush.stroke(brush.lw(3.4)))
        }
        var brace = Path()
        brace.move(to: CGPoint(x: farFoot.x + (fulcrum.x - farFoot.x) * 0.45,
                               y: farFoot.y + (fulcrum.y - farFoot.y) * 0.45))
        brace.addLine(to: CGPoint(x: nearFoot.x + (fulcrum.x - nearFoot.x) * 0.45,
                                  y: nearFoot.y + (fulcrum.y - nearFoot.y) * 0.45))
        context.stroke(brace, with: .color(Color(red: 0.32, green: 0.32, blue: 0.34)),
                       style: brush.stroke(brush.lw(2.6)))

        // Rubber stop under the low end.
        context.fill(Path(ellipseIn: CGRect(x: low.x - brush.rx(0.016),
                                            y: low.y + thickness * 0.35,
                                            width: brush.rx(0.032),
                                            height: brush.ry(0.016))),
                     with: .color(Color(red: 0.16, green: 0.16, blue: 0.18)))

        brush.plank(in: &context,
                    from: low,
                    to: high,
                    thickness: thickness,
                    wood: equipBlue,
                    woodLight: Color(red: 0.40, green: 0.66, blue: 0.92),
                    woodDeep: Color(red: 0.10, green: 0.26, blue: 0.50))
        for end in [low, high] {
            let toward = end == low ? high : low
            let inner = CGPoint(x: end.x + (toward.x - end.x) * 0.16,
                                y: end.y + (toward.y - end.y) * 0.16)
            brush.plank(in: &context,
                        from: end,
                        to: inner,
                        thickness: thickness,
                        wood: equipYellow,
                        woodLight: Color(red: 1.0, green: 0.90, blue: 0.44),
                        woodDeep: Color(red: 0.74, green: 0.58, blue: 0.10))
            // Bolts on each contact zone.
            for boltT in [CGFloat(0.04), 0.11] {
                let bx = end.x + (toward.x - end.x) * boltT
                let by = end.y + (toward.y - end.y) * boltT
                context.fill(Path(ellipseIn: CGRect(x: bx - brush.rx(0.005),
                                                    y: by - brush.ry(0.005),
                                                    width: brush.rx(0.010),
                                                    height: brush.ry(0.010))),
                             with: .color(Color(red: 0.30, green: 0.30, blue: 0.32)))
            }
        }

        // Centre rubber strip along the walking surface.
        var strip = Path()
        strip.move(to: CGPoint(x: low.x + dx * 0.18 - nx * thickness * 0.12,
                               y: low.y + dy * 0.18 - ny * thickness * 0.12))
        strip.addLine(to: CGPoint(x: low.x + dx * 0.82 - nx * thickness * 0.12,
                                  y: low.y + dy * 0.82 - ny * thickness * 0.12))
        context.stroke(strip, with: .color(Color(red: 0.14, green: 0.16, blue: 0.22).opacity(0.55)),
                       style: brush.stroke(brush.lw(1.8)))

        // Grip ribs, skipped at the fulcrum.
        for rib in 1...9 {
            let t = CGFloat(rib) / 10
            if abs(t - 0.5) < 0.06 { continue }
            let point = CGPoint(x: low.x + dx * t, y: low.y + dy * t)
            var mark = Path()
            mark.move(to: CGPoint(x: point.x - nx * thickness * 0.42,
                                  y: point.y - ny * thickness * 0.42))
            mark.addLine(to: CGPoint(x: point.x + nx * thickness * 0.42,
                                     y: point.y + ny * thickness * 0.42))
            context.stroke(mark, with: .color(Color.white.opacity(0.28)),
                           style: brush.stroke(brush.lw(1.0)))
        }

        // Axle housing on the near edge, not a disc sitting on the board.
        let axle = CGRect(x: pivot.x - brush.rx(0.012) + nx * thickness * 0.20,
                          y: pivot.y - brush.ry(0.010) + ny * thickness * 0.20,
                          width: brush.rx(0.024),
                          height: brush.ry(0.020))
        context.fill(Path(roundedRect: axle, cornerRadius: brush.ry(0.006)),
                     with: .color(Color(red: 0.28, green: 0.28, blue: 0.30)))
        context.fill(Path(ellipseIn: axle.insetBy(dx: brush.rx(0.007), dy: brush.ry(0.005))),
                     with: .color(Color(red: 0.55, green: 0.55, blue: 0.58)))
    }

    private func paintRingDressing(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Water bowl with a bright reflection.
        let bowl = brush.p(0.062, 0.918)
        let bowlWidth = brush.rx(0.075)
        brush.contactShadow(in: &context, center: bowl,
                            width: bowlWidth * 1.5, height: bowlWidth * 0.4, opacity: 0.26)
        context.fill(Path(ellipseIn: CGRect(x: bowl.x - bowlWidth * 0.5,
                                            y: bowl.y - bowlWidth * 0.30,
                                            width: bowlWidth,
                                            height: bowlWidth * 0.52)),
                     with: .color(Color(red: 0.28, green: 0.56, blue: 0.86)))
        context.fill(Path(ellipseIn: CGRect(x: bowl.x - bowlWidth * 0.38,
                                            y: bowl.y - bowlWidth * 0.24,
                                            width: bowlWidth * 0.76,
                                            height: bowlWidth * 0.34)),
                     with: .color(Color(red: 0.62, green: 0.84, blue: 0.94)))

        paintTennisBall(brush, in: &context, at: (0.280, 0.858), radius: 0.017)
        paintTennisBall(brush, in: &context, at: (0.175, 0.938), radius: 0.015)
    }

    private func paintTennisBall(_ brush: HabitatBrush,
                                 in context: inout GraphicsContext,
                                 at fraction: (CGFloat, CGFloat),
                                 radius: CGFloat) {
        let point = brush.p(fraction.0, fraction.1)
        let r = brush.rx(radius)
        brush.contactShadow(in: &context,
                            center: CGPoint(x: point.x, y: point.y + r * 0.8),
                            width: r * 2.4, height: r * 0.8, opacity: 0.24)
        context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r,
                                            width: r * 2, height: r * 2)),
                     with: .radialGradient(
                        Gradient(colors: [Color(red: 0.88, green: 0.94, blue: 0.34),
                                          Color(red: 0.58, green: 0.68, blue: 0.16)]),
                        center: CGPoint(x: point.x - r * 0.3, y: point.y - r * 0.35),
                        startRadius: 0,
                        endRadius: r * 1.4))
        var seam = Path()
        seam.move(to: CGPoint(x: point.x - r * 0.9, y: point.y - r * 0.2))
        seam.addQuadCurve(to: CGPoint(x: point.x + r * 0.9, y: point.y - r * 0.2),
                          control: CGPoint(x: point.x, y: point.y + r * 0.7))
        context.stroke(seam, with: .color(Color.white.opacity(0.75)), style: brush.stroke(brush.lw(0.9)))
    }

    private func paintBunting(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Two poles planted at the ring fence, carrying a sagging line of
        // pennants across the top of the cabinet.
        let poleXs: [CGFloat] = [0.016, 0.984]
        let poleBase: CGFloat = 0.662
        for x in poleXs {
            brush.contactShadow(in: &context,
                                center: brush.p(x, poleBase + 0.006),
                                width: brush.rx(0.070),
                                height: brush.ry(0.022),
                                opacity: 0.32)
            // A turf collar so the foot is in the grass, not hovering on it.
            context.fill(Path(ellipseIn: CGRect(
                x: brush.p(x, poleBase).x - brush.rx(0.028),
                y: brush.p(x, poleBase).y - brush.ry(0.006),
                width: brush.rx(0.056),
                height: brush.ry(0.018))),
                         with: .color(turfDeep.opacity(0.55)))
            let footW = brush.rx(0.032)
            context.fill(Path(roundedRect: CGRect(x: brush.p(x, poleBase).x - footW * 0.5,
                                                  y: brush.p(x, poleBase).y - brush.ry(0.012),
                                                  width: footW,
                                                  height: brush.ry(0.018)),
                              cornerRadius: brush.ry(0.004)),
                         with: .color(Color(red: 0.42, green: 0.40, blue: 0.36)))
            var pole = Path()
            pole.move(to: brush.p(x, 0.018))
            pole.addLine(to: brush.p(x, poleBase - 0.006))
            context.stroke(pole, with: .color(Color.black.opacity(0.16)), style: brush.stroke(brush.lw(4.0)))
            context.stroke(pole, with: .linearGradient(
                Gradient(colors: [post, Color(red: 0.56, green: 0.55, blue: 0.52)]),
                startPoint: brush.p(x - 0.01, 0),
                endPoint: brush.p(x + 0.01, 0)),
                           style: brush.stroke(brush.lw(2.8)))
            var finial = Path()
            let tip = brush.p(x, 0.018)
            finial.addEllipse(in: CGRect(x: tip.x - brush.rx(0.012), y: tip.y - brush.rx(0.012),
                                         width: brush.rx(0.024), height: brush.rx(0.024)))
            context.fill(finial, with: .color(equipYellow))
        }

        let lines: [(CGFloat, CGFloat, CGFloat)] = [(0.016, 0.984, 0.150), (0.016, 0.984, 0.245)]
        for (lineIndex, line) in lines.enumerated() {
            let start = brush.p(line.0, 0.045 + CGFloat(lineIndex) * 0.075)
            let end = brush.p(line.1, 0.055 + CGFloat(lineIndex) * 0.075)
            let sag = brush.ry(line.2)
            var cord = Path()
            cord.move(to: start)
            cord.addQuadCurve(to: end,
                              control: CGPoint(x: (start.x + end.x) * 0.5,
                                               y: (start.y + end.y) * 0.5 + sag))
            context.stroke(cord, with: .color(Color(red: 0.36, green: 0.34, blue: 0.32).opacity(0.75)),
                           style: brush.stroke(brush.lw(1.2)))

            let flagColors = [equipRed, equipYellow, equipBlue,
                              Color(red: 0.94, green: 0.96, blue: 0.94),
                              Color(red: 0.30, green: 0.72, blue: 0.42)]
            let count = 13
            for index in 0..<count {
                let t = CGFloat(index) / CGFloat(count - 1)
                // Point on the quadratic cord.
                let oneX = start.x + ((start.x + end.x) * 0.5 - start.x) * t
                let oneY = start.y + ((start.y + end.y) * 0.5 + sag - start.y) * t
                let twoX = (start.x + end.x) * 0.5 + (end.x - (start.x + end.x) * 0.5) * t
                let twoY = (start.y + end.y) * 0.5 + sag + (end.y - ((start.y + end.y) * 0.5 + sag)) * t
                let anchor = CGPoint(x: oneX + (twoX - oneX) * t, y: oneY + (twoY - oneY) * t)
                let flagWidth = brush.rx(0.030)
                let flagHeight = brush.ry(0.052)
                var flag = Path()
                flag.move(to: CGPoint(x: anchor.x - flagWidth * 0.5, y: anchor.y))
                flag.addLine(to: CGPoint(x: anchor.x + flagWidth * 0.5, y: anchor.y))
                flag.addLine(to: CGPoint(x: anchor.x, y: anchor.y + flagHeight))
                flag.closeSubpath()
                context.fill(flag,
                             with: .color(flagColors[(index + lineIndex) % flagColors.count].opacity(0.92)))
                context.stroke(flag, with: .color(Color.black.opacity(0.10)), style: brush.joined(brush.lw(0.6)))
            }
        }
    }

    private func paintForeground(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Rough grass at the ring edge, left uncut, crops the bottom corners.
        for index in 0..<6 {
            brush.grassTuft(in: &context,
                            base: brush.p(0.012 + CGFloat(index) * 0.040, 1.015),
                            height: brush.ry(0.125 + CGFloat(index % 3) * 0.028),
                            width: brush.rx(0.092),
                            colors: [turfDeep, Color(red: 0.26, green: 0.52, blue: 0.22), turf],
                            bladeCount: 10,
                            seed: 400 &+ index,
                            shadow: 0)
            brush.grassTuft(in: &context,
                            base: brush.p(0.760 + CGFloat(index) * 0.050, 1.020),
                            height: brush.ry(0.135 + CGFloat(index % 3) * 0.026),
                            width: brush.rx(0.096),
                            colors: [turfDeep, Color(red: 0.24, green: 0.50, blue: 0.21), turf],
                            bladeCount: 10,
                            seed: 450 &+ index,
                            shadow: 0)
        }

        // A few daisies in the rough, the way club fields always have.
        for index in 0..<6 {
            brush.flower(in: &context,
                         base: brush.p(index < 3
                                       ? 0.030 + CGFloat(index) * 0.055
                                       : 0.820 + CGFloat(index - 3) * 0.055,
                                       0.995),
                         height: brush.ry(0.060),
                         stem: Color(red: 0.26, green: 0.50, blue: 0.21),
                         petal: Color(red: 0.97, green: 0.97, blue: 0.93),
                         heart: Color(red: 0.98, green: 0.82, blue: 0.26),
                         petals: 8,
                         seed: 500 &+ index,
                         lean: index.isMultiple(of: 2) ? 0.07 : -0.06)
        }
    }
}
