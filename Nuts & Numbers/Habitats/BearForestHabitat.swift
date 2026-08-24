//
//  BearForestHabitat.swift
//  Nuts & Numbers
//
//  A mountain valley: snow ridges in the far distance, a spruce forest on the
//  slopes and a salmon river running out of the rocks toward the viewer. The
//  river keeps the middle of the cabinet calm while the banks, trunks and
//  canopy carry the detail.
//

import SwiftUI

struct BearForestHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let skyTop = Color(red: 0.40, green: 0.66, blue: 0.86)
    private let skyLow = Color(red: 0.85, green: 0.90, blue: 0.86)
    private let ridgeFar = Color(red: 0.58, green: 0.67, blue: 0.79)
    private let ridgeNear = Color(red: 0.36, green: 0.47, blue: 0.50)
    private let snow = Color(red: 0.95, green: 0.97, blue: 0.99)
    private let forestFar = Color(red: 0.21, green: 0.35, blue: 0.31)
    private let needle = Color(red: 0.14, green: 0.32, blue: 0.22)
    private let needleLight = Color(red: 0.27, green: 0.48, blue: 0.26)
    private let grass = Color(red: 0.29, green: 0.47, blue: 0.23)
    private let grassLight = Color(red: 0.47, green: 0.63, blue: 0.27)
    private let moss = Color(red: 0.33, green: 0.52, blue: 0.21)
    private let soil = Color(red: 0.28, green: 0.22, blue: 0.15)
    private let soilLight = Color(red: 0.47, green: 0.37, blue: 0.23)
    private let bark = Color(red: 0.29, green: 0.19, blue: 0.12)
    private let barkLight = Color(red: 0.52, green: 0.37, blue: 0.23)
    private let stone = Color(red: 0.58, green: 0.58, blue: 0.54)
    private let stoneDark = Color(red: 0.23, green: 0.25, blue: 0.25)
    private let water = Color(red: 0.40, green: 0.66, blue: 0.72)
    private let waterDeep = Color(red: 0.12, green: 0.33, blue: 0.44)

    var body: some View {
        Canvas { context, size in
            let brush = HabitatBrush(size: size, isPad: isPad)
            paintSky(brush, in: &context)
            paintMountains(brush, in: &context)
            paintDistantForest(brush, in: &context)
            paintValleyFloor(brush, in: &context)
            paintRiver(brush, in: &context)
            paintCascade(brush, in: &context)
            paintRiverbank(brush, in: &context)
            paintGroundCover(brush, in: &context)
            paintBerryThicket(brush, in: &context)
            paintFallenLog(brush, in: &context)
            paintFrameTrees(brush, in: &context)
            paintCanopy(brush, in: &context)
            paintBeehive(brush, in: &context)
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

    // MARK: - Distance

    private func paintSky(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        context.fill(Path(CGRect(origin: .zero, size: brush.size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: skyTop, location: 0),
                            .init(color: Color(red: 0.63, green: 0.79, blue: 0.89), location: 0.24),
                            .init(color: skyLow, location: 0.44)
                        ]),
                        startPoint: brush.p(0.4, 0),
                        endPoint: brush.p(0.6, 0.46)))

        brush.sun(in: &context,
                  center: brush.p(0.795, 0.135),
                  radius: brush.rx(0.058),
                  core: Color(red: 1.0, green: 0.98, blue: 0.88).opacity(0.72),
                  glow: Color(red: 1.0, green: 0.96, blue: 0.80).opacity(0.30),
                  glowSpread: 3.8)

        let clouds: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.20, 0.115, 0.34, 0.055), (0.62, 0.075, 0.26, 0.040), (0.90, 0.185, 0.28, 0.045)
        ]
        for (index, cloud) in clouds.enumerated() {
            brush.cloud(in: &context,
                        center: brush.p(cloud.0, cloud.1),
                        width: brush.rx(cloud.2),
                        height: brush.ry(cloud.3),
                        color: Color.white.opacity(0.80),
                        shade: Color(red: 0.80, green: 0.86, blue: 0.92).opacity(0.60),
                        seed: index &* 17)
        }
    }

    private func paintMountains(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Far range: pale, high, mostly haze.
        var far = Path()
        far.move(to: brush.p(-0.02, 0.415))
        far.addLine(to: brush.p(0.10, 0.255))
        far.addLine(to: brush.p(0.18, 0.320))
        far.addLine(to: brush.p(0.30, 0.185))
        far.addLine(to: brush.p(0.44, 0.315))
        far.addLine(to: brush.p(0.56, 0.230))
        far.addLine(to: brush.p(0.70, 0.335))
        far.addLine(to: brush.p(0.84, 0.245))
        far.addLine(to: brush.p(1.02, 0.395))
        far.addLine(to: brush.p(1.02, 0.50))
        far.addLine(to: brush.p(-0.02, 0.50))
        far.closeSubpath()
        context.fill(far, with: .linearGradient(
            Gradient(colors: [ridgeFar.opacity(0.92), ridgeFar.opacity(0.42)]),
            startPoint: brush.p(0.5, 0.18),
            endPoint: brush.p(0.5, 0.46)))

        // Snow caps follow the peaks rather than sitting on top as white blobs.
        let peaks: [(CGFloat, CGFloat, CGFloat)] = [
            (0.10, 0.255, 0.055), (0.30, 0.185, 0.075), (0.56, 0.230, 0.062), (0.84, 0.245, 0.058)
        ]
        for peak in peaks {
            var cap = Path()
            cap.move(to: brush.p(peak.0 - peak.2, peak.1 + 0.062))
            cap.addLine(to: brush.p(peak.0, peak.1))
            cap.addLine(to: brush.p(peak.0 + peak.2, peak.1 + 0.066))
            cap.addQuadCurve(to: brush.p(peak.0 + peak.2 * 0.34, peak.1 + 0.040),
                             control: brush.p(peak.0 + peak.2 * 0.68, peak.1 + 0.030))
            cap.addQuadCurve(to: brush.p(peak.0 - peak.2 * 0.28, peak.1 + 0.048),
                             control: brush.p(peak.0, peak.1 + 0.072))
            cap.closeSubpath()
            context.fill(cap, with: .linearGradient(
                Gradient(colors: [snow, Color(red: 0.78, green: 0.85, blue: 0.92)]),
                startPoint: brush.p(peak.0, peak.1),
                endPoint: brush.p(peak.0, peak.1 + 0.07)))
        }

        // Near range: darker, closer, with gullies.
        var near = Path()
        near.move(to: brush.p(-0.02, 0.470))
        near.addLine(to: brush.p(0.14, 0.365))
        near.addLine(to: brush.p(0.26, 0.425))
        near.addLine(to: brush.p(0.40, 0.340))
        near.addLine(to: brush.p(0.52, 0.408))
        near.addLine(to: brush.p(0.66, 0.352))
        near.addLine(to: brush.p(0.80, 0.418))
        near.addLine(to: brush.p(0.93, 0.360))
        near.addLine(to: brush.p(1.02, 0.440))
        near.addLine(to: brush.p(1.02, 0.55))
        near.addLine(to: brush.p(-0.02, 0.55))
        near.closeSubpath()
        context.fill(near, with: .linearGradient(
            Gradient(colors: [ridgeNear.opacity(0.95), Color(red: 0.30, green: 0.42, blue: 0.38)]),
            startPoint: brush.p(0.5, 0.34),
            endPoint: brush.p(0.5, 0.52)))

        // Gullies are shaded wedges hanging off the ridge notches, not drawn
        // lines: a row of evenly spaced strokes on a flat slope reads as
        // scratches on the artwork rather than as terrain.
        let notches: [CGFloat] = [0.14, 0.26, 0.40, 0.52, 0.66, 0.80, 0.93]
        for (index, notch) in notches.enumerated() {
            let top = 0.372 + habitatNoise(index, 3, 0, 0.045)
            let spread = habitatNoise(index, 4, 0.016, 0.038)
            let bottom = 0.470 + habitatNoise(index, 5, 0, 0.040)
            var gully = Path()
            gully.move(to: brush.p(notch, top))
            gully.addQuadCurve(to: brush.p(notch - spread, bottom),
                               control: brush.p(notch - spread * 0.35, (top + bottom) * 0.5))
            gully.addLine(to: brush.p(notch + spread * 0.55, bottom))
            gully.addQuadCurve(to: brush.p(notch, top),
                               control: brush.p(notch + spread * 0.30, (top + bottom) * 0.5))
            gully.closeSubpath()
            context.fill(gully, with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0.13), Color.black.opacity(0.02)]),
                startPoint: brush.p(notch, top),
                endPoint: brush.p(notch, bottom)))
        }

        brush.hazeBand(in: &context, top: 0.400, bottom: 0.505, color: Color.white.opacity(0.30))
    }

    private func paintDistantForest(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Two bands of spruce: the rear one pale and flat, the front one with
        // enough silhouette variation to read as individual trees.
        for band in 0..<2 {
            let baseY: CGFloat = band == 0 ? 0.498 : 0.535
            let scale: CGFloat = band == 0 ? 0.070 : 0.105
            let color = band == 0 ? forestFar.opacity(0.62) : forestFar
            let light = band == 0 ? forestFar.opacity(0.50) : Color(red: 0.26, green: 0.42, blue: 0.30)
            let count = band == 0 ? 21 : 15
            for index in 0..<count {
                let x = -0.02 + CGFloat(index) / CGFloat(count - 1) * 1.04
                    + habitatNoise(index &+ band &* 50, 5, -0.014, 0.014)
                brush.conifer(in: &context,
                              base: brush.p(x, baseY + habitatNoise(index, 6, -0.006, 0.006)),
                              height: brush.ry(scale * habitatNoise(index &+ band &* 50, 7, 0.72, 1.28)),
                              width: brush.rx(scale * 0.42),
                              needle: color,
                              needleLight: light,
                              trunk: nil,
                              seed: index &* 3 &+ band,
                              tiers: band == 0 ? 4 : 5)
            }
        }
        brush.hazeBand(in: &context, top: 0.470, bottom: 0.540, color: Color.white.opacity(0.20))
    }

    // MARK: - Valley

    private func paintValleyFloor(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var floor = Path()
        floor.move(to: brush.p(0, 0.530))
        floor.addQuadCurve(to: brush.p(1, 0.522), control: brush.p(0.52, 0.568))
        floor.addLine(to: brush.p(1, 1))
        floor.addLine(to: brush.p(0, 1))
        floor.closeSubpath()
        context.fill(floor, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.38, green: 0.53, blue: 0.28), location: 0),
                .init(color: grass, location: 0.34),
                .init(color: Color(red: 0.22, green: 0.36, blue: 0.18), location: 0.78),
                .init(color: Color(red: 0.14, green: 0.24, blue: 0.13), location: 1)
            ]),
            startPoint: brush.p(0.5, 0.52),
            endPoint: brush.p(0.5, 1)))

        let patches: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (0.13, 0.585, 0.28, 0.055, moss.opacity(0.30)),
            (0.80, 0.600, 0.30, 0.060, Color(red: 0.48, green: 0.58, blue: 0.26).opacity(0.26)),
            (0.20, 0.760, 0.34, 0.100, soil.opacity(0.22)),
            (0.86, 0.800, 0.32, 0.110, moss.opacity(0.24)),
            (0.52, 0.930, 0.44, 0.120, Color(red: 0.16, green: 0.28, blue: 0.14).opacity(0.30))
        ]
        for (index, patch) in patches.enumerated() {
            brush.groundPatch(in: &context,
                              center: brush.p(patch.0, patch.1),
                              width: brush.rx(patch.2),
                              height: brush.ry(patch.3),
                              color: patch.4,
                              seed: 900 &+ index &* 11)
        }
    }

    private func paintRiver(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        var river = Path()
        river.move(to: brush.p(0.455, 0.528))
        river.addCurve(to: brush.p(0.02, 1.02),
                       control1: brush.p(0.40, 0.68),
                       control2: brush.p(0.14, 0.82))
        river.addLine(to: brush.p(0.60, 1.02))
        river.addCurve(to: brush.p(0.545, 0.528),
                       control1: brush.p(0.62, 0.82),
                       control2: brush.p(0.52, 0.68))
        river.closeSubpath()
        context.fill(river, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.62, green: 0.80, blue: 0.82), location: 0),
                .init(color: water, location: 0.30),
                .init(color: waterDeep, location: 0.85),
                .init(color: Color(red: 0.08, green: 0.24, blue: 0.34), location: 1)
            ]),
            startPoint: brush.p(0.5, 0.53),
            endPoint: brush.p(0.4, 1)))

        // Current lives only in the motion layer. Drawn highlights here
        // freeze into stripes the moment the river is still.

        // Stepping stones. Each one gets a foam collar on its upstream side.
        let stones: [(CGFloat, CGFloat, CGFloat)] = [
            (0.470, 0.600, 0.028), (0.415, 0.665, 0.038),
            (0.330, 0.752, 0.050), (0.215, 0.862, 0.062)
        ]
        for (index, item) in stones.enumerated() {
            let center = brush.p(item.0, item.1)
            let radius = brush.rx(item.2)
            brush.rock(in: &context,
                       center: center,
                       radius: radius,
                       light: stone,
                       dark: stoneDark,
                       seed: 1000 &+ index &* 7,
                       seated: false)
            var foam = Path()
            foam.move(to: CGPoint(x: center.x - radius * 1.15, y: center.y + radius * 0.28))
            foam.addQuadCurve(to: CGPoint(x: center.x + radius * 1.15, y: center.y + radius * 0.24),
                              control: CGPoint(x: center.x, y: center.y - radius * 0.60))
            context.stroke(foam,
                           with: .color(Color.white.opacity(0.55)),
                           style: brush.stroke(brush.lw(1.4)))
            var wake = Path()
            wake.move(to: CGPoint(x: center.x - radius * 0.8, y: center.y + radius * 0.5))
            wake.addQuadCurve(to: CGPoint(x: center.x - radius * 2.2, y: center.y + radius * 1.9),
                              control: CGPoint(x: center.x - radius * 1.7, y: center.y + radius * 1.0))
            context.stroke(wake,
                           with: .color(Color.white.opacity(0.22)),
                           style: brush.stroke(brush.lw(1.0)))
        }
    }

    private func paintCascade(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Water first, then the source stone sits in the river mouth so it
        // belongs to the stream instead of hovering on the horizon.
        var chute = Path()
        chute.move(to: brush.p(0.478, 0.532))
        chute.addLine(to: brush.p(0.532, 0.532))
        chute.addCurve(to: brush.p(0.548, 0.582),
                       control1: brush.p(0.540, 0.548),
                       control2: brush.p(0.546, 0.566))
        chute.addLine(to: brush.p(0.452, 0.582))
        chute.addCurve(to: brush.p(0.478, 0.532),
                       control1: brush.p(0.454, 0.566),
                       control2: brush.p(0.460, 0.548))
        chute.closeSubpath()
        context.fill(chute, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.82), Color(red: 0.66, green: 0.86, blue: 0.90).opacity(0.75)]),
            startPoint: brush.p(0.5, 0.530),
            endPoint: brush.p(0.5, 0.584)))

        for index in 0..<5 {
            let x = 0.462 + CGFloat(index) * 0.019
            var strand = Path()
            strand.move(to: brush.p(x, 0.538))
            strand.addQuadCurve(to: brush.p(x - 0.004, 0.578),
                                control: brush.p(x + 0.006, 0.558))
            context.stroke(strand,
                           with: .color(Color.white.opacity(index.isMultiple(of: 2) ? 0.55 : 0.30)),
                           style: brush.stroke(brush.lw(0.9)))
        }

        for index in 0..<6 {
            let center = brush.p(0.470 + habitatNoise(index, 11, 0, 0.062),
                                 0.582 + habitatNoise(index, 12, 0, 0.016))
            let radius = brush.rx(habitatNoise(index, 13, 0.010, 0.024))
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.6,
                                                width: radius * 2, height: radius * 1.2)),
                         with: .color(Color.white.opacity(0.34)))
        }

        brush.rock(in: &context, center: brush.p(0.492, 0.584), radius: brush.rx(0.040),
                   light: stone.opacity(0.92), dark: stoneDark, seed: 1103)
        let source = brush.p(0.492, 0.584)
        var collar = Path()
        collar.addArc(center: source,
                      radius: brush.rx(0.050),
                      startAngle: .degrees(20),
                      endAngle: .degrees(160),
                      clockwise: false)
        context.stroke(collar, with: .color(Color.white.opacity(0.40)),
                       style: brush.stroke(brush.lw(1.6)))
        brush.rock(in: &context, center: brush.p(0.388, 0.556), radius: brush.rx(0.078),
                   light: stone, dark: stoneDark, seed: 1101)
        brush.rock(in: &context, center: brush.p(0.622, 0.552), radius: brush.rx(0.084),
                   light: stone, dark: stoneDark, seed: 1102)
    }

    private func paintRiverbank(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Gravel bars line both banks, coarser near the viewer.
        for side in 0..<2 {
            let clusters = side == 0 ? 9 : 8
            for index in 0..<clusters {
                let t = CGFloat(index) / CGFloat(clusters - 1)
                let x = side == 0
                    ? 0.44 - t * 0.42 + habitatNoise(index, 21, -0.02, 0.02)
                    : 0.56 + t * 0.10 + habitatNoise(index, 22, -0.02, 0.02)
                let y = 0.560 + t * 0.42
                brush.rock(in: &context,
                           center: brush.p(x, y),
                           radius: brush.rx(0.012 + t * 0.030),
                           light: stone.opacity(0.9),
                           dark: stoneDark,
                           seed: 1200 &+ side &* 40 &+ index)
            }
        }

        // Wet, dark mud where the grass gives out. Patches, not a drawn
        // outline: a pair of long strokes along the river reads as rails.
        for index in 0..<12 {
            let t = CGFloat(index) / 11
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let x = 0.50 + side * (0.055 + t * (side < 0 ? 0.40 : 0.08))
            let y = 0.560 + t * 0.42
            brush.groundPatch(in: &context,
                              center: brush.p(x, y),
                              width: brush.rx(0.055 + t * 0.04),
                              height: brush.ry(0.022 + t * 0.016),
                              color: Color(red: 0.22, green: 0.19, blue: 0.13).opacity(0.28),
                              seed: 1280 &+ index)
        }
    }

    private func paintGroundCover(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        let tufts: [(CGFloat, CGFloat, CGFloat)] = [
            (0.055, 0.585, 0.030), (0.155, 0.605, 0.038), (0.255, 0.582, 0.026),
            (0.660, 0.590, 0.030), (0.755, 0.612, 0.042), (0.870, 0.585, 0.032),
            (0.955, 0.625, 0.048), (0.075, 0.690, 0.052), (0.700, 0.700, 0.055),
            (0.845, 0.735, 0.064), (0.930, 0.850, 0.078), (0.640, 0.880, 0.070)
        ]
        for (index, tuft) in tufts.enumerated() {
            brush.grassTuft(in: &context,
                            base: brush.p(tuft.0, tuft.1),
                            height: brush.ry(tuft.2),
                            width: brush.rx(tuft.2 * 1.4),
                            colors: [grass, grassLight, moss],
                            bladeCount: tuft.2 > 0.05 ? 12 : 9,
                            seed: 1300 &+ index &* 5)
        }

        // Granite slabs breaking through the turf.
        let slabs: [(CGFloat, CGFloat, CGFloat)] = [
            (0.115, 0.640, 0.045), (0.885, 0.660, 0.040), (0.775, 0.925, 0.070)
        ]
        for (index, slab) in slabs.enumerated() {
            brush.rock(in: &context,
                       center: brush.p(slab.0, slab.1),
                       radius: brush.rx(slab.2),
                       light: stone,
                       dark: stoneDark,
                       seed: 1400 &+ index,
                       flatten: 0.52)
            // Moss creeps over the shaded top of each slab.
            let center = brush.p(slab.0, slab.1)
            let radius = brush.rx(slab.2)
            var cushion = Path()
            cushion.move(to: CGPoint(x: center.x - radius * 0.6, y: center.y - radius * 0.18))
            cushion.addQuadCurve(to: CGPoint(x: center.x + radius * 0.5, y: center.y - radius * 0.24),
                                 control: CGPoint(x: center.x - radius * 0.05, y: center.y - radius * 0.52))
            cushion.addQuadCurve(to: CGPoint(x: center.x - radius * 0.6, y: center.y - radius * 0.18),
                                 control: CGPoint(x: center.x - radius * 0.05, y: center.y - radius * 0.06))
            cushion.closeSubpath()
            context.fill(cushion, with: .color(moss.opacity(0.62)))
        }
    }

    private func paintBerryThicket(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Blueberry scrub on the right bank: what a bear actually comes for.
        let bushes: [(CGFloat, CGFloat, CGFloat)] = [
            (0.735, 0.652, 0.060), (0.845, 0.690, 0.075), (0.940, 0.648, 0.055)
        ]
        for (index, bush) in bushes.enumerated() {
            let center = brush.p(bush.0, bush.1 - bush.2 * 0.45)
            brush.contactShadow(in: &context,
                                center: brush.p(bush.0, bush.1),
                                width: brush.rx(bush.2 * 2.0),
                                height: brush.ry(bush.2 * 0.42),
                                opacity: 0.20)
            brush.crown(in: &context,
                        center: center,
                        width: brush.rx(bush.2 * 1.9),
                        height: brush.ry(bush.2 * 1.5),
                        colors: [Color(red: 0.20, green: 0.38, blue: 0.19),
                                 Color(red: 0.30, green: 0.50, blue: 0.22),
                                 Color(red: 0.17, green: 0.32, blue: 0.17)],
                        seed: 1500 &+ index &* 9,
                        lobes: 5)
            for berry in 0..<9 {
                let angle = Double(habitatNoise(index &* 20 &+ berry, 31)) * 2 * .pi
                let distance = brush.rx(bush.2) * habitatNoise(index &* 20 &+ berry, 32, 0.25, 0.85)
                let point = CGPoint(x: center.x + CGFloat(cos(angle)) * distance,
                                    y: center.y + CGFloat(sin(angle)) * distance * 0.8)
                let radius = brush.rx(0.0075)
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                    width: radius * 2, height: radius * 2)),
                             with: .color(Color(red: 0.24, green: 0.24, blue: 0.48)))
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius * 0.4, y: point.y - radius * 0.55,
                                                    width: radius * 0.6, height: radius * 0.5)),
                             with: .color(Color.white.opacity(0.32)))
            }
        }
    }

    private func paintFallenLog(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A mossy trunk lying across the left bank, tying the frame tree to
        // the ground plane.
        let start = brush.p(-0.02, 0.735)
        let end = brush.p(0.315, 0.700)
        brush.contactShadow(in: &context,
                            center: brush.p(0.145, 0.735),
                            width: brush.rx(0.38),
                            height: brush.ry(0.040),
                            opacity: 0.26)
        brush.log(in: &context,
                  from: start,
                  to: end,
                  thickness: brush.ry(0.052),
                  bark: bark,
                  barkLight: barkLight,
                  core: Color(red: 0.72, green: 0.52, blue: 0.28))

        // Moss coat on the upper surface plus small shelf fungi.
        var coat = Path()
        coat.move(to: CGPoint(x: start.x, y: start.y - brush.ry(0.020)))
        coat.addQuadCurve(to: CGPoint(x: end.x - brush.rx(0.02), y: end.y - brush.ry(0.022)),
                          control: brush.p(0.15, 0.700))
        context.stroke(coat, with: .color(moss.opacity(0.85)), style: brush.stroke(brush.lw(3.4)))
        for index in 0..<4 {
            let t = CGFloat(index) / 3
            let point = CGPoint(x: start.x + (end.x - start.x) * (0.14 + t * 0.72),
                                y: start.y + (end.y - start.y) * (0.14 + t * 0.72) + brush.ry(0.012))
            var shelf = Path()
            shelf.move(to: point)
            shelf.addQuadCurve(to: CGPoint(x: point.x + brush.rx(0.042), y: point.y - brush.ry(0.004)),
                               control: CGPoint(x: point.x + brush.rx(0.020), y: point.y - brush.ry(0.020)))
            shelf.addQuadCurve(to: point,
                               control: CGPoint(x: point.x + brush.rx(0.020), y: point.y + brush.ry(0.006)))
            shelf.closeSubpath()
            context.fill(shelf, with: .color(index.isMultiple(of: 2)
                                             ? Color(red: 0.82, green: 0.70, blue: 0.44)
                                             : Color(red: 0.66, green: 0.50, blue: 0.30)))
        }
        for index in 0..<3 {
            brush.mushroom(in: &context,
                           base: brush.p(0.075 + CGFloat(index) * 0.062, 0.782),
                           height: brush.ry(0.036 + CGFloat(index % 2) * 0.010),
                           cap: Color(red: 0.78, green: 0.24, blue: 0.16),
                           capShade: Color(red: 0.52, green: 0.14, blue: 0.10),
                           stem: Color(red: 0.94, green: 0.92, blue: 0.84),
                           speckles: true,
                           seed: 1600 &+ index)
        }
    }

    // MARK: - Trees

    private func paintFrameTrees(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Two mature spruces crop the frame. Their bases are hidden by the
        // bank so they feel rooted rather than pasted on.
        brush.trunk(in: &context,
                    base: brush.p(0.045, 0.980),
                    top: brush.p(0.085, -0.02),
                    baseWidth: brush.rx(0.115),
                    topWidth: brush.rx(0.055),
                    bark: bark,
                    barkLight: barkLight,
                    grain: 4,
                    seed: 5)
        brush.trunk(in: &context,
                    base: brush.p(0.955, 1.04),
                    top: brush.p(0.925, -0.02),
                    baseWidth: brush.rx(0.118),
                    topWidth: brush.rx(0.048),
                    bark: bark,
                    barkLight: barkLight,
                    grain: 4,
                    seed: 9)

        // Moss and root flare bury the cut at the foot of each trunk so the
        // right one no longer ends on a hard horizontal line.
        for (side, direction) in [(CGFloat(0.045), CGFloat(1)), (CGFloat(0.955), CGFloat(-1))] {
            let foot = brush.p(side, side < 0.5 ? 0.955 : 0.968)
            brush.groundPatch(in: &context,
                              center: foot,
                              width: brush.rx(0.16),
                              height: brush.ry(0.055),
                              color: moss.opacity(0.72),
                              seed: side < 0.5 ? 1710 : 1720)
            for index in 0..<3 {
                let spread = CGFloat(index + 1) * 0.058
                var root = Path()
                root.move(to: brush.p(side, 0.930 + CGFloat(index) * 0.022))
                root.addQuadCurve(to: brush.p(side + direction * spread, 0.968 + CGFloat(index) * 0.018),
                                  control: brush.p(side + direction * spread * 0.5,
                                                   0.938 + CGFloat(index) * 0.018))
                context.stroke(root, with: .color(Color.black.opacity(0.20)),
                               style: brush.stroke(brush.lw(6.0 - CGFloat(index))))
                context.stroke(root, with: .color(barkLight.opacity(0.85)),
                               style: brush.stroke(brush.lw(4.4 - CGFloat(index))))
            }
            brush.grassTuft(in: &context,
                            base: brush.p(side + direction * 0.070, 0.978),
                            height: brush.ry(0.055),
                            width: brush.rx(0.070),
                            colors: [moss, grass, grassLight],
                            bladeCount: 8,
                            seed: side < 0.5 ? 1730 : 1740)
        }

        // A broken snag between the right trunk and the berry scrub, with
        // woodpecker holes.
        let snagBase = brush.p(0.775, 0.640)
        let snagTop = brush.ry(0.235)
        let snagBark = Color(red: 0.46, green: 0.38, blue: 0.29)
        let snagShade = Color(red: 0.24, green: 0.19, blue: 0.14)

        // Root flare, so the trunk grows out of the ground instead of being
        // planted in it like a post.
        var flare = Path()
        flare.move(to: CGPoint(x: snagBase.x - brush.rx(0.058), y: snagBase.y + brush.ry(0.004)))
        flare.addQuadCurve(to: CGPoint(x: snagBase.x - brush.rx(0.022), y: snagBase.y - brush.ry(0.052)),
                           control: CGPoint(x: snagBase.x - brush.rx(0.030), y: snagBase.y - brush.ry(0.012)))
        flare.addLine(to: CGPoint(x: snagBase.x + brush.rx(0.024), y: snagBase.y - brush.ry(0.048)))
        flare.addQuadCurve(to: CGPoint(x: snagBase.x + brush.rx(0.052), y: snagBase.y + brush.ry(0.004)),
                           control: CGPoint(x: snagBase.x + brush.rx(0.032), y: snagBase.y - brush.ry(0.010)))
        flare.closeSubpath()
        context.fill(flare, with: .color(snagShade.opacity(0.92)))
        brush.groundPatch(in: &context,
                          center: CGPoint(x: snagBase.x, y: snagBase.y + brush.ry(0.012)),
                          width: brush.rx(0.12),
                          height: brush.ry(0.038),
                          color: moss.opacity(0.70),
                          seed: 1760)
        brush.grassTuft(in: &context,
                        base: CGPoint(x: snagBase.x + brush.rx(0.038), y: snagBase.y + brush.ry(0.006)),
                        height: brush.ry(0.042),
                        width: brush.rx(0.055),
                        colors: [moss, grass],
                        bladeCount: 7,
                        seed: 1765)

        // The shaft leans a little and narrows unevenly; the crown is torn
        // open into splinters where the top third snapped off.
        let lean = brush.rx(0.020)
        func shaftX(_ t: CGFloat, halfWidth: CGFloat) -> CGFloat {
            snagBase.x + lean * t * t + halfWidth
        }
        var snag = Path()
        snag.move(to: CGPoint(x: shaftX(0, halfWidth: -brush.rx(0.030)), y: snagBase.y))
        snag.addQuadCurve(to: CGPoint(x: shaftX(1, halfWidth: -brush.rx(0.013)), y: snagBase.y - snagTop),
                          control: CGPoint(x: shaftX(0.5, halfWidth: -brush.rx(0.026)),
                                           y: snagBase.y - snagTop * 0.5))
        // Splintered crown: three uneven spikes with torn gaps between them.
        let spikes: [(CGFloat, CGFloat)] = [(-0.013, 0.000), (-0.007, 0.036), (0.000, -0.014),
                                            (0.006, 0.028), (0.012, -0.004), (0.016, 0.022)]
        for spike in spikes {
            snag.addLine(to: CGPoint(x: shaftX(1, halfWidth: brush.rx(spike.0)),
                                     y: snagBase.y - snagTop + brush.ry(spike.1)))
        }
        snag.addQuadCurve(to: CGPoint(x: shaftX(0, halfWidth: brush.rx(0.028)), y: snagBase.y),
                          control: CGPoint(x: shaftX(0.5, halfWidth: brush.rx(0.024)),
                                           y: snagBase.y - snagTop * 0.5))
        snag.closeSubpath()
        context.fill(snag, with: .linearGradient(
            Gradient(colors: [Color(red: 0.56, green: 0.47, blue: 0.36), snagBark, snagShade]),
            startPoint: CGPoint(x: snagBase.x - brush.rx(0.030), y: snagBase.y),
            endPoint: CGPoint(x: snagBase.x + brush.rx(0.030), y: snagBase.y)))

        // Peeling bark: vertical fibres that stop at different heights, which
        // is what separates dead standing wood from a fence post.
        for index in 0..<9 {
            let offset = habitatNoise(index, 61, -0.024, 0.024)
            let top = habitatNoise(index, 62, 0.06, 0.22)
            let bottom = habitatNoise(index, 63, 0.01, 0.09)
            var fibre = Path()
            fibre.move(to: CGPoint(x: shaftX(bottom / 0.235, halfWidth: brush.rx(offset)),
                                   y: snagBase.y - brush.ry(bottom)))
            fibre.addQuadCurve(to: CGPoint(x: shaftX(top / 0.235, halfWidth: brush.rx(offset * 0.7)),
                                           y: snagBase.y - brush.ry(top)),
                               control: CGPoint(x: shaftX(0.5, halfWidth: brush.rx(offset * 1.2)),
                                                y: snagBase.y - brush.ry((top + bottom) * 0.5)))
            context.stroke(fibre,
                           with: .color(index % 3 == 0
                                        ? Color.white.opacity(0.10)
                                        : Color.black.opacity(0.16)),
                           style: brush.stroke(brush.lw(1.0)))
        }

        // Two snapped limb stubs give the silhouette something to catch on.
        let stubs: [(CGFloat, CGFloat, CGFloat)] = [(0.150, -1, 0.036), (0.196, 1, 0.028)]
        for stub in stubs {
            let t = stub.0 / 0.235
            let originX = shaftX(t, halfWidth: brush.rx(0.018) * stub.1)
            let originY = snagBase.y - brush.ry(stub.0)
            var limb = Path()
            limb.move(to: CGPoint(x: originX, y: originY - brush.ry(0.012)))
            limb.addQuadCurve(to: CGPoint(x: originX + brush.rx(stub.2) * stub.1,
                                          y: originY - brush.ry(stub.2 * 0.5)),
                              control: CGPoint(x: originX + brush.rx(stub.2 * 0.6) * stub.1,
                                               y: originY - brush.ry(0.004)))
            limb.addLine(to: CGPoint(x: originX + brush.rx(stub.2 * 0.92) * stub.1,
                                     y: originY - brush.ry(stub.2 * 0.30)))
            limb.addQuadCurve(to: CGPoint(x: originX, y: originY + brush.ry(0.010)),
                              control: CGPoint(x: originX + brush.rx(stub.2 * 0.5) * stub.1,
                                               y: originY + brush.ry(0.012)))
            limb.closeSubpath()
            context.fill(limb, with: .color(snagShade.opacity(0.95)))
        }

        // Woodpecker workings, scattered rather than stacked in a column.
        let holes: [(CGFloat, CGFloat, CGFloat)] = [(-0.008, 0.072, 0.013),
                                                    (0.010, 0.118, 0.010),
                                                    (-0.004, 0.166, 0.011)]
        for hole in holes {
            let t = hole.1 / 0.235
            let center = CGPoint(x: shaftX(t, halfWidth: brush.rx(hole.0)),
                                 y: snagBase.y - brush.ry(hole.1))
            context.fill(Path(ellipseIn: CGRect(x: center.x - brush.rx(hole.2) * 0.5,
                                                y: center.y - brush.rx(hole.2) * 0.62,
                                                width: brush.rx(hole.2),
                                                height: brush.rx(hole.2) * 1.24)),
                         with: .color(Color.black.opacity(0.74)))
            var rim = Path()
            rim.addArc(center: CGPoint(x: center.x, y: center.y + brush.rx(hole.2) * 0.10),
                       radius: brush.rx(hole.2) * 0.62,
                       startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            context.stroke(rim,
                           with: .color(Color(red: 0.72, green: 0.62, blue: 0.48).opacity(0.55)),
                           style: brush.stroke(brush.lw(0.9)))
        }
    }

    private func paintCanopy(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Needle sprays fanning in from both top corners, plus a couple of
        // branches that cross the very top of the frame.
        let sprays: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.055, 0.040, 0.30, 0.20), (0.075, 0.150, 0.26, 0.10), (0.060, 0.270, 0.22, -0.05),
            (0.945, 0.055, 0.30, .pi - 0.22), (0.925, 0.170, 0.26, .pi - 0.10), (0.940, 0.290, 0.21, .pi + 0.05)
        ]
        for (index, spray) in sprays.enumerated() {
            brush.frond(in: &context,
                        base: brush.p(spray.0, spray.1),
                        length: brush.rx(spray.2),
                        angle: spray.3,
                        curl: 0.18,
                        color: needle,
                        tipColor: needleLight,
                        leaflets: 8)
            _ = index
        }

        let branches: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.08, 0.075, 0.26, 0.020, 0.46, 0.055),
            (0.93, 0.095, 0.72, 0.030, 0.54, 0.075)
        ]
        for branch in branches {
            var path = Path()
            path.move(to: brush.p(branch.0, branch.1))
            path.addQuadCurve(to: brush.p(branch.4, branch.5),
                              control: brush.p(branch.2, branch.3))
            context.stroke(path,
                           with: .linearGradient(Gradient(colors: [bark, barkLight, bark]),
                                                 startPoint: brush.p(branch.0, branch.1),
                                                 endPoint: brush.p(branch.4, branch.5)),
                           style: brush.stroke(brush.rx(0.020)))
        }

        // Needle clusters hanging off those branches, with a few cones.
        let clusters: [(CGFloat, CGFloat, CGFloat)] = [
            (0.20, 0.052, 0.075), (0.33, 0.058, 0.062), (0.44, 0.070, 0.055),
            (0.82, 0.075, 0.078), (0.70, 0.070, 0.064), (0.60, 0.080, 0.052)
        ]
        for (index, cluster) in clusters.enumerated() {
            brush.crown(in: &context,
                        center: brush.p(cluster.0, cluster.1),
                        width: brush.rx(cluster.2 * 2.2),
                        height: brush.ry(cluster.2 * 1.5),
                        colors: [needle, needleLight, Color(red: 0.19, green: 0.38, blue: 0.24)],
                        seed: 1700 &+ index &* 13,
                        lobes: 4)
        }
        let cones: [(CGFloat, CGFloat)] = [(0.245, 0.098), (0.375, 0.100), (0.775, 0.118), (0.655, 0.112)]
        for (index, cone) in cones.enumerated() {
            let top = brush.p(cone.0, cone.1)
            var body = Path()
            body.move(to: top)
            body.addQuadCurve(to: CGPoint(x: top.x, y: top.y + brush.ry(0.042)),
                              control: CGPoint(x: top.x + brush.rx(0.016), y: top.y + brush.ry(0.020)))
            body.addQuadCurve(to: top,
                              control: CGPoint(x: top.x - brush.rx(0.016), y: top.y + brush.ry(0.020)))
            body.closeSubpath()
            context.fill(body, with: .color(index.isMultiple(of: 2)
                                            ? Color(red: 0.44, green: 0.28, blue: 0.15)
                                            : Color(red: 0.34, green: 0.21, blue: 0.11)))
        }
    }

    private func paintBeehive(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // A wild hive hanging from the right branch: unmistakably a bear's
        // forest, and it lives in the otherwise empty upper right.
        let anchor = brush.p(0.855, 0.120)
        var stalk = Path()
        stalk.move(to: anchor)
        stalk.addLine(to: CGPoint(x: anchor.x, y: anchor.y + brush.ry(0.024)))
        context.stroke(stalk, with: .color(Color(red: 0.52, green: 0.40, blue: 0.20)),
                       style: brush.stroke(brush.lw(2.0)))

        let center = CGPoint(x: anchor.x, y: anchor.y + brush.ry(0.086))
        let points = brush.blobPoints(center: center,
                                      radiusX: brush.rx(0.052),
                                      radiusY: brush.ry(0.062),
                                      count: 9,
                                      irregularity: 0.16,
                                      seed: 1801)
        context.fill(brush.blob(points), with: .linearGradient(
            Gradient(colors: [Color(red: 0.90, green: 0.75, blue: 0.42),
                              Color(red: 0.60, green: 0.44, blue: 0.20)]),
            startPoint: CGPoint(x: center.x - brush.rx(0.05), y: center.y - brush.ry(0.06)),
            endPoint: CGPoint(x: center.x + brush.rx(0.05), y: center.y + brush.ry(0.06))))
        for index in 0..<4 {
            let y = center.y - brush.ry(0.030) + CGFloat(index) * brush.ry(0.024)
            var band = Path()
            band.move(to: CGPoint(x: center.x - brush.rx(0.046), y: y))
            band.addQuadCurve(to: CGPoint(x: center.x + brush.rx(0.046), y: y),
                              control: CGPoint(x: center.x, y: y + brush.ry(0.014)))
            context.stroke(band, with: .color(Color(red: 0.50, green: 0.36, blue: 0.16).opacity(0.55)),
                           style: brush.stroke(brush.lw(0.9)))
        }
        let mouth = CGRect(x: center.x - brush.rx(0.012),
                           y: center.y + brush.ry(0.030),
                           width: brush.rx(0.024),
                           height: brush.ry(0.018))
        context.fill(Path(ellipseIn: mouth), with: .color(Color.black.opacity(0.55)))
    }

    private func paintForeground(_ brush: HabitatBrush, in context: inout GraphicsContext) {
        // Ferns and litter in both bottom corners frame the play area from
        // below without covering the answer pile.
        let ferns: [(CGFloat, CGFloat, CGFloat, Double, CGFloat)] = [
            (0.02, 1.01, 0.30, -1.15, 0.22), (0.075, 1.02, 0.34, -1.42, 0.14),
            (0.155, 1.02, 0.28, -1.75, -0.16), (0.975, 1.01, 0.32, -1.95, -0.20),
            (0.905, 1.02, 0.36, -1.70, -0.12), (0.825, 1.02, 0.27, -1.38, 0.16)
        ]
        for (index, fern) in ferns.enumerated() {
            brush.frond(in: &context,
                        base: brush.p(fern.0, fern.1),
                        length: brush.ry(fern.2),
                        angle: fern.3,
                        curl: fern.4,
                        color: Color(red: 0.12, green: 0.28, blue: 0.15),
                        tipColor: Color(red: 0.22, green: 0.44, blue: 0.20),
                        leaflets: 10)
            _ = index
        }

        for index in 0..<3 {
            brush.mushroom(in: &context,
                           base: brush.p(0.865 + CGFloat(index) * 0.040, 0.975 - CGFloat(index % 2) * 0.020),
                           height: brush.ry(0.030),
                           cap: Color(red: 0.72, green: 0.56, blue: 0.34),
                           capShade: Color(red: 0.46, green: 0.32, blue: 0.18),
                           stem: Color(red: 0.90, green: 0.86, blue: 0.74),
                           speckles: false,
                           seed: 1900 &+ index)
        }

        // The last stone of the river sits in front of the water, so the
        // stream disappears behind it instead of running off the frame as a
        // flat blue slab.
        let mouth = brush.p(0.305, 0.975)
        brush.rock(in: &context,
                   center: mouth,
                   radius: brush.rx(0.078),
                   light: stone,
                   dark: stoneDark,
                   seed: 1910,
                   flatten: 0.62)
        var collar = Path()
        collar.move(to: CGPoint(x: mouth.x - brush.rx(0.090), y: mouth.y - brush.ry(0.018)))
        collar.addQuadCurve(to: CGPoint(x: mouth.x + brush.rx(0.070), y: mouth.y - brush.ry(0.010)),
                            control: CGPoint(x: mouth.x - brush.rx(0.010), y: mouth.y - brush.ry(0.055)))
        context.stroke(collar,
                       with: .color(Color.white.opacity(0.42)),
                       style: brush.stroke(brush.lw(1.6)))
        brush.grassTuft(in: &context,
                        base: CGPoint(x: mouth.x + brush.rx(0.070), y: mouth.y + brush.ry(0.018)),
                        height: brush.ry(0.048),
                        width: brush.rx(0.060),
                        colors: [moss, grass],
                        bladeCount: 7,
                        seed: 1914)
    }
}
