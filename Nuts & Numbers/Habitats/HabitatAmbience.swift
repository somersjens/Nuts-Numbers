//
//  HabitatAmbience.swift
//  Nuts & Numbers
//
//  The moving layer that sits on top of each static habitat. It follows the
//  same budget as the elephant sanctuary: one 30 Hz timeline, a couple of
//  dozen solid fills and short strokes, no gradients and no per-frame path
//  rebuilding beyond what is unavoidable. Motion is placed away from the drop
//  corridor and stops completely under Reduce Motion.
//

import SwiftUI

enum AnimalHabitatKind: String, CaseIterable {
    case octopus, crab, bear, fox, frog, penguin, bunny, dog, lion

    init(characterID: String) {
        self = AnimalHabitatKind(rawValue: characterID) ?? .fox
    }
}

/// Looping progress in `0...1`. With `time == 0` it collapses to the offset,
/// so a paused timeline still yields a sensible, evenly spread still frame.
@inline(__always)
private func loop(_ time: TimeInterval, _ duration: Double, _ offset: Double) -> CGFloat {
    let raw = (time / duration + offset).truncatingRemainder(dividingBy: 1)
    return CGFloat(raw < 0 ? raw + 1 : raw)
}

struct AnimalHabitatLivingDetails: View {
    let characterID: String
    let isPad: Bool
    let reduceMotion: Bool

    var body: some View {
        let habitat = AnimalHabitatKind(characterID: characterID)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let brush = HabitatBrush(size: size, isPad: isPad)
                switch habitat {
                case .octopus: paintReef(brush, in: &context, time: time)
                case .crab: paintShallows(brush, in: &context, time: time)
                case .bear: paintMountainForest(brush, in: &context, time: time)
                case .fox: paintAutumnForest(brush, in: &context, time: time)
                case .frog: paintMarsh(brush, in: &context, time: time)
                case .penguin: paintPolar(brush, in: &context, time: time)
                case .bunny: paintMeadow(brush, in: &context, time: time)
                case .dog: paintAgilityField(brush, in: &context, time: time)
                case .lion: paintSavanna(brush, in: &context, time: time)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Shared marks

private extension AnimalHabitatLivingDetails {
    /// A rising bubble that shrinks and fades as it nears the surface.
    func bubble(_ brush: HabitatBrush,
                in context: inout GraphicsContext,
                vent: CGPoint,
                progress: CGFloat,
                rise: CGFloat,
                drift: CGFloat,
                radius: CGFloat) {
        let y = vent.y - rise * progress
        let wobble = CGFloat(sin(Double(progress) * 7.4)) * drift
        let scale = 0.55 + progress * 0.45
        let fade = Double(min(1, progress * 4) * (1 - progress * 0.85))
        let r = radius * scale
        let rect = CGRect(x: vent.x + wobble - r, y: y - r, width: r * 2, height: r * 2)
        context.stroke(Path(ellipseIn: rect),
                       with: .color(Color.white.opacity(0.34 * fade)),
                       style: brush.stroke(brush.lw(0.9)))
        context.fill(Path(ellipseIn: rect.insetBy(dx: r * 0.55, dy: r * 0.55)),
                     with: .color(Color.white.opacity(0.30 * fade)))
    }

    /// A drifting speck: dust in air, plankton in water.
    func mote(_ brush: HabitatBrush,
              in context: inout GraphicsContext,
              at point: CGPoint,
              radius: CGFloat,
              opacity: Double,
              color: Color = .white) {
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                            width: radius * 2, height: radius * 2)),
                     with: .color(color.opacity(opacity)))
    }

    /// Broken surface highlight. Interrupted on purpose so a row of them never
    /// reads as a progress bar behind the gameplay.
    func wavelet(_ brush: HabitatBrush,
                 in context: inout GraphicsContext,
                 from start: CGPoint,
                 to end: CGPoint,
                 lift: CGFloat,
                 opacity: Double) {
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end,
                      control1: CGPoint(x: start.x + (end.x - start.x) * 0.34, y: start.y - lift),
                      control2: CGPoint(x: start.x + (end.x - start.x) * 0.72, y: start.y + lift * 0.6))
        context.stroke(path,
                       with: .color(Color.white.opacity(opacity)),
                       style: brush.stroke(brush.lw(1.1)))
    }

    /// Expanding ring on water, fading as it grows.
    func ripple(_ brush: HabitatBrush,
                in context: inout GraphicsContext,
                center: CGPoint,
                progress: CGFloat,
                maxWidth: CGFloat) {
        let width = maxWidth * (0.16 + progress * 0.84)
        let height = width * 0.30
        context.stroke(Path(ellipseIn: CGRect(x: center.x - width, y: center.y - height,
                                              width: width * 2, height: height * 2)),
                       with: .color(Color.white.opacity(0.26 * Double(1 - progress))),
                       style: brush.stroke(brush.lw(0.9)))
    }

    /// Two-stroke bird chevron with a flapping span.
    func flyer(_ brush: HabitatBrush,
               in context: inout GraphicsContext,
               at point: CGPoint,
               span: CGFloat,
               flap: CGFloat,
               color: Color) {
        var wings = Path()
        wings.move(to: CGPoint(x: point.x - span, y: point.y + flap * 0.3))
        wings.addQuadCurve(to: point, control: CGPoint(x: point.x - span * 0.5, y: point.y - flap))
        wings.addQuadCurve(to: CGPoint(x: point.x + span, y: point.y + flap * 0.28),
                           control: CGPoint(x: point.x + span * 0.5, y: point.y - flap * 0.92))
        context.stroke(wings, with: .color(color), style: brush.joined(brush.lw(1.1)))
    }

    /// A leaf or petal tumbling as it falls; the width pulse fakes the spin.
    func tumbler(_ brush: HabitatBrush,
                 in context: inout GraphicsContext,
                 at point: CGPoint,
                 size: CGFloat,
                 spin: Double,
                 color: Color) {
        let width = size * CGFloat(0.25 + abs(cos(spin)) * 0.75)
        context.fill(Path(ellipseIn: CGRect(x: point.x - width * 0.5, y: point.y - size * 0.5,
                                            width: width, height: size)),
                     with: .color(color))
    }

    /// A small insect: a body dot with a blurred wing smear.
    func flutterer(_ brush: HabitatBrush,
                   in context: inout GraphicsContext,
                   at point: CGPoint,
                   size: CGFloat,
                   beat: Double,
                   wing: Color,
                   body: Color) {
        let span = size * CGFloat(0.55 + abs(sin(beat)) * 0.75)
        context.fill(Path(ellipseIn: CGRect(x: point.x - span, y: point.y - size * 0.34,
                                            width: span, height: size * 0.68)),
                     with: .color(wing))
        context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y - size * 0.34,
                                            width: span, height: size * 0.68)),
                     with: .color(wing))
        context.fill(Path(ellipseIn: CGRect(x: point.x - size * 0.11, y: point.y - size * 0.20,
                                            width: size * 0.22, height: size * 0.40)),
                     with: .color(body))
    }
}

// MARK: - Underwater

private extension AnimalHabitatLivingDetails {
    func paintReef(_ brush: HabitatBrush, in context: inout GraphicsContext, time: TimeInterval) {
        // Bubbles leak from crevices in both bommies, well outside the drop
        // corridor, and thin out before they reach the surface.
        let vents: [(CGFloat, CGFloat)] = [(0.088, 0.845), (0.905, 0.868), (0.205, 0.900)]
        for (ventIndex, vent) in vents.enumerated() {
            let count = ventIndex == 2 ? 3 : 5
            for index in 0..<count {
                let progress = loop(time, 6.2 + Double(ventIndex) * 1.4, Double(index) / Double(count))
                bubble(brush, in: &context,
                       vent: brush.p(vent.0, vent.1),
                       progress: progress,
                       rise: brush.ry(0.62),
                       drift: brush.rx(0.018),
                       radius: brush.rx(0.011 + CGFloat(index % 3) * 0.004))
            }
        }

        // Suspended plankton sinking slowly through the light.
        for index in 0..<12 {
            let fall = loop(time, 26 + Double(index % 4) * 5, Double(index) * 0.083)
            let x = habitatNoise(index, 201, 0.05, 0.95)
            let sway = CGFloat(sin(time * 0.30 + Double(index))) * 0.010
            mote(brush, in: &context,
                 at: brush.p(x + sway, 0.06 + fall * 0.72),
                 radius: brush.rx(0.0035 + habitatNoise(index, 202, 0, 0.003)),
                 opacity: 0.10 + Double(habitatNoise(index, 203, 0, 0.12)))
        }

        // Reef fish cruising the mid water, kept off the drop corridor. Tail
        // flicks so they never sit as frozen cut-outs.
        let reefFish: [(CGFloat, Double, Bool, Color, CGFloat)] = [
            (0.268, 9.5, true, Color(red: 0.98, green: 0.62, blue: 0.24), 0.062),
            (0.300, 11.0, false, Color(red: 0.42, green: 0.78, blue: 0.86), 0.054),
            (0.355, 13.5, true, Color(red: 0.94, green: 0.84, blue: 0.36), 0.070),
            (0.390, 10.2, false, Color(red: 0.98, green: 0.52, blue: 0.38), 0.048),
            (0.430, 12.4, true, Color(red: 0.36, green: 0.70, blue: 0.78), 0.056)
        ]
        for (index, swimmer) in reefFish.enumerated() {
            let progress = loop(time, swimmer.1, Double(index) * 0.17)
            let x = swimmer.2 ? -0.12 + progress * 1.24 : 1.12 - progress * 1.24
            let y = swimmer.0 + CGFloat(sin(time * 1.4 + Double(index) * 1.1)) * 0.016
            let flick = CGFloat(sin(time * 9.0 + Double(index) * 2.2))
            brush.fish(in: &context,
                       center: brush.p(x, y),
                       length: brush.rx(swimmer.4),
                       color: swimmer.3.opacity(0.78),
                       belly: Color.white.opacity(0.55),
                       facingRight: swimmer.2,
                       flick: flick)
        }

        // Caustics sliding along the underside of the surface.
        for index in 0..<3 {
            let slide = CGFloat(sin(time * 0.42 + Double(index) * 1.7)) * 0.05
            let y = 0.036 + CGFloat(index) * 0.014
            wavelet(brush, in: &context,
                    from: brush.p(0.12 + CGFloat(index) * 0.24 + slide, y),
                    to: brush.p(0.34 + CGFloat(index) * 0.24 + slide, y),
                    lift: brush.ry(0.010),
                    opacity: 0.22 - Double(index) * 0.04)
        }
    }

    func paintShallows(_ brush: HabitatBrush, in context: inout GraphicsContext, time: TimeInterval) {
        for (ventIndex, vent) in [(0.075, 0.880), (0.930, 0.860)].enumerated() {
            for index in 0..<4 {
                let progress = loop(time, 5.4 + Double(ventIndex) * 1.1, Double(index) * 0.25)
                bubble(brush, in: &context,
                       vent: brush.p(vent.0, vent.1),
                       progress: progress,
                       rise: brush.ry(0.70),
                       drift: brush.rx(0.016),
                       radius: brush.rx(0.010 + CGFloat(index % 2) * 0.004))
            }
        }

        // A loose shoal drifting across the back of the flat.
        for index in 0..<7 {
            let progress = loop(time, 11 + Double(index) * 1.4, Double(index) * 0.13)
            let x = -0.10 + progress * 1.20
            let y = 0.355 + CGFloat(index % 3) * 0.038
                + CGFloat(sin(time * 1.6 + Double(index))) * 0.012
            let flick = CGFloat(sin(time * 10.0 + Double(index) * 1.8))
            brush.fish(in: &context,
                       center: brush.p(x, y),
                       length: brush.rx(0.036 + CGFloat(index % 2) * 0.014),
                       color: Color(red: 0.98, green: 0.78, blue: 0.32).opacity(0.74),
                       belly: Color.white.opacity(0.5),
                       facingRight: true,
                       flick: flick)
        }

        // Caustic net crawling over the sand.
        for index in 0..<5 {
            let slide = CGFloat(sin(time * 0.5 + Double(index) * 0.9)) * 0.035
            let y = 0.760 + CGFloat(index) * 0.052
            wavelet(brush, in: &context,
                    from: brush.p(0.05 + CGFloat(index) * 0.18 + slide, y),
                    to: brush.p(0.27 + CGFloat(index) * 0.18 + slide, y),
                    lift: brush.ry(0.012),
                    opacity: 0.16 - Double(index) * 0.015)
        }

        for index in 0..<8 {
            let fall = loop(time, 22 + Double(index % 3) * 6, Double(index) * 0.125)
            mote(brush, in: &context,
                 at: brush.p(habitatNoise(index, 211, 0.04, 0.96), 0.20 + fall * 0.62),
                 radius: brush.rx(0.003),
                 opacity: 0.14)
        }
    }
}

// MARK: - Woodland

private extension AnimalHabitatLivingDetails {
    func paintMountainForest(_ brush: HabitatBrush, in context: inout GraphicsContext, time: TimeInterval) {
        // Current: slow, broken glints that follow the river's own slant.
        // Long horizontal strokes racing downstream read as stripes.
        for index in 0..<4 {
            let progress = loop(time, 10.5 + Double(index) * 1.4, Double(index) * 0.23)
            let t = progress
            let y = 0.595 + t * 0.340
            let leftBank = 0.455 - t * 0.400
            let rightBank = 0.545 + t * 0.045
            let width = rightBank - leftBank
            let start = leftBank + width * (0.28 + CGFloat(index % 2) * 0.16)
            wavelet(brush, in: &context,
                    from: brush.p(start, y),
                    to: brush.p(start - width * 0.08, y + 0.038),
                    lift: brush.ry(0.003),
                    opacity: 0.10 * Double(1 - t * 0.45))
        }

        // A few quieter streaks on the cascade.
        for index in 0..<3 {
            let progress = loop(time, 2.8, Double(index) * 0.33)
            let x = 0.476 + CGFloat(index) * 0.018
            var streak = Path()
            streak.move(to: brush.p(x, 0.522 + progress * 0.006))
            streak.addQuadCurve(to: brush.p(x - 0.003, 0.522 + progress * 0.050),
                                control: brush.p(x + 0.004, 0.546))
            context.stroke(streak,
                           with: .color(Color.white.opacity(0.28 * Double(1 - progress))),
                           style: brush.stroke(brush.lw(0.9)))
        }

        // Spray hanging over the cascade at the head of the river.
        for index in 0..<5 {
            let progress = loop(time, 3.4, Double(index) * 0.2)
            mote(brush, in: &context,
                 at: brush.p(0.482 + habitatNoise(index, 221, -0.030, 0.030),
                             0.560 - progress * 0.030),
                 radius: brush.rx(0.008 + progress * 0.006),
                 opacity: 0.22 * Double(1 - progress))
        }

        // Needles and small leaves spiralling down through the canopy gaps.
        for index in 0..<7 {
            let fall = loop(time, 9.5 + Double(index % 3) * 2.4, Double(index) * 0.14)
            let x = habitatNoise(index, 222, 0.03, 0.97)
            let sway = CGFloat(sin(time * 1.1 + Double(index) * 2.0)) * 0.022
            tumbler(brush, in: &context,
                    at: brush.p(x + sway, -0.05 + fall * 1.12),
                    size: brush.ry(0.014),
                    spin: time * 2.2 + Double(index),
                    color: index.isMultiple(of: 3)
                        ? Color(red: 0.72, green: 0.56, blue: 0.24).opacity(0.72)
                        : Color(red: 0.24, green: 0.42, blue: 0.22).opacity(0.66))
        }

        // A pair of birds crossing high over the valley.
        for index in 0..<2 {
            let progress = loop(time, 15 + Double(index) * 3.4, Double(index) * 0.42)
            let x = -0.08 + progress * 1.16
            let y = 0.145 + CGFloat(index) * 0.042
                + CGFloat(sin(time * 0.8 + Double(index))) * 0.006
            flyer(brush, in: &context,
                  at: brush.p(x, y),
                  span: brush.rx(0.016),
                  flap: brush.ry(0.008) * CGFloat(abs(sin(time * 3.0 + Double(index)))),
                  color: Color(red: 0.16, green: 0.18, blue: 0.16).opacity(0.52))
        }

        // Mist sliding along the tree line.
        for index in 0..<2 {
            let drift = loop(time, 40 + Double(index) * 12, Double(index) * 0.5)
            let x = -0.25 + drift * 1.5
            let width = brush.rx(0.42)
            let height = brush.ry(0.036)
            context.fill(Path(ellipseIn: CGRect(x: brush.rx(x) - width * 0.5,
                                                y: brush.ry(0.478 + CGFloat(index) * 0.030) - height * 0.5,
                                                width: width, height: height)),
                         with: .color(Color.white.opacity(0.10)))
        }
    }

    func paintAutumnForest(_ brush: HabitatBrush, in context: inout GraphicsContext, time: TimeInterval) {
        // Leaf fall is the whole point of this habitat, so it carries most of
        // the motion budget. Paths cross the edges, not the middle.
        for index in 0..<10 {
            let fall = loop(time, 8.0 + Double(index % 4) * 2.2, Double(index) * 0.1)
            let lane = habitatNoise(index, 231)
            let x = lane < 0.5 ? lane * 0.62 : 0.40 + lane * 0.62
            let sway = CGFloat(sin(time * 1.25 + Double(index) * 1.7)) * 0.032
            tumbler(brush, in: &context,
                    at: brush.p(x + sway, -0.06 + fall * 1.14),
                    size: brush.ry(0.022 + habitatNoise(index, 232, 0, 0.012)),
                    spin: time * 2.6 + Double(index) * 0.8,
                    color: [Color(red: 0.86, green: 0.44, blue: 0.14),
                            Color(red: 0.94, green: 0.68, blue: 0.20),
                            Color(red: 0.68, green: 0.26, blue: 0.12),
                            Color(red: 0.82, green: 0.56, blue: 0.22)][index % 4].opacity(0.82))
        }

        // The shafts breathe as the canopy moves overhead.
        for index in 0..<3 {
            let pulse = 0.5 + 0.5 * sin(time * 0.55 + Double(index) * 1.2)
            var shaft = Path()
            let topX = 0.60 + CGFloat(index) * 0.13
            shaft.move(to: brush.p(topX, 0.02))
            shaft.addLine(to: brush.p(topX + 0.055, 0.02))
            shaft.addLine(to: brush.p(topX - 0.10, 0.72))
            shaft.addLine(to: brush.p(topX - 0.20, 0.72))
            shaft.closeSubpath()
            context.fill(shaft, with: .color(Color(red: 1.0, green: 0.80, blue: 0.42)
                .opacity(0.030 + 0.030 * pulse)))
        }

        for index in 0..<8 {
            let rise = loop(time, 18 + Double(index % 3) * 5, Double(index) * 0.125)
            mote(brush, in: &context,
                 at: brush.p(habitatNoise(index, 233, 0.06, 0.94), 0.86 - rise * 0.44),
                 radius: brush.rx(0.0035),
                 opacity: 0.24 * Double(1 - rise),
                 color: Color(red: 1.0, green: 0.92, blue: 0.72))
        }
    }
}

// MARK: - Water and ice

private extension AnimalHabitatLivingDetails {
    func paintMarsh(_ brush: HabitatBrush, in context: inout GraphicsContext, time: TimeInterval) {
        // Rings from insects touching the surface, kept to the pond edges.
        for (index, spot) in [(0.235, 0.735), (0.790, 0.690), (0.640, 0.885)].enumerated() {
            let progress = loop(time, 4.6 + Double(index) * 1.3, Double(index) * 0.33)
            ripple(brush, in: &context,
                   center: brush.p(spot.0, spot.1),
                   progress: progress,
                   maxWidth: brush.rx(0.085))
        }

        // Long, slow glints on the open water.
        for index in 0..<5 {
            let phase = CGFloat(sin(time * 0.6 + Double(index) * 0.95))
            let y = 0.610 + CGFloat(index) * 0.048
            wavelet(brush, in: &context,
                    from: brush.p(0.16 + CGFloat(index) * 0.13 + phase * 0.012, y),
                    to: brush.p(0.36 + CGFloat(index) * 0.13 + phase * 0.010, y),
                    lift: brush.ry(0.004),
                    opacity: 0.24 - Double(index) * 0.03)
        }

        // Two dragonflies hovering over the reeds, never over the middle.
        for index in 0..<2 {
            let orbit = time * (0.42 + Double(index) * 0.12) + Double(index) * 2.1
            let anchorX: CGFloat = index == 0 ? 0.145 : 0.865
            let point = brush.p(anchorX + CGFloat(cos(orbit)) * 0.075,
                                0.560 + CGFloat(sin(orbit * 1.6)) * 0.055)
            flutterer(brush, in: &context,
                      at: point,
                      size: brush.ry(0.030),
                      beat: time * 14 + Double(index),
                      wing: Color.white.opacity(0.30),
                      body: Color(red: 0.20, green: 0.52, blue: 0.56).opacity(0.85))
        }

        // Mist drifting low across the far bank.
        for index in 0..<3 {
            let drift = loop(time, 34 + Double(index) * 9, Double(index) * 0.33)
            let width = brush.rx(0.40)
            let height = brush.ry(0.030)
            context.fill(Path(ellipseIn: CGRect(x: brush.rx(-0.24 + drift * 1.48) - width * 0.5,
                                                y: brush.ry(0.516 + CGFloat(index) * 0.026) - height * 0.5,
                                                width: width, height: height)),
                         with: .color(Color.white.opacity(0.13)))
        }

        for index in 0..<6 {
            let bob = CGFloat(sin(time * 0.9 + Double(index) * 1.4)) * 0.006
            mote(brush, in: &context,
                 at: brush.p(habitatNoise(index, 241, 0.05, 0.95),
                             habitatNoise(index, 242, 0.470, 0.560) + bob),
                 radius: brush.rx(0.0030),
                 opacity: 0.30,
                 color: Color(red: 1.0, green: 0.98, blue: 0.86))
        }
    }

    func paintPolar(_ brush: HabitatBrush, in context: inout GraphicsContext, time: TimeInterval) {
        // Wind-driven snow: it crosses the frame diagonally rather than
        // falling straight, which is what makes it read as cold.
        for index in 0..<20 {
            let fall = loop(time, 7.5 + Double(index % 5) * 2.6, Double(index) * 0.05)
            let lane = habitatNoise(index, 251)
            let gust = CGFloat(sin(time * 0.7 + Double(index) * 0.6)) * 0.030
            let x = lane * 1.14 - 0.07 + fall * 0.16 + gust
            mote(brush, in: &context,
                 at: brush.p(x, -0.04 + fall * 1.10),
                 radius: brush.rx(0.0035 + habitatNoise(index, 252, 0, 0.0045)),
                 opacity: 0.40 + Double(habitatNoise(index, 253, 0, 0.35)))
        }

        // Swell on the open sea behind the shelf.
        for index in 0..<4 {
            let phase = CGFloat(sin(time * 0.75 + Double(index) * 1.25))
            let y = 0.566 + CGFloat(index) * 0.020
            wavelet(brush, in: &context,
                    from: brush.p(0.08 + CGFloat(index) * 0.21 + phase * 0.014, y),
                    to: brush.p(0.28 + CGFloat(index) * 0.21 + phase * 0.012, y),
                    lift: brush.ry(0.004),
                    opacity: 0.30 - Double(index) * 0.04)
        }

        // Something surfacing in the dive hole every few seconds.
        for index in 0..<2 {
            let progress = loop(time, 5.8, Double(index) * 0.5)
            ripple(brush, in: &context,
                   center: brush.p(0.505, 0.778),
                   progress: progress,
                   maxWidth: brush.rx(0.150))
        }

        // Spindrift streaming off the crest of the shelf.
        for index in 0..<4 {
            let drift = loop(time, 6.5 + Double(index) * 1.4, Double(index) * 0.25)
            let width = brush.rx(0.16 + drift * 0.14)
            let height = brush.ry(0.012)
            context.fill(Path(ellipseIn: CGRect(x: brush.rx(0.14 + drift * 0.34) - width * 0.5,
                                                y: brush.ry(0.672 + CGFloat(index % 2) * 0.020) - height * 0.5,
                                                width: width, height: height)),
                         with: .color(Color.white.opacity(0.22 * Double(1 - drift))))
        }
    }
}

// MARK: - Open ground

private extension AnimalHabitatLivingDetails {
    func paintMeadow(_ brush: HabitatBrush, in context: inout GraphicsContext, time: TimeInterval) {
        // Butterflies loop over the beds and the hedge, away from the middle.
        for index in 0..<3 {
            let orbit = time * (0.34 + Double(index) * 0.09) + Double(index) * 2.4
            let anchorX: CGFloat = [0.125, 0.885, 0.760][index]
            let anchorY: CGFloat = [0.700, 0.640, 0.820][index]
            let point = brush.p(anchorX + CGFloat(cos(orbit)) * 0.085,
                                anchorY + CGFloat(sin(orbit * 1.7)) * 0.070)
            flutterer(brush, in: &context,
                      at: point,
                      size: brush.ry(0.034),
                      beat: time * 7.5 + Double(index),
                      wing: [Color(red: 1.0, green: 0.86, blue: 0.32),
                             Color(red: 0.98, green: 0.98, blue: 0.94),
                             Color(red: 0.96, green: 0.56, blue: 0.72)][index].opacity(0.88),
                      body: Color(red: 0.32, green: 0.24, blue: 0.16).opacity(0.85))
        }

        // Two bees working the flowers on a tighter, faster path.
        for index in 0..<2 {
            let orbit = time * (1.15 + Double(index) * 0.3) + Double(index) * 1.9
            let point = brush.p((index == 0 ? 0.075 : 0.930) + CGFloat(cos(orbit)) * 0.045,
                                (index == 0 ? 0.760 : 0.782) + CGFloat(sin(orbit * 2.2)) * 0.038)
            mote(brush, in: &context, at: point,
                 radius: brush.rx(0.006),
                 opacity: 0.85,
                 color: Color(red: 0.94, green: 0.76, blue: 0.18))
        }

        // Pollen and seed fluff lifting off the meadow.
        for index in 0..<10 {
            let rise = loop(time, 16 + Double(index % 4) * 4, Double(index) * 0.1)
            let sway = CGFloat(sin(time * 0.55 + Double(index) * 1.3)) * 0.020
            mote(brush, in: &context,
                 at: brush.p(habitatNoise(index, 261, 0.03, 0.97) + sway, 0.95 - rise * 0.66),
                 radius: brush.rx(0.0035),
                 opacity: 0.42 * Double(1 - rise * 0.7))
        }
    }

    func paintAgilityField(_ brush: HabitatBrush, in context: inout GraphicsContext, time: TimeInterval) {
        let pennantColors = [Color(red: 0.88, green: 0.24, blue: 0.20),
                             Color(red: 0.98, green: 0.80, blue: 0.16),
                             Color(red: 0.18, green: 0.45, blue: 0.80),
                             Color(red: 0.94, green: 0.96, blue: 0.94),
                             Color(red: 0.30, green: 0.72, blue: 0.42)]

        // The bunting is the one thing on this field that should always be
        // moving; each pennant swings on its own slightly offset clock.
        for line in 0..<2 {
            for index in 0..<13 {
                let t = CGFloat(index) / 12
                let sag = CGFloat(0.150 + CGFloat(line) * 0.095)
                let start = brush.p(0.016, 0.045 + CGFloat(line) * 0.075)
                let end = brush.p(0.984, 0.055 + CGFloat(line) * 0.075)
                let controlY = (start.y + end.y) * 0.5 + brush.ry(sag)
                let controlX = (start.x + end.x) * 0.5
                let oneX = start.x + (controlX - start.x) * t
                let oneY = start.y + (controlY - start.y) * t
                let twoX = controlX + (end.x - controlX) * t
                let twoY = controlY + (end.y - controlY) * t
                let anchor = CGPoint(x: oneX + (twoX - oneX) * t, y: oneY + (twoY - oneY) * t)

                let swing = CGFloat(sin(time * 2.1 + Double(index) * 0.55 + Double(line) * 0.9))
                let flagWidth = brush.rx(0.030)
                let flagHeight = brush.ry(0.052)
                var flag = Path()
                flag.move(to: CGPoint(x: anchor.x - flagWidth * 0.5, y: anchor.y))
                flag.addLine(to: CGPoint(x: anchor.x + flagWidth * 0.5, y: anchor.y))
                flag.addLine(to: CGPoint(x: anchor.x + swing * flagWidth * 0.42,
                                         y: anchor.y + flagHeight))
                flag.closeSubpath()
                // Only the leading edge is repainted, so the static pennant
                // underneath still shows through as the flag swings.
                context.fill(flag,
                             with: .color(pennantColors[(index + line) % pennantColors.count]
                                .opacity(0.92)))
            }
        }

        for index in 0..<2 {
            let progress = loop(time, 16 + Double(index) * 3.8, Double(index) * 0.45)
            flyer(brush, in: &context,
                  at: brush.p(-0.08 + progress * 1.16, 0.375 + CGFloat(index) * 0.036),
                  span: brush.rx(0.015),
                  flap: brush.ry(0.007) * CGFloat(abs(sin(time * 3.2 + Double(index)))),
                  color: Color(red: 0.18, green: 0.20, blue: 0.18).opacity(0.45))
        }

        for index in 0..<7 {
            let rise = loop(time, 19 + Double(index % 3) * 4, Double(index) * 0.14)
            let sway = CGFloat(sin(time * 0.5 + Double(index))) * 0.018
            mote(brush, in: &context,
                 at: brush.p(habitatNoise(index, 271, 0.02, 0.98) + sway, 0.98 - rise * 0.52),
                 radius: brush.rx(0.0032),
                 opacity: 0.34 * Double(1 - rise * 0.8))
        }
    }

    func paintSavanna(_ brush: HabitatBrush, in context: inout GraphicsContext, time: TimeInterval) {
        // Heat shimmer over the far plain: thin bands that slide sideways and
        // fade, never a hard moving line.
        for index in 0..<4 {
            let slide = CGFloat(sin(time * 0.45 + Double(index) * 1.35))
            let y = brush.ry(0.600 + CGFloat(index) * 0.022)
            let width = brush.rx(0.34)
            let height = brush.ry(0.012)
            context.fill(Path(ellipseIn: CGRect(x: brush.rx(0.18 + CGFloat(index) * 0.22) + slide * brush.rx(0.03) - width * 0.5,
                                                y: y - height * 0.5,
                                                width: width, height: height)),
                         with: .color(Color(red: 1.0, green: 0.94, blue: 0.76)
                            .opacity(0.10 + 0.06 * Double(abs(slide)))))
        }

        // Vultures turning on a thermal above the kopje.
        for index in 0..<3 {
            let orbit = time * 0.10 + Double(index) * 2.1
            let point = brush.p(0.760 + CGFloat(cos(orbit)) * 0.135,
                                0.185 + CGFloat(sin(orbit)) * 0.048)
            flyer(brush, in: &context,
                  at: point,
                  span: brush.rx(0.019 + CGFloat(index % 2) * 0.005),
                  flap: brush.ry(0.004) * CGFloat(abs(sin(time * 1.1 + Double(index)))),
                  color: Color(red: 0.16, green: 0.14, blue: 0.12).opacity(0.48))
        }

        // Dust lifting off the dry ground and blowing right.
        for index in 0..<10 {
            let drift = loop(time, 13 + Double(index % 4) * 4, Double(index) * 0.1)
            let lift = CGFloat(sin(time * 0.4 + Double(index) * 1.1)) * 0.020
            mote(brush, in: &context,
                 at: brush.p(-0.06 + drift * 1.14,
                             habitatNoise(index, 281, 0.700, 0.960) - drift * 0.10 + lift),
                 radius: brush.rx(0.004 + habitatNoise(index, 282, 0, 0.004)),
                 opacity: 0.26 * Double(1 - drift * 0.6),
                 color: Color(red: 0.98, green: 0.90, blue: 0.70))
        }

        // Seed fluff crossing the foreground grass.
        for index in 0..<5 {
            let drift = loop(time, 22 + Double(index) * 3.5, Double(index) * 0.2)
            mote(brush, in: &context,
                 at: brush.p(1.06 - drift * 1.14, 0.905 - CGFloat(sin(Double(drift) * .pi)) * 0.075),
                 radius: brush.rx(0.005),
                 opacity: 0.40,
                 color: Color(red: 1.0, green: 0.97, blue: 0.86))
        }
    }
}
