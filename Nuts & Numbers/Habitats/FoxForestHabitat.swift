//
//  FoxForestHabitat.swift
//  Nuts & Numbers
//
//  Deep autumn woodland. Receding trunks and a low sun build the depth, a den
//  under a root mound anchors the right side and the canopy closes the top of
//  the frame. The clearing in the middle stays open and low in contrast.
//

import SwiftUI

struct FoxForestHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let hazeGold = Color(red: 0.95, green: 0.78, blue: 0.44)
    private let hazeDeep = Color(red: 0.58, green: 0.38, blue: 0.18)
    private let canopyDark = Color(red: 0.36, green: 0.19, blue: 0.08)
    private let canopyRed = Color(red: 0.74, green: 0.25, blue: 0.11)
    private let canopyOrange = Color(red: 0.87, green: 0.47, blue: 0.13)
    private let canopyGold = Color(red: 0.94, green: 0.70, blue: 0.22)
    private let canopyOlive = Color(red: 0.52, green: 0.46, blue: 0.17)
    private let trunkDark = Color(red: 0.26, green: 0.18, blue: 0.13)
    private let trunkLight = Color(red: 0.50, green: 0.38, blue: 0.26)
    private let birch = Color(red: 0.88, green: 0.85, blue: 0.79)
    private let birchShade = Color(red: 0.62, green: 0.58, blue: 0.52)
    private let litterLight = Color(red: 0.78, green: 0.50, blue: 0.22)
    private let litterDeep = Color(red: 0.24, green: 0.15, blue: 0.09)
    private let moss = Color(red: 0.36, green: 0.44, blue: 0.18)

    var body: some View {
        Canvas { context, size in
            let brush = HabitatBrush(size: size, isPad: isPad)
            paintBackdrop(brush, in: &context)
            paintDistantTrees(brush, in: &context)
            paintSunShafts(brush, in: &context)
            paintForestFloor(brush, in: &context)
            paintPath(brush, in: &context)
            paintLitter(brush, in: &context)
            paintMidTrunks(brush, in: &context)
            paintDen(brush, in: &context)
            paintFallenLog(brush, in: &context)
            paintBramble(brush, in: &context)
            paintFrameTrees(brush, in: &context)
            paintCanopy(brush, in: &context)
            paintForeground(brush, in: &context)
        }
        .overlay {
            LinearGradient(colors: [.white.opacity(0.06),
                                    .clear,
                                    character.deepColor.opacity(0.06)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Depth

    private func paintBackdrop(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        context.fill(Path(CGRect(origin: .zero, size: brush.size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: Color(red: 0.46, green: 0.34, blue: 0.16), location: 0),
                            .init(color: Color(red: 0.80, green: 0.58, blue: 0.26), location: 0.22),
                            .init(color: hazeGold, location: 0.44),
                            .init(color: hazeDeep, location: 0.62),
                            .init(color: Color(red: 0.30, green: 0.18, blue: 0.09), location: 1)
                        ]),
                        startPoint: brush.p(0.72, 0),
                        endPoint: brush.p(0.36, 1)))

        // The low sun burns through a gap in the canopy on the right.
        brush.sun(in: &context,
                  center: brush.p(0.845, 0.335),
                  radius: brush.rx(0.070),
                  core: Color(red: 1.0, green: 0.95, blue: 0.76).opacity(0.62),
                  glow: Color(red: 1.0, green: 0.86, blue: 0.48).opacity(0.34),
                  glowSpread: 4.2)
    }

    private func paintDistantTrees(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Three receding bands. Each is flatter, paler and shorter than the
        // one in front of it, which is what sells the depth of a real wood.
        let bands: [(CGFloat, CGFloat, Double, Int)] = [
            (0.520, 0.30, 0.20, 17),
            (0.560, 0.38, 0.34, 13),
            (0.605, 0.46, 0.50, 10)
        ]
        for (bandIndex, band) in bands.enumerated() {
            for index in 0..<band.3 {
                let x = -0.03 + CGFloat(index) / CGFloat(band.3 - 1) * 1.06
                    + habitatNoise(index &+ bandIndex &* 40, 3, -0.020, 0.020)
                let height = band.1 * habitatNoise(index &+ bandIndex &* 40, 4, 0.68, 1.24)
                let baseY = band.0 + habitatNoise(index, 5, -0.008, 0.008)
                let width = brush.rx(0.010 + CGFloat(bandIndex) * 0.006)
                var stem = Path()
                stem.move(to: brush.p(x, baseY))
                stem.addQuadCurve(to: brush.p(x + habitatNoise(index, 6, -0.012, 0.012), baseY - height),
                                  control: brush.p(x, baseY - height * 0.5))
                context.stroke(stem,
                               with: .color(canopyDark.opacity(band.2)),
                               style: brush.stroke(width))
                brush.crown(in: &context,
                            center: brush.p(x, baseY - height * 0.92),
                            width: brush.rx(0.10 + CGFloat(bandIndex) * 0.035),
                            height: brush.ry(0.075 + CGFloat(bandIndex) * 0.025),
                            colors: [canopyOrange.opacity(band.2 * 0.9),
                                     canopyGold.opacity(band.2 * 0.75),
                                     canopyRed.opacity(band.2 * 0.8)],
                            seed: 100 &+ bandIndex &* 30 &+ index,
                            lobes: 4)
            }
            brush.hazeBand(in: &context,
                           top: band.0 - 0.10,
                           bottom: band.0 + 0.03,
                           color: hazeGold.opacity(0.22))
        }
    }

    private func paintSunShafts(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        let shafts: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
            (0.86, 0.96, 0.44, 0.62, 0.86, 0.085),
            (0.74, 0.80, 0.30, 0.42, 0.80, 0.060),
            (0.94, 1.04, 0.62, 0.84, 0.92, 0.070),
            (0.60, 0.65, 0.20, 0.28, 0.74, 0.045)
        ]
        for shaft in shafts {
            brush.lightShaft(in: &context,
                             topLeft: shaft.0,
                             topRight: shaft.1,
                             bottomLeft: shaft.2,
                             bottomRight: shaft.3,
                             topY: 0,
                             bottomY: brush.ry(shaft.4),
                             color: Color(red: 1.0, green: 0.82, blue: 0.44).opacity(shaft.5))
        }
    }

    // MARK: - Floor

    private func paintForestFloor(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var floor = Path()
        floor.move(to: brush.p(0, 0.600))
        floor.addQuadCurve(to: brush.p(1, 0.590), control: brush.p(0.5, 0.630))
        floor.addLine(to: brush.p(1, 1))
        floor.addLine(to: brush.p(0, 1))
        floor.closeSubpath()
        context.fill(floor, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.66, green: 0.44, blue: 0.20), location: 0),
                .init(color: litterLight, location: 0.26),
                .init(color: Color(red: 0.50, green: 0.30, blue: 0.14), location: 0.66),
                .init(color: litterDeep, location: 1)
            ]),
            startPoint: brush.p(0.5, 0.59),
            endPoint: brush.p(0.5, 1)))

        let patches: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (0.14, 0.655, 0.30, 0.060, moss.opacity(0.26)),
            (0.62, 0.640, 0.26, 0.050, Color(red: 0.92, green: 0.66, blue: 0.28).opacity(0.20)),
            (0.88, 0.720, 0.28, 0.080, litterDeep.opacity(0.24)),
            (0.28, 0.810, 0.36, 0.110, Color(red: 0.88, green: 0.58, blue: 0.22).opacity(0.16)),
            (0.72, 0.930, 0.42, 0.120, litterDeep.opacity(0.28))
        ]
        for (index, patch) in patches.enumerated() {
            brush.groundPatch(in: &context,
                              center: brush.p(patch.0, patch.1),
                              width: brush.rx(patch.2),
                              height: brush.ry(patch.3),
                              color: patch.4,
                              seed: 200 &+ index &* 11)
        }

        // Surface roots crossing the floor tie the trunks to the ground.
        let roots: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.02, 0.780, 0.14, 0.760, 0.30, 0.800),
            (0.03, 0.885, 0.18, 0.905, 0.36, 0.880),
            (0.98, 0.760, 0.86, 0.745, 0.70, 0.790),
            (0.99, 0.870, 0.84, 0.895, 0.66, 0.870)
        ]
        for root in roots {
            var path = Path()
            path.move(to: brush.p(root.0, root.1))
            path.addQuadCurve(to: brush.p(root.4, root.5), control: brush.p(root.2, root.3))
            context.stroke(path, with: .color(Color.black.opacity(0.20)),
                           style: brush.stroke(brush.rx(0.026)))
            context.stroke(path,
                           with: .linearGradient(Gradient(colors: [trunkLight, trunkDark]),
                                                 startPoint: brush.p(root.0, root.1),
                                                 endPoint: brush.p(root.4, root.5)),
                           style: brush.stroke(brush.rx(0.019)))
        }
    }

    private func paintPath(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A worn game trail widening toward the viewer. Soft fill first, then
        // broken edge patches so it never sits as a hard lozenge on the floor.
        var trail = Path()
        trail.move(to: brush.p(0.475, 0.610))
        trail.addCurve(to: brush.p(0.325, 1.02),
                       control1: brush.p(0.52, 0.74),
                       control2: brush.p(0.32, 0.84))
        trail.addLine(to: brush.p(0.735, 1.02))
        trail.addCurve(to: brush.p(0.545, 0.610),
                       control1: brush.p(0.71, 0.84),
                       control2: brush.p(0.50, 0.74))
        trail.closeSubpath()
        context.fill(trail, with: .linearGradient(
            Gradient(colors: [Color(red: 0.62, green: 0.46, blue: 0.26).opacity(0.38),
                              Color(red: 0.40, green: 0.28, blue: 0.16).opacity(0.32)]),
            startPoint: brush.p(0.5, 0.61),
            endPoint: brush.p(0.5, 1)))

        for index in 0..<10 {
            let t = CGFloat(index) / 9
            let y = 0.640 + t * t * 0.36
            let half = 0.040 + t * 0.14
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            brush.groundPatch(in: &context,
                              center: brush.p(0.51 + side * half, y),
                              width: brush.rx(0.070 + t * 0.04),
                              height: brush.ry(0.028 + t * 0.018),
                              color: Color(red: 0.32, green: 0.22, blue: 0.12).opacity(0.16),
                              seed: 240 &+ index &* 7)
        }

        context.drawLayer { inner in
            inner.clip(to: trail)
            for index in 0..<16 {
                let t = CGFloat(index) / 15
                let y = 0.640 + t * t * 0.36
                let half = 0.028 + t * 0.12
                var scuff = Path()
                scuff.move(to: brush.p(0.50 - half, y))
                scuff.addQuadCurve(to: brush.p(0.50 + half * 0.7, y + 0.006),
                                   control: brush.p(0.50, y - 0.008))
                inner.stroke(scuff,
                             with: .color(Color(red: 0.72, green: 0.54, blue: 0.30)
                                .opacity(0.10 + Double(t) * 0.08)),
                             style: brush.stroke(brush.lw(0.9 + t)))
            }
        }
    }

    private func paintLitter(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Fallen leaves: bigger and more saturated near the glass, tiny and
        // muted toward the horizon.
        let colors = [canopyRed, canopyOrange, canopyGold,
                      Color(red: 0.56, green: 0.30, blue: 0.12), canopyOlive]
        for index in 0..<48 {
            let depth = habitatNoise(index, 11)
            let x = habitatNoise(index, 12, 0.01, 0.99)
            let y = 0.610 + depth * depth * 0.39
            let length = brush.rx(0.014 + depth * 0.034)
            let color = colors[index % colors.count].opacity(0.62 + Double(depth) * 0.32)
            if depth < 0.38 {
                // Distant litter reads as a speck. A full leaf() is lost at
                // that size and costs a gradient plus a vein on first raster.
                let center = brush.p(x, y)
                context.fill(Path(ellipseIn: CGRect(x: center.x - length * 0.45,
                                                    y: center.y - length * 0.22,
                                                    width: length * 0.90,
                                                    height: length * 0.44)),
                             with: .color(color))
            } else {
                brush.leaf(in: &context,
                           center: brush.p(x, y),
                           length: length,
                           angle: Double(habitatNoise(index, 13)) * .pi,
                           color: color,
                           vein: 0.10)
            }
        }

        // Acorns and beech mast in a few clusters rather than spread evenly.
        for cluster in 0..<4 {
            let cx = habitatNoise(cluster, 14, 0.08, 0.90)
            let cy = habitatNoise(cluster, 15, 0.78, 0.97)
            for index in 0..<4 {
                let point = brush.p(cx + habitatNoise(cluster &* 9 &+ index, 16, -0.030, 0.030),
                                    cy + habitatNoise(cluster &* 9 &+ index, 17, -0.014, 0.014))
                let radius = brush.rx(0.009)
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius * 1.2,
                                                    width: radius * 2, height: radius * 2.4)),
                             with: .color(Color(red: 0.72, green: 0.52, blue: 0.24)))
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius * 1.1, y: point.y - radius * 1.5,
                                                    width: radius * 2.2, height: radius * 1.1)),
                             with: .color(Color(red: 0.36, green: 0.24, blue: 0.12)))
            }
        }
    }

    // MARK: - Mid-ground

    private func paintMidTrunks(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Two birches and two oaks standing in the middle distance. They are
        // slender and low in contrast so the play corridor stays readable.
        let birches: [(CGFloat, CGFloat, CGFloat)] = [(0.285, 0.618, 0.026), (0.365, 0.606, 0.019)]
        for (index, tree) in birches.enumerated() {
            let base = brush.p(tree.0, tree.1)
            let top = brush.p(tree.0 + 0.012, -0.02)
            brush.trunk(in: &context,
                        base: base,
                        top: top,
                        baseWidth: brush.rx(tree.2),
                        topWidth: brush.rx(tree.2 * 0.52),
                        bark: birchShade,
                        barkLight: birch,
                        grain: 2,
                        seed: 300 &+ index)
            for scar in 0..<7 {
                let y = 0.05 + CGFloat(scar) * 0.078
                let mark = CGRect(x: base.x - brush.rx(tree.2 * 0.42)
                                    + habitatNoise(index &* 11 &+ scar, 21, 0, tree.2 * 0.5) * brush.w,
                                  y: brush.ry(y),
                                  width: brush.rx(tree.2 * habitatNoise(index &* 11 &+ scar, 22, 0.30, 0.62)),
                                  height: brush.ry(0.008))
                context.fill(Path(roundedRect: mark, cornerRadius: mark.height * 0.5),
                             with: .color(Color(red: 0.24, green: 0.20, blue: 0.17).opacity(0.62)))
            }
        }

        let oaks: [(CGFloat, CGFloat, CGFloat)] = [(0.635, 0.628, 0.034), (0.715, 0.612, 0.024)]
        for (index, tree) in oaks.enumerated() {
            brush.trunk(in: &context,
                        base: brush.p(tree.0, tree.1),
                        top: brush.p(tree.0 - 0.016, -0.02),
                        baseWidth: brush.rx(tree.2),
                        topWidth: brush.rx(tree.2 * 0.48),
                        bark: trunkDark.opacity(0.88),
                        barkLight: trunkLight.opacity(0.88),
                        grain: 3,
                        seed: 350 &+ index)
        }
    }

    private func paintDen(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Earth mound with an arch of exposed roots and a dark entrance. The
        // hole is the darkest value in the scene, so it reads instantly.
        let moundCenter = brush.p(0.845, 0.735)
        let moundPoints = brush.blobPoints(center: moundCenter,
                                           radiusX: brush.rx(0.220),
                                           radiusY: brush.ry(0.115),
                                           count: 10,
                                           irregularity: 0.28,
                                           seed: 401)
        context.fill(brush.blob(moundPoints), with: .linearGradient(
            Gradient(colors: [Color(red: 0.46, green: 0.32, blue: 0.17),
                              Color(red: 0.20, green: 0.13, blue: 0.08)]),
            startPoint: CGPoint(x: moundCenter.x, y: moundCenter.y - brush.ry(0.11)),
            endPoint: CGPoint(x: moundCenter.x, y: moundCenter.y + brush.ry(0.11))))

        // Grass and moss holding the mound together.
        for index in 0..<6 {
            brush.grassTuft(in: &context,
                            base: brush.p(0.700 + CGFloat(index) * 0.058, 0.678 + CGFloat(index % 3) * 0.016),
                            height: brush.ry(0.040),
                            width: brush.rx(0.052),
                            colors: [moss, Color(red: 0.48, green: 0.52, blue: 0.20)],
                            bladeCount: 7,
                            seed: 420 &+ index,
                            shadow: 0.10)
        }

        let mouth = brush.p(0.845, 0.775)
        var opening = Path()
        opening.move(to: CGPoint(x: mouth.x - brush.rx(0.072), y: mouth.y + brush.ry(0.048)))
        opening.addCurve(to: CGPoint(x: mouth.x + brush.rx(0.070), y: mouth.y + brush.ry(0.046)),
                         control1: CGPoint(x: mouth.x - brush.rx(0.078), y: mouth.y - brush.ry(0.058)),
                         control2: CGPoint(x: mouth.x + brush.rx(0.076), y: mouth.y - brush.ry(0.060)))
        opening.addQuadCurve(to: CGPoint(x: mouth.x - brush.rx(0.072), y: mouth.y + brush.ry(0.048)),
                             control: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.070)))
        opening.closeSubpath()
        context.fill(opening, with: .radialGradient(
            Gradient(colors: [Color.black.opacity(0.95), Color(red: 0.14, green: 0.09, blue: 0.05)]),
            center: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.02)),
            startRadius: 0,
            endRadius: brush.rx(0.09)))

        // Loose spoil fanning out of the entrance.
        var spoil = Path()
        spoil.move(to: CGPoint(x: mouth.x - brush.rx(0.10), y: mouth.y + brush.ry(0.052)))
        spoil.addQuadCurve(to: CGPoint(x: mouth.x + brush.rx(0.10), y: mouth.y + brush.ry(0.050)),
                           control: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.018)))
        spoil.addQuadCurve(to: CGPoint(x: mouth.x - brush.rx(0.10), y: mouth.y + brush.ry(0.052)),
                           control: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.108)))
        spoil.closeSubpath()
        context.fill(spoil, with: .color(Color(red: 0.58, green: 0.42, blue: 0.22).opacity(0.85)))

        // Root arch over the mouth.
        for index in 0..<4 {
            var root = Path()
            let lift = CGFloat(index) * 0.014
            root.move(to: brush.p(0.720 - lift * 0.4, 0.712 + lift))
            root.addCurve(to: brush.p(0.965 + lift * 0.3, 0.726 + lift),
                          control1: brush.p(0.790, 0.660 + lift * 1.4),
                          control2: brush.p(0.900, 0.664 + lift * 1.4))
            context.stroke(root, with: .color(Color.black.opacity(0.22)),
                           style: brush.stroke(brush.rx(0.023 - CGFloat(index) * 0.003)))
            context.stroke(root,
                           with: .linearGradient(Gradient(colors: [trunkLight, trunkDark]),
                                                 startPoint: brush.p(0.72, 0.71),
                                                 endPoint: brush.p(0.96, 0.73)),
                           style: brush.stroke(brush.rx(0.017 - CGFloat(index) * 0.002)))
        }
    }

    private func paintFallenLog(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        let start = brush.p(-0.03, 0.815)
        let end = brush.p(0.295, 0.775)
        brush.contactShadow(in: &context,
                            center: brush.p(0.135, 0.815),
                            width: brush.rx(0.36),
                            height: brush.ry(0.042),
                            opacity: 0.28)
        brush.log(in: &context,
                  from: start,
                  to: end,
                  thickness: brush.ry(0.058),
                  bark: trunkDark,
                  barkLight: trunkLight,
                  core: Color(red: 0.78, green: 0.58, blue: 0.32))
        var coat = Path()
        coat.move(to: CGPoint(x: start.x, y: start.y - brush.ry(0.024)))
        coat.addQuadCurve(to: CGPoint(x: end.x - brush.rx(0.02), y: end.y - brush.ry(0.026)),
                          control: brush.p(0.14, 0.776))
        context.stroke(coat, with: .color(moss.opacity(0.88)), style: brush.stroke(brush.lw(3.6)))

        for index in 0..<4 {
            brush.mushroom(in: &context,
                           base: brush.p(0.055 + CGFloat(index) * 0.055, 0.862 + CGFloat(index % 2) * 0.018),
                           height: brush.ry(0.034 + CGFloat(index % 3) * 0.008),
                           cap: index.isMultiple(of: 2)
                                ? Color(red: 0.84, green: 0.44, blue: 0.16)
                                : Color(red: 0.66, green: 0.34, blue: 0.14),
                           capShade: Color(red: 0.44, green: 0.22, blue: 0.09),
                           stem: Color(red: 0.92, green: 0.86, blue: 0.72),
                           speckles: false,
                           seed: 500 &+ index)
        }
    }

    private func paintBramble(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Arching bramble canes with blackberries between the log and the path.
        for index in 0..<5 {
            let base = brush.p(0.165 + CGFloat(index) * 0.036, 0.760)
            let tip = brush.p(0.255 + CGFloat(index) * 0.048, 0.700 + CGFloat(index % 2) * 0.030)
            var cane = Path()
            cane.move(to: base)
            cane.addQuadCurve(to: tip,
                              control: CGPoint(x: base.x + brush.rx(0.02), y: base.y - brush.ry(0.090)))
            context.stroke(cane,
                           with: .color(Color(red: 0.38, green: 0.30, blue: 0.18)),
                           style: brush.stroke(brush.lw(1.4)))
            for leafIndex in 0..<3 {
                let t = CGFloat(leafIndex + 1) / 4
                let point = CGPoint(x: base.x + (tip.x - base.x) * t,
                                    y: base.y + (tip.y - base.y) * t - brush.ry(0.020) * sin(Double(t) * .pi))
                brush.leaf(in: &context,
                           center: point,
                           length: brush.ry(0.038),
                           angle: leafIndex.isMultiple(of: 2) ? -0.6 : .pi + 0.7,
                           color: Color(red: 0.30, green: 0.40, blue: 0.16),
                           vein: 0.12)
            }
            if index.isMultiple(of: 2) {
                for berry in 0..<3 {
                    let radius = brush.rx(0.008)
                    let point = CGPoint(x: tip.x + CGFloat(berry - 1) * radius * 1.6,
                                        y: tip.y + CGFloat(berry % 2) * radius * 1.4)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                        width: radius * 2, height: radius * 2)),
                                 with: .color(Color(red: 0.16, green: 0.08, blue: 0.18)))
                }
            }
        }
    }

    // MARK: - Frame and canopy

    private func paintFrameTrees(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        brush.trunk(in: &context,
                    base: brush.p(0.030, 1.02),
                    top: brush.p(0.085, -0.02),
                    baseWidth: brush.rx(0.140),
                    topWidth: brush.rx(0.075),
                    bark: trunkDark,
                    barkLight: trunkLight,
                    grain: 4,
                    seed: 601)
        brush.trunk(in: &context,
                    base: brush.p(0.972, 1.02),
                    top: brush.p(0.918, -0.02),
                    baseWidth: brush.rx(0.125),
                    topWidth: brush.rx(0.068),
                    bark: trunkDark,
                    barkLight: trunkLight,
                    grain: 4,
                    seed: 611)

        // Deep bark furrows: oaks read wrong without them.
        for side in [false, true] {
            let anchor: CGFloat = side ? 0.945 : 0.055
            let drift: CGFloat = side ? -0.030 : 0.030
            for index in 0..<5 {
                let offset = (CGFloat(index) / 4 - 0.5) * 0.070
                var groove = Path()
                groove.move(to: brush.p(anchor + offset, 0.98))
                groove.addCurve(to: brush.p(anchor + offset * 0.5 + drift, 0.02),
                                control1: brush.p(anchor + offset * 1.4 + drift * 0.3, 0.66),
                                control2: brush.p(anchor + offset * 0.6 + drift * 0.8, 0.32))
                context.stroke(groove,
                               with: .color(index.isMultiple(of: 2)
                                            ? Color.black.opacity(0.24)
                                            : Color.white.opacity(0.09)),
                               style: brush.stroke(brush.lw(1.2)))
            }
            // A burl knot on each trunk catches the low light.
            let knot = CGRect(x: brush.rx(anchor - 0.028), y: brush.ry(side ? 0.520 : 0.430),
                              width: brush.rx(0.056), height: brush.rx(0.042))
            context.fill(Path(ellipseIn: knot), with: .color(trunkDark.opacity(0.85)))
            context.stroke(Path(ellipseIn: knot.insetBy(dx: brush.rx(0.011), dy: brush.rx(0.008))),
                           with: .color(trunkLight.opacity(0.62)),
                           style: brush.stroke(brush.lw(1.0)))
        }
    }

    private func paintCanopy(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Overlapping foliage masses close the top of the frame, with narrow
        // gaps left for the sky glow to come through.
        let masses: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.02, 0.030, 0.30, 0.17), (0.16, 0.005, 0.28, 0.15),
            (0.32, 0.035, 0.24, 0.13), (0.50, 0.010, 0.26, 0.14),
            (0.67, 0.030, 0.25, 0.14), (0.84, 0.000, 0.30, 0.16),
            (0.99, 0.045, 0.26, 0.16), (0.06, 0.145, 0.20, 0.13),
            (0.94, 0.155, 0.20, 0.13), (0.42, 0.115, 0.16, 0.09)
        ]
        let palettes: [[Color]] = [
            [canopyOrange, canopyGold, canopyRed],
            [canopyRed, canopyDark, canopyOrange],
            [canopyGold, canopyOlive, canopyOrange]
        ]
        for (index, mass) in masses.enumerated() {
            brush.crown(in: &context,
                        center: brush.p(mass.0, mass.1),
                        width: brush.rx(mass.2),
                        height: brush.ry(mass.3),
                        colors: palettes[index % palettes.count],
                        seed: 700 &+ index &* 13,
                        lobes: 5)
        }

        // Branches carrying the canopy in from the frame trees.
        let branches: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.075, 0.180, 0.22, 0.085, 0.44, 0.075, 0.026),
            (0.925, 0.200, 0.78, 0.095, 0.56, 0.088, 0.024),
            (0.070, 0.330, 0.17, 0.250, 0.28, 0.230, 0.016),
            (0.930, 0.350, 0.83, 0.265, 0.73, 0.248, 0.015)
        ]
        for branch in branches {
            var path = Path()
            path.move(to: brush.p(branch.0, branch.1))
            path.addQuadCurve(to: brush.p(branch.4, branch.5), control: brush.p(branch.2, branch.3))
            context.stroke(path,
                           with: .linearGradient(Gradient(colors: [trunkDark, trunkLight, trunkDark]),
                                                 startPoint: brush.p(branch.0, branch.1),
                                                 endPoint: brush.p(branch.4, branch.5)),
                           style: brush.stroke(brush.rx(branch.6)))
        }

        // Leaves hanging off the branches themselves, not sprinkled in the
        // empty air between them.
        for (branchIndex, branch) in branches.enumerated() {
            for sample in 0..<5 {
                let t = 0.18 + CGFloat(sample) / 5 * 0.70
                let oneX = branch.0 + (branch.2 - branch.0) * t
                let oneY = branch.1 + (branch.3 - branch.1) * t
                let twoX = branch.2 + (branch.4 - branch.2) * t
                let twoY = branch.3 + (branch.5 - branch.3) * t
                let x = oneX + (twoX - oneX) * t
                let y = oneY + (twoY - oneY) * t + 0.018
                brush.leaf(in: &context,
                           center: brush.p(x, y),
                           length: brush.ry(habitatNoise(branchIndex &* 10 &+ sample, 33, 0.028, 0.048)),
                           angle: Double(habitatNoise(branchIndex &* 10 &+ sample, 34, 0.6, 2.4)),
                           color: [canopyRed, canopyOrange, canopyGold][sample % 3].opacity(0.88),
                           vein: 0.12)
            }
        }
    }

    private func paintForeground(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Bracken silhouettes in the bottom corners.
        let fronds: [(CGFloat, CGFloat, CGFloat, Double, CGFloat)] = [
            (0.01, 1.02, 0.30, -1.20, 0.22), (0.085, 1.03, 0.35, -1.46, 0.12),
            (0.175, 1.03, 0.26, -1.78, -0.18),
            (0.985, 1.02, 0.31, -1.92, -0.22), (0.905, 1.03, 0.36, -1.66, -0.10),
            (0.815, 1.03, 0.25, -1.34, 0.18)
        ]
        for frond in fronds {
            brush.frond(in: &context,
                        base: brush.p(frond.0, frond.1),
                        length: brush.ry(frond.2),
                        angle: frond.3,
                        curl: frond.4,
                        color: Color(red: 0.30, green: 0.20, blue: 0.08),
                        tipColor: Color(red: 0.52, green: 0.32, blue: 0.10),
                        leaflets: 10)
        }

        // A ring of toadstools in the near litter.
        for index in 0..<5 {
            let angle = Double(index) / 5 * 2 * .pi
            let center = brush.p(0.505 + CGFloat(cos(angle)) * 0.075,
                                 0.965 + CGFloat(sin(angle)) * 0.022)
            brush.mushroom(in: &context,
                           base: center,
                           height: brush.ry(0.030 + CGFloat(index % 2) * 0.008),
                           cap: Color(red: 0.80, green: 0.22, blue: 0.14),
                           capShade: Color(red: 0.50, green: 0.12, blue: 0.08),
                           stem: Color(red: 0.94, green: 0.90, blue: 0.80),
                           speckles: true,
                           seed: 800 &+ index)
        }

        // Large, dark near leaves in the top corners read as out-of-focus
        // foliage right in front of the camera.
        for index in 0..<5 {
            brush.leaf(in: &context,
                       center: brush.p(0.045 + CGFloat(index) * 0.030, 0.030 + CGFloat(index % 2) * 0.048),
                       length: brush.ry(0.115),
                       angle: 0.65 + Double(index) * 0.32,
                       color: canopyDark.opacity(0.72),
                       vein: 0.08)
            brush.leaf(in: &context,
                       center: brush.p(0.955 - CGFloat(index) * 0.030, 0.038 + CGFloat(index % 2) * 0.050),
                       length: brush.ry(0.110),
                       angle: 2.3 - Double(index) * 0.30,
                       color: canopyDark.opacity(0.68),
                       vein: 0.08)
        }
    }
}
