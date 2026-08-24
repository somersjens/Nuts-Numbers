//
//  BunnyMeadowHabitat.swift
//  Nuts & Numbers
//
//  A kitchen garden at the edge of a flower meadow: rolling hills and a
//  hedgerow behind, a picket fence across the middle distance, planted beds in
//  front of it and a burrow under the hedge on the right.
//

import SwiftUI

struct BunnyMeadowHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let skyTop = Color(red: 0.40, green: 0.71, blue: 0.94)
    private let skyLow = Color(red: 0.87, green: 0.94, blue: 0.96)
    private let hillFar = Color(red: 0.58, green: 0.74, blue: 0.54)
    private let hillNear = Color(red: 0.42, green: 0.65, blue: 0.34)
    private let hedge = Color(red: 0.20, green: 0.40, blue: 0.21)
    private let hedgeLight = Color(red: 0.34, green: 0.55, blue: 0.25)
    private let grass = Color(red: 0.38, green: 0.66, blue: 0.28)
    private let grassLight = Color(red: 0.61, green: 0.79, blue: 0.33)
    private let grassDeep = Color(red: 0.21, green: 0.43, blue: 0.20)
    private let soil = Color(red: 0.35, green: 0.25, blue: 0.16)
    private let soilLight = Color(red: 0.53, green: 0.40, blue: 0.25)
    private let wood = Color(red: 0.80, green: 0.71, blue: 0.53)
    private let woodDeep = Color(red: 0.48, green: 0.38, blue: 0.24)
    private let carrot = Color(red: 0.95, green: 0.53, blue: 0.16)

    var body: some View {
        Canvas { context, size in
            let brush = HabitatBrush(size: size, isPad: isPad)
            paintSky(brush, in: &context)
            paintHills(brush, in: &context)
            paintOrchardRow(brush, in: &context)
            paintHedgerow(brush, in: &context)
            paintMeadowFloor(brush, in: &context)
            paintPicketFence(brush, in: &context)
            paintVegetableBeds(brush, in: &context)
            paintBeanTrellis(brush, in: &context)
            paintBurrow(brush, in: &context)
            paintMeadowFlowers(brush, in: &context)
            paintCrate(brush, in: &context)
            paintAppleBranch(brush, in: &context)
            paintForeground(brush, in: &context)
        }
        .overlay {
            LinearGradient(colors: [.white.opacity(0.075),
                                    .clear,
                                    character.deepColor.opacity(0.045)],
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
                            .init(color: Color(red: 0.66, green: 0.85, blue: 0.96), location: 0.28),
                            .init(color: skyLow, location: 0.48)
                        ]),
                        startPoint: brush.p(0.4, 0),
                        endPoint: brush.p(0.6, 0.52)))

        brush.sun(in: &context,
                  center: brush.p(0.185, 0.145),
                  radius: brush.rx(0.068),
                  core: Color(red: 1.0, green: 0.97, blue: 0.80).opacity(0.78),
                  glow: Color(red: 1.0, green: 0.94, blue: 0.66).opacity(0.32),
                  glowSpread: 3.6)

        let clouds: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.36, 0.100, 0.30, 0.052), (0.70, 0.165, 0.34, 0.058),
            (0.96, 0.075, 0.26, 0.042), (0.10, 0.290, 0.24, 0.036)
        ]
        for (index, cloud) in clouds.enumerated() {
            brush.cloud(in: &context,
                        center: brush.p(cloud.0, cloud.1),
                        width: brush.rx(cloud.2),
                        height: brush.ry(cloud.3),
                        color: Color.white.opacity(0.92),
                        shade: Color(red: 0.80, green: 0.86, blue: 0.94).opacity(0.72),
                        seed: index &* 23)
        }
    }

    private func paintHills(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var far = Path()
        far.move(to: brush.p(-0.02, 0.492))
        far.addCurve(to: brush.p(0.36, 0.436),
                     control1: brush.p(0.10, 0.452),
                     control2: brush.p(0.24, 0.424))
        far.addCurve(to: brush.p(0.74, 0.470),
                     control1: brush.p(0.50, 0.450),
                     control2: brush.p(0.62, 0.486))
        far.addCurve(to: brush.p(1.02, 0.428),
                     control1: brush.p(0.86, 0.456),
                     control2: brush.p(0.95, 0.420))
        far.addLine(to: brush.p(1.02, 0.56))
        far.addLine(to: brush.p(-0.02, 0.56))
        far.closeSubpath()
        context.fill(far, with: .linearGradient(
            Gradient(colors: [hillFar, Color(red: 0.50, green: 0.68, blue: 0.44)]),
            startPoint: brush.p(0.5, 0.42),
            endPoint: brush.p(0.5, 0.55)))

        var near = Path()
        near.move(to: brush.p(-0.02, 0.532))
        near.addCurve(to: brush.p(0.44, 0.492),
                      control1: brush.p(0.14, 0.508),
                      control2: brush.p(0.30, 0.482))
        near.addCurve(to: brush.p(1.02, 0.516),
                      control1: brush.p(0.66, 0.504),
                      control2: brush.p(0.86, 0.528))
        near.addLine(to: brush.p(1.02, 0.60))
        near.addLine(to: brush.p(-0.02, 0.60))
        near.closeSubpath()
        context.fill(near, with: .linearGradient(
            Gradient(colors: [hillNear, Color(red: 0.34, green: 0.56, blue: 0.28)]),
            startPoint: brush.p(0.5, 0.49),
            endPoint: brush.p(0.5, 0.59)))

        // Field boundaries drawn as thin hedge lines following the contours.
        for index in 0..<4 {
            var boundary = Path()
            let y = 0.452 + CGFloat(index) * 0.020
            boundary.move(to: brush.p(0.02 + CGFloat(index) * 0.18, y))
            boundary.addQuadCurve(to: brush.p(0.36 + CGFloat(index) * 0.16, y + 0.024),
                                  control: brush.p(0.20 + CGFloat(index) * 0.17, y - 0.010))
            context.stroke(boundary,
                           with: .color(hedge.opacity(0.28)),
                           style: brush.stroke(brush.lw(1.6)))
        }
    }

    private func paintOrchardRow(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A line of small trees on the ridge gives the horizon scale.
        for index in 0..<11 {
            let x = 0.06 + CGFloat(index) * 0.092 + habitatNoise(index, 3, -0.014, 0.014)
            let baseY = 0.500 + habitatNoise(index, 4, -0.006, 0.006)
            let height = habitatNoise(index, 5, 0.045, 0.075)
            var stem = Path()
            stem.move(to: brush.p(x, baseY))
            stem.addLine(to: brush.p(x, baseY - height * 0.42))
            context.stroke(stem,
                           with: .color(Color(red: 0.36, green: 0.28, blue: 0.18).opacity(0.55)),
                           style: brush.stroke(brush.lw(1.3)))
            brush.crown(in: &context,
                        center: brush.p(x, baseY - height * 0.72),
                        width: brush.rx(height * 0.85),
                        height: brush.ry(height * 0.82),
                        colors: [hedge.opacity(0.68), hedgeLight.opacity(0.58), hedge.opacity(0.60)],
                        seed: 100 &+ index &* 5,
                        lobes: 4)
        }
    }

    private func paintHedgerow(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A thick hedge closing the back of the garden, taller on the right
        // where the burrow sits underneath it.
        var body = Path()
        body.move(to: brush.p(-0.02, 0.598))
        body.addCurve(to: brush.p(0.34, 0.556),
                      control1: brush.p(0.08, 0.560),
                      control2: brush.p(0.22, 0.546))
        body.addCurve(to: brush.p(0.66, 0.572),
                      control1: brush.p(0.46, 0.566),
                      control2: brush.p(0.56, 0.582))
        body.addCurve(to: brush.p(1.02, 0.512),
                      control1: brush.p(0.80, 0.560),
                      control2: brush.p(0.93, 0.502))
        body.addLine(to: brush.p(1.02, 0.660))
        body.addLine(to: brush.p(-0.02, 0.660))
        body.closeSubpath()
        context.fill(body, with: .linearGradient(
            Gradient(colors: [hedgeLight, hedge, Color(red: 0.14, green: 0.30, blue: 0.16)]),
            startPoint: brush.p(0.5, 0.52),
            endPoint: brush.p(0.5, 0.66)))

        // Leaf clumps along the top edge break the silhouette.
        for index in 0..<26 {
            let t = CGFloat(index) / 25
            let x = -0.01 + t * 1.02
            let y = 0.598 - t * 0.062 + habitatNoise(index, 11, -0.016, 0.010)
            brush.crown(in: &context,
                        center: brush.p(x, y),
                        width: brush.rx(habitatNoise(index, 12, 0.055, 0.095)),
                        height: brush.ry(habitatNoise(index, 13, 0.030, 0.052)),
                        colors: [hedgeLight, hedge, Color(red: 0.28, green: 0.50, blue: 0.22)],
                        seed: 200 &+ index &* 3,
                        lobes: 4)
        }

        // Hawthorn berries and a few white blossoms scattered through it.
        for index in 0..<18 {
            let point = brush.p(habitatNoise(index, 14, 0.02, 0.98),
                                habitatNoise(index, 15, 0.552, 0.632))
            let radius = brush.rx(0.006)
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(index.isMultiple(of: 3)
                                      ? Color(red: 0.96, green: 0.96, blue: 0.92)
                                      : Color(red: 0.82, green: 0.20, blue: 0.18)))
        }
    }

    // MARK: - Garden

    private func paintMeadowFloor(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var floor = Path()
        floor.move(to: brush.p(-0.02, 0.640))
        floor.addQuadCurve(to: brush.p(1.02, 0.628), control: brush.p(0.5, 0.664))
        floor.addLine(to: brush.p(1.02, 1.04))
        floor.addLine(to: brush.p(-0.02, 1.04))
        floor.closeSubpath()
        context.fill(floor, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.55, green: 0.76, blue: 0.34), location: 0),
                .init(color: grass, location: 0.34),
                .init(color: Color(red: 0.29, green: 0.53, blue: 0.23), location: 0.76),
                .init(color: grassDeep, location: 1)
            ]),
            startPoint: brush.p(0.5, 0.63),
            endPoint: brush.p(0.5, 1)))

        let patches: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (0.14, 0.690, 0.30, 0.055, grassLight.opacity(0.30)),
            (0.82, 0.700, 0.28, 0.060, grassDeep.opacity(0.22)),
            (0.46, 0.815, 0.42, 0.090, grassLight.opacity(0.20)),
            (0.16, 0.930, 0.36, 0.100, grassDeep.opacity(0.26))
        ]
        for (index, patch) in patches.enumerated() {
            brush.groundPatch(in: &context,
                              center: brush.p(patch.0, patch.1),
                              width: brush.rx(patch.2),
                              height: brush.ry(patch.3),
                              color: patch.4,
                              seed: 300 &+ index &* 11)
        }

        // Short clover lawn in the middle: a deliberately calm strip.
        for index in 0..<26 {
            let point = brush.p(habitatNoise(index, 21, 0.30, 0.72),
                                habitatNoise(index, 22, 0.700, 0.880))
            let radius = brush.rx(habitatNoise(index, 23, 0.005, 0.010))
            for leafIndex in 0..<3 {
                let angle = Double(leafIndex) / 3 * 2 * .pi - .pi / 2
                context.fill(Path(ellipseIn: CGRect(x: point.x + CGFloat(cos(angle)) * radius - radius * 0.6,
                                                    y: point.y + CGFloat(sin(angle)) * radius * 0.7 - radius * 0.5,
                                                    width: radius * 1.2,
                                                    height: radius)),
                             with: .color(grassLight.opacity(0.55)))
            }
        }
    }

    private func paintPicketFence(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // The fence runs across the garden and turns toward the viewer on the
        // left, which is what gives the flat bed area a sense of enclosure.
        let baseY: CGFloat = 0.652
        var rail = Path()
        rail.move(to: brush.p(-0.02, baseY - 0.030))
        rail.addQuadCurve(to: brush.p(1.02, baseY - 0.044), control: brush.p(0.5, baseY - 0.022))
        context.stroke(rail, with: .color(woodDeep.opacity(0.6)), style: brush.stroke(brush.lw(3.6)))
        context.stroke(rail, with: .color(wood), style: brush.stroke(brush.lw(2.6)))

        for index in 0..<22 {
            let t = CGFloat(index) / 21
            let x = -0.01 + t * 1.02
            let height = 0.075 - t * 0.012
            let top = baseY - height + habitatNoise(index, 31, -0.004, 0.004)
            var picket = Path()
            picket.move(to: brush.p(x - 0.0115, baseY))
            picket.addLine(to: brush.p(x - 0.0115, top + 0.010))
            picket.addLine(to: brush.p(x, top))
            picket.addLine(to: brush.p(x + 0.0115, top + 0.010))
            picket.addLine(to: brush.p(x + 0.0115, baseY))
            picket.closeSubpath()
            context.fill(picket, with: .linearGradient(
                Gradient(colors: [Color(red: 0.92, green: 0.88, blue: 0.78), wood, woodDeep]),
                startPoint: brush.p(x - 0.012, top),
                endPoint: brush.p(x + 0.012, baseY)))
            context.stroke(picket, with: .color(woodDeep.opacity(0.5)), style: brush.joined(brush.lw(0.7)))
        }

        // Contact shadows so the fence stands in the grass rather than on it.
        for index in 0..<22 {
            let x = -0.01 + CGFloat(index) / 21 * 1.02
            brush.contactShadow(in: &context,
                                center: brush.p(x, baseY + 0.004),
                                width: brush.rx(0.034),
                                height: brush.ry(0.014),
                                opacity: 0.24)
        }

        // A leaning gate post with a coil of twine at the left end.
        brush.plank(in: &context,
                    from: brush.p(0.055, 0.560),
                    to: brush.p(0.048, 0.700),
                    thickness: brush.rx(0.030),
                    wood: wood,
                    woodLight: Color(red: 0.93, green: 0.89, blue: 0.79),
                    woodDeep: woodDeep)
        for index in 0..<3 {
            let radius = brush.rx(0.020 - CGFloat(index) * 0.004)
            context.stroke(Path(ellipseIn: CGRect(x: brush.rx(0.052) - radius,
                                                  y: brush.ry(0.596) + CGFloat(index) * brush.ry(0.012) - radius * 0.4,
                                                  width: radius * 2,
                                                  height: radius * 0.8)),
                           with: .color(Color(red: 0.78, green: 0.70, blue: 0.48)),
                           style: brush.stroke(brush.lw(1.2)))
        }
    }

    private func paintVegetableBeds(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Three tilled rows stepping toward the viewer. Each row carries a
        // different crop so the garden reads as planted, not decorated.
        let rows: [(CGFloat, CGFloat, CGFloat, Int)] = [
            (0.700, 0.026, 0.86, 9),
            (0.790, 0.034, 0.94, 8),
            (0.910, 0.044, 1.02, 7)
        ]
        for (rowIndex, row) in rows.enumerated() {
            var bed = Path()
            bed.move(to: brush.p(0.5 - row.2 * 0.5, row.0 + row.1))
            bed.addQuadCurve(to: brush.p(0.5 + row.2 * 0.5, row.0 + row.1),
                             control: brush.p(0.5, row.0 + row.1 * 1.5))
            bed.addQuadCurve(to: brush.p(0.5 - row.2 * 0.5, row.0 + row.1),
                             control: brush.p(0.5, row.0 - row.1 * 1.2))
            bed.closeSubpath()
            context.fill(bed, with: .linearGradient(
                Gradient(colors: [soilLight, soil]),
                startPoint: brush.p(0.5, row.0 - row.1),
                endPoint: brush.p(0.5, row.0 + row.1 * 1.4)))

            // Clods and rake lines in the soil.
            for index in 0..<16 {
                let x = 0.5 - row.2 * 0.48 + habitatNoise(rowIndex &* 40 &+ index, 41) * row.2 * 0.96
                let y = row.0 + habitatNoise(rowIndex &* 40 &+ index, 42, -0.6, 0.9) * row.1
                let radius = brush.rx(habitatNoise(rowIndex &* 40 &+ index, 43, 0.004, 0.010))
                context.fill(Path(ellipseIn: CGRect(x: x * brush.w - radius, y: y * brush.h - radius * 0.7,
                                                    width: radius * 2, height: radius * 1.4)),
                             with: .color(index.isMultiple(of: 2)
                                          ? Color.black.opacity(0.18)
                                          : soilLight.opacity(0.55)))
            }

            for index in 0..<row.3 {
                let t = CGFloat(index) / CGFloat(row.3 - 1)
                let x = 0.5 - row.2 * 0.44 + t * row.2 * 0.88
                let base = brush.p(x, row.0)
                switch rowIndex {
                case 0:
                    paintCabbage(brush, in: &context, center: base, radius: brush.rx(0.030), seed: index)
                case 1:
                    paintCarrotTop(brush, in: &context, base: base, height: brush.ry(0.062), seed: index)
                default:
                    paintLettuce(brush, in: &context, center: base, radius: brush.rx(0.036), seed: index)
                }
            }
        }

        // Two pulled carrots lying on the near soil, roots showing.
        for index in 0..<2 {
            let center = brush.p(index == 0 ? 0.335 : 0.615, index == 0 ? 0.952 : 0.975)
            let angle: Double = index == 0 ? 0.32 : -0.24
            var root = Path()
            root.move(to: CGPoint(x: center.x - CGFloat(cos(angle)) * brush.rx(0.048),
                                  y: center.y - CGFloat(sin(angle)) * brush.rx(0.048)))
            root.addQuadCurve(to: CGPoint(x: center.x + CGFloat(cos(angle)) * brush.rx(0.048),
                                          y: center.y + CGFloat(sin(angle)) * brush.rx(0.048)),
                              control: CGPoint(x: center.x, y: center.y - brush.ry(0.020)))
            root.addQuadCurve(to: CGPoint(x: center.x - CGFloat(cos(angle)) * brush.rx(0.048),
                                          y: center.y - CGFloat(sin(angle)) * brush.rx(0.048)),
                              control: CGPoint(x: center.x, y: center.y + brush.ry(0.020)))
            root.closeSubpath()
            context.fill(root, with: .linearGradient(
                Gradient(colors: [Color(red: 0.99, green: 0.68, blue: 0.30), carrot]),
                startPoint: CGPoint(x: center.x, y: center.y - brush.ry(0.02)),
                endPoint: CGPoint(x: center.x, y: center.y + brush.ry(0.02))))
            for frondIndex in 0..<4 {
                brush.leaf(in: &context,
                           center: CGPoint(x: center.x - CGFloat(cos(angle)) * brush.rx(0.070),
                                           y: center.y - CGFloat(sin(angle)) * brush.rx(0.070)
                                              - brush.ry(0.008) * CGFloat(frondIndex)),
                           length: brush.ry(0.048),
                           angle: .pi + angle + Double(frondIndex - 2) * 0.28,
                           color: Color(red: 0.31, green: 0.57, blue: 0.22),
                           vein: 0.12)
            }
        }
    }

    private func paintCabbage(_ brush: HabitatBrush,
                              in context: inout GraphicsContext,
                              center: CGPoint,
                              radius: CGFloat,
                              seed: Int) {
        brush.contactShadow(in: &context,
                            center: CGPoint(x: center.x, y: center.y + radius * 0.2),
                            width: radius * 2.4, height: radius * 0.7, opacity: 0.22)
        for index in 0..<6 {
            let angle = Double(index) / 6 * 2 * .pi
            brush.leaf(in: &context,
                       center: CGPoint(x: center.x + CGFloat(cos(angle)) * radius * 0.52,
                                       y: center.y + CGFloat(sin(angle)) * radius * 0.32 - radius * 0.18),
                       length: radius * 1.5,
                       angle: angle,
                       color: Color(red: 0.42, green: 0.66, blue: 0.34).opacity(0.92),
                       vein: 0.14)
        }
        let points = brush.blobPoints(center: CGPoint(x: center.x, y: center.y - radius * 0.34),
                                      radiusX: radius * 0.66,
                                      radiusY: radius * 0.58,
                                      count: 8,
                                      irregularity: 0.18,
                                      seed: 900 &+ seed)
        context.fill(brush.blob(points), with: .linearGradient(
            Gradient(colors: [Color(red: 0.72, green: 0.84, blue: 0.52), Color(red: 0.40, green: 0.60, blue: 0.30)]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y)))
    }

    private func paintCarrotTop(_ brush: HabitatBrush,
                                in context: inout GraphicsContext,
                                base: CGPoint,
                                height: CGFloat,
                                seed: Int) {
        brush.contactShadow(in: &context, center: base,
                            width: height * 0.9, height: height * 0.22, opacity: 0.20)
        // A sliver of orange shoulder showing above the soil.
        context.fill(Path(ellipseIn: CGRect(x: base.x - height * 0.14,
                                            y: base.y - height * 0.10,
                                            width: height * 0.28,
                                            height: height * 0.18)),
                     with: .color(carrot))
        for index in 0..<7 {
            let spread = (CGFloat(index) / 6 - 0.5) * height * 0.85
            let tip = CGPoint(x: base.x + spread, y: base.y - height * habitatNoise(seed &+ index, 51, 0.62, 1.05))
            var stalk = Path()
            stalk.move(to: CGPoint(x: base.x, y: base.y - height * 0.05))
            stalk.addQuadCurve(to: tip, control: CGPoint(x: base.x + spread * 0.3, y: base.y - height * 0.55))
            context.stroke(stalk,
                           with: .color(Color(red: 0.28, green: 0.52, blue: 0.20)),
                           style: brush.stroke(brush.lw(1.0)))
            brush.leaf(in: &context,
                       center: tip,
                       length: height * 0.34,
                       angle: -.pi / 2 + Double(spread / height) * 1.6,
                       color: Color(red: 0.36, green: 0.62, blue: 0.24),
                       vein: 0)
        }
    }

    private func paintLettuce(_ brush: HabitatBrush,
                              in context: inout GraphicsContext,
                              center: CGPoint,
                              radius: CGFloat,
                              seed: Int) {
        brush.contactShadow(in: &context,
                            center: CGPoint(x: center.x, y: center.y + radius * 0.18),
                            width: radius * 2.2, height: radius * 0.62, opacity: 0.22)
        for index in 0..<8 {
            let angle = Double(index) / 8 * 2 * .pi + Double(habitatNoise(seed, 61)) * 0.5
            let length = radius * habitatNoise(seed &+ index, 62, 1.0, 1.5)
            brush.leaf(in: &context,
                       center: CGPoint(x: center.x + CGFloat(cos(angle)) * length * 0.36,
                                       y: center.y + CGFloat(sin(angle)) * length * 0.24 - radius * 0.16),
                       length: length,
                       angle: angle,
                       color: index.isMultiple(of: 2)
                            ? Color(red: 0.62, green: 0.80, blue: 0.36)
                            : Color(red: 0.44, green: 0.68, blue: 0.28),
                       vein: 0.16)
        }
    }

    private func paintBeanTrellis(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A cane wigwam on the right with beans climbing it, tall enough to
        // give that side of the frame real height.
        let apex = brush.p(0.858, 0.395)
        let feet: [CGFloat] = [0.760, 0.812, 0.870, 0.925, 0.965]
        for (index, foot) in feet.enumerated() {
            let base = brush.p(foot, 0.700 + CGFloat(index % 2) * 0.014)
            var cane = Path()
            cane.move(to: base)
            cane.addQuadCurve(to: apex,
                              control: CGPoint(x: (base.x + apex.x) * 0.5 + brush.rx(0.006),
                                               y: (base.y + apex.y) * 0.5))
            context.stroke(cane, with: .color(Color.black.opacity(0.18)), style: brush.stroke(brush.lw(2.6)))
            context.stroke(cane,
                           with: .color(Color(red: 0.78, green: 0.68, blue: 0.42)),
                           style: brush.stroke(brush.lw(1.8)))

            // A bean vine spiralling up each cane.
            for step in 0..<8 {
                let t = CGFloat(step) / 8
                let point = CGPoint(x: base.x + (apex.x - base.x) * t,
                                    y: base.y + (apex.y - base.y) * t)
                let side: CGFloat = step.isMultiple(of: 2) ? 1 : -1
                brush.leaf(in: &context,
                           center: CGPoint(x: point.x + side * brush.rx(0.020),
                                           y: point.y - brush.ry(0.004)),
                           length: brush.ry(0.042),
                           angle: side > 0 ? -0.30 : .pi + 0.30,
                           color: index.isMultiple(of: 2)
                                ? Color(red: 0.30, green: 0.55, blue: 0.24)
                                : Color(red: 0.40, green: 0.64, blue: 0.26),
                           vein: 0.14)
                if step % 3 == 1 {
                    var pod = Path()
                    pod.move(to: CGPoint(x: point.x + side * brush.rx(0.010), y: point.y))
                    pod.addQuadCurve(to: CGPoint(x: point.x + side * brush.rx(0.016),
                                                 y: point.y + brush.ry(0.044)),
                                     control: CGPoint(x: point.x + side * brush.rx(0.030),
                                                      y: point.y + brush.ry(0.022)))
                    context.stroke(pod,
                                   with: .color(Color(red: 0.44, green: 0.68, blue: 0.24)),
                                   style: brush.stroke(brush.lw(1.8)))
                }
            }
        }
        // Twine binding at the apex.
        for index in 0..<3 {
            let radius = brush.rx(0.020 + CGFloat(index) * 0.005)
            context.stroke(Path(ellipseIn: CGRect(x: apex.x - radius,
                                                  y: apex.y + CGFloat(index) * brush.ry(0.010) - radius * 0.3,
                                                  width: radius * 2,
                                                  height: radius * 0.6)),
                           with: .color(Color(red: 0.86, green: 0.80, blue: 0.60)),
                           style: brush.stroke(brush.lw(1.2)))
        }
    }

    private func paintBurrow(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // The entrance under the hedge: a dark hole with a fan of loose earth
        // and a well-worn run leading away from it.
        let mouth = brush.p(0.170, 0.648)
        var spoil = Path()
        spoil.move(to: CGPoint(x: mouth.x - brush.rx(0.090), y: mouth.y + brush.ry(0.040)))
        spoil.addQuadCurve(to: CGPoint(x: mouth.x + brush.rx(0.090), y: mouth.y + brush.ry(0.038)),
                           control: CGPoint(x: mouth.x, y: mouth.y - brush.ry(0.014)))
        spoil.addQuadCurve(to: CGPoint(x: mouth.x - brush.rx(0.090), y: mouth.y + brush.ry(0.040)),
                           control: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.090)))
        spoil.closeSubpath()
        context.fill(spoil, with: .linearGradient(
            Gradient(colors: [soilLight, soil]),
            startPoint: CGPoint(x: mouth.x, y: mouth.y),
            endPoint: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.08))))

        var hole = Path()
        hole.move(to: CGPoint(x: mouth.x - brush.rx(0.048), y: mouth.y + brush.ry(0.026)))
        hole.addCurve(to: CGPoint(x: mouth.x + brush.rx(0.048), y: mouth.y + brush.ry(0.024)),
                      control1: CGPoint(x: mouth.x - brush.rx(0.052), y: mouth.y - brush.ry(0.034)),
                      control2: CGPoint(x: mouth.x + brush.rx(0.052), y: mouth.y - brush.ry(0.036)))
        hole.addQuadCurve(to: CGPoint(x: mouth.x - brush.rx(0.048), y: mouth.y + brush.ry(0.026)),
                          control: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.042)))
        hole.closeSubpath()
        context.fill(hole, with: .radialGradient(
            Gradient(colors: [Color.black.opacity(0.92), Color(red: 0.16, green: 0.11, blue: 0.07)]),
            center: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.010)),
            startRadius: 0,
            endRadius: brush.rx(0.06)))

        // A worn run through the grass leading toward the beds.
        var run = Path()
        run.move(to: CGPoint(x: mouth.x, y: mouth.y + brush.ry(0.042)))
        run.addCurve(to: brush.p(0.300, 0.885),
                     control1: brush.p(0.150, 0.740),
                     control2: brush.p(0.215, 0.820))
        context.stroke(run,
                       with: .color(Color(red: 0.55, green: 0.48, blue: 0.28).opacity(0.42)),
                       style: brush.stroke(brush.rx(0.038)))
    }

    private func paintMeadowFlowers(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        let blooms: [(CGFloat, CGFloat, CGFloat, Color, Color, Int)] = [
            (0.045, 0.735, 0.090, Color(red: 0.94, green: 0.36, blue: 0.30), Color(red: 0.90, green: 0.82, blue: 0.30), 6),
            (0.115, 0.775, 0.105, Color(red: 0.98, green: 0.98, blue: 0.94), Color(red: 0.98, green: 0.82, blue: 0.26), 8),
            (0.215, 0.740, 0.082, Color(red: 0.42, green: 0.48, blue: 0.86), Color(red: 0.96, green: 0.90, blue: 0.44), 6),
            (0.930, 0.760, 0.098, Color(red: 0.96, green: 0.64, blue: 0.76), Color(red: 0.94, green: 0.84, blue: 0.32), 7),
            (0.855, 0.800, 0.086, Color(red: 0.98, green: 0.98, blue: 0.94), Color(red: 0.98, green: 0.80, blue: 0.24), 8),
            (0.760, 0.760, 0.076, Color(red: 0.86, green: 0.42, blue: 0.86), Color(red: 0.96, green: 0.88, blue: 0.40), 6),
            (0.300, 0.700, 0.058, Color(red: 0.98, green: 0.86, blue: 0.36), Color(red: 0.78, green: 0.54, blue: 0.14), 6),
            (0.690, 0.706, 0.062, Color(red: 0.96, green: 0.96, blue: 0.92), Color(red: 0.96, green: 0.78, blue: 0.24), 7)
        ]
        for (index, bloom) in blooms.enumerated() {
            brush.flower(in: &context,
                         base: brush.p(bloom.0, bloom.1),
                         height: brush.ry(bloom.2),
                         stem: Color(red: 0.28, green: 0.52, blue: 0.22),
                         petal: bloom.3,
                         heart: bloom.4,
                         petals: bloom.5,
                         seed: 1000 &+ index &* 7,
                         lean: index.isMultiple(of: 2) ? 0.08 : -0.07)
        }

        // Hollyhock spires framing the left edge.
        for index in 0..<2 {
            let base = brush.p(0.022 + CGFloat(index) * 0.052, 0.905 - CGFloat(index) * 0.045)
            let height = brush.ry(0.36 - CGFloat(index) * 0.05)
            var stalk = Path()
            stalk.move(to: base)
            stalk.addQuadCurve(to: CGPoint(x: base.x + brush.rx(0.018), y: base.y - height),
                               control: CGPoint(x: base.x - brush.rx(0.010), y: base.y - height * 0.55))
            context.stroke(stalk,
                           with: .color(Color(red: 0.26, green: 0.48, blue: 0.20)),
                           style: brush.stroke(brush.lw(2.2)))
            for flowerIndex in 0..<6 {
                let t = CGFloat(flowerIndex) / 5
                let point = CGPoint(x: base.x + brush.rx(0.018) * t * t,
                                    y: base.y - height * (0.30 + t * 0.66))
                let radius = brush.rx(0.026 - CGFloat(flowerIndex) * 0.002)
                for petalIndex in 0..<5 {
                    let angle = Double(petalIndex) / 5 * 2 * .pi
                    brush.leaf(in: &context,
                               center: CGPoint(x: point.x + CGFloat(cos(angle)) * radius * 0.5,
                                               y: point.y + CGFloat(sin(angle)) * radius * 0.5),
                               length: radius * 1.2,
                               angle: angle,
                               color: index == 0
                                    ? Color(red: 0.96, green: 0.60, blue: 0.72)
                                    : Color(red: 0.90, green: 0.44, blue: 0.52),
                               vein: 0)
                }
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius * 0.22, y: point.y - radius * 0.22,
                                                    width: radius * 0.44, height: radius * 0.44)),
                             with: .color(Color(red: 0.98, green: 0.90, blue: 0.52)))
            }
        }
    }

    private func paintCrate(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A harvest crate on the near grass, holding a few carrots.
        let rect = CGRect(x: brush.rx(0.148), y: brush.ry(0.858),
                          width: brush.rx(0.185), height: brush.ry(0.100))
        brush.contactShadow(in: &context,
                            center: CGPoint(x: rect.midX, y: rect.maxY),
                            width: rect.width * 1.3,
                            height: rect.height * 0.42,
                            opacity: 0.30)
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [wood, woodDeep]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        for index in 0..<3 {
            let y = rect.minY + rect.height * (0.24 + CGFloat(index) * 0.30)
            var slat = Path()
            slat.move(to: CGPoint(x: rect.minX, y: y))
            slat.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.stroke(slat, with: .color(woodDeep.opacity(0.72)), style: brush.stroke(brush.lw(1.2)))
        }
        for index in 0..<2 {
            var post = Path()
            let x = index == 0 ? rect.minX + rect.width * 0.06 : rect.maxX - rect.width * 0.06
            post.move(to: CGPoint(x: x, y: rect.minY))
            post.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.stroke(post, with: .color(Color(red: 0.90, green: 0.84, blue: 0.68)),
                           style: brush.stroke(brush.lw(2.0)))
        }
        for index in 0..<3 {
            let center = CGPoint(x: rect.minX + rect.width * (0.26 + CGFloat(index) * 0.24),
                                 y: rect.minY - brush.ry(0.006))
            context.fill(Path(ellipseIn: CGRect(x: center.x - brush.rx(0.018),
                                                y: center.y - brush.ry(0.012),
                                                width: brush.rx(0.036),
                                                height: brush.ry(0.024))),
                         with: .color(carrot))
            for frondIndex in 0..<3 {
                brush.leaf(in: &context,
                           center: CGPoint(x: center.x, y: center.y - brush.ry(0.026)),
                           length: brush.ry(0.044),
                           angle: -.pi / 2 + Double(frondIndex - 1) * 0.42,
                           color: Color(red: 0.32, green: 0.58, blue: 0.22),
                           vein: 0.10)
            }
        }
    }

    private func paintAppleBranch(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // An apple bough leaning in from the top-left, with a second, smaller
        // branch on the right so the top of the frame is balanced.
        let boughs: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.02, 0.055, 0.20, 0.020, 0.46, 0.115, 0.026),
            (1.02, 0.090, 0.86, 0.040, 0.66, 0.140, 0.020)
        ]
        for bough in boughs {
            var path = Path()
            path.move(to: brush.p(bough.0, bough.1))
            path.addQuadCurve(to: brush.p(bough.4, bough.5), control: brush.p(bough.2, bough.3))
            context.stroke(path,
                           with: .linearGradient(Gradient(colors: [Color(red: 0.34, green: 0.25, blue: 0.16),
                                                                   Color(red: 0.56, green: 0.43, blue: 0.27)]),
                                                 startPoint: brush.p(bough.0, bough.1),
                                                 endPoint: brush.p(bough.4, bough.5)),
                           style: brush.stroke(brush.rx(bough.6)))
        }

        let masses: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.04, 0.030, 0.28, 0.14), (0.20, 0.005, 0.26, 0.13), (0.38, 0.055, 0.22, 0.11),
            (0.97, 0.045, 0.24, 0.13), (0.82, 0.020, 0.22, 0.12), (0.68, 0.080, 0.18, 0.09)
        ]
        for (index, mass) in masses.enumerated() {
            brush.crown(in: &context,
                        center: brush.p(mass.0, mass.1),
                        width: brush.rx(mass.2),
                        height: brush.ry(mass.3),
                        colors: [Color(red: 0.30, green: 0.53, blue: 0.24),
                                 Color(red: 0.44, green: 0.67, blue: 0.27),
                                 Color(red: 0.22, green: 0.42, blue: 0.20)],
                        seed: 1100 &+ index &* 9,
                        lobes: 5)
        }

        let apples: [(CGFloat, CGFloat)] = [
            (0.115, 0.098), (0.245, 0.075), (0.355, 0.115), (0.895, 0.100), (0.755, 0.088)
        ]
        for (index, apple) in apples.enumerated() {
            let center = brush.p(apple.0, apple.1)
            let radius = brush.rx(0.021)
            var stalk = Path()
            stalk.move(to: CGPoint(x: center.x, y: center.y - radius))
            stalk.addLine(to: CGPoint(x: center.x + radius * 0.2, y: center.y - radius * 1.7))
            context.stroke(stalk, with: .color(Color(red: 0.40, green: 0.30, blue: 0.16)),
                           style: brush.stroke(brush.lw(1.0)))
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .radialGradient(
                            Gradient(colors: [Color(red: 0.95, green: 0.42, blue: 0.30),
                                              Color(red: 0.70, green: 0.14, blue: 0.14)]),
                            center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.35),
                            startRadius: 0,
                            endRadius: radius * 1.5))
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.5, y: center.y - radius * 0.6,
                                                width: radius * 0.4, height: radius * 0.3)),
                         with: .color(Color.white.opacity(0.42)))
            _ = index
        }
    }

    private func paintForeground(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Tall meadow grass and seed heads crop the bottom corners.
        for index in 0..<6 {
            brush.grassTuft(in: &context,
                            base: brush.p(0.01 + CGFloat(index) * 0.042, 1.01),
                            height: brush.ry(0.145 + CGFloat(index % 3) * 0.030),
                            width: brush.rx(0.100),
                            colors: [grassDeep, Color(red: 0.30, green: 0.54, blue: 0.22), grass],
                            bladeCount: 11,
                            seed: 1200 &+ index,
                            shadow: 0)
            brush.grassTuft(in: &context,
                            base: brush.p(0.72 + CGFloat(index) * 0.055, 1.02),
                            height: brush.ry(0.155 + CGFloat(index % 3) * 0.028),
                            width: brush.rx(0.105),
                            colors: [grassDeep, Color(red: 0.28, green: 0.52, blue: 0.21), grass],
                            bladeCount: 11,
                            seed: 1250 &+ index,
                            shadow: 0)
        }

        // Grass seed heads on tall stems, drawn last so they sit in front.
        for index in 0..<9 {
            let base = brush.p(habitatNoise(index, 71, 0.02, 0.98), 1.005)
            let height = brush.ry(habitatNoise(index, 72, 0.14, 0.24))
            let lean = brush.rx(habitatNoise(index, 73, -0.030, 0.030))
            let tip = CGPoint(x: base.x + lean, y: base.y - height)
            var stem = Path()
            stem.move(to: base)
            stem.addQuadCurve(to: tip, control: CGPoint(x: base.x + lean * 0.2, y: base.y - height * 0.6))
            context.stroke(stem,
                           with: .color(Color(red: 0.42, green: 0.56, blue: 0.24)),
                           style: brush.stroke(brush.lw(1.1)))
            for seedIndex in 0..<5 {
                let t = CGFloat(seedIndex) / 4
                let point = CGPoint(x: tip.x - lean * t * 0.3, y: tip.y + height * 0.16 * t)
                let side: CGFloat = seedIndex.isMultiple(of: 2) ? 1 : -1
                context.fill(Path(ellipseIn: CGRect(x: point.x + side * brush.rx(0.005) - brush.rx(0.005),
                                                    y: point.y - brush.ry(0.008),
                                                    width: brush.rx(0.010),
                                                    height: brush.ry(0.016))),
                             with: .color(Color(red: 0.68, green: 0.70, blue: 0.36).opacity(0.88)))
            }
        }
    }
}
