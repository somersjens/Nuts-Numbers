//
//  ClawMachineBackground.swift
//  Nuts & Numbers
//
//  A quiet, character-coloured menu surface. The pegboard and the exact walnut
//  artwork from the claw game tie the menus to gameplay without adding a
//  second cabinet or claw around the controls in front.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ClawMachineBackground: View, Equatable {
    let character: AnimalCharacter

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let palette = ClawMachinePalette(character: character)

            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: palette.top, location: 0),
                        .init(color: palette.middle, location: 0.48),
                        .init(color: palette.bottom, location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [.white.opacity(0.48), .white.opacity(0)],
                    center: UnitPoint(x: 0.34, y: 0.14),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.68
                )

                ClawPegboard(color: character.deepColor)
                    .opacity(0.23)

                ClawCabinetGlass(color: character.color)

                InGameNutBed()
                    .frame(height: min(136, max(108, size.height * 0.14)))
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // Keeps long translated copy and white cards readable while
                // leaving the pegboard and walnut silhouettes recognisable.
                Color.white.opacity(0.10)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ClawMachinePalette {
    let character: AnimalCharacter

    var top: Color { mix(character.skyRGB, (1.00, 0.97, 0.89), 0.34) }
    var middle: Color { mix(character.tintRGB, (0.96, 0.88, 0.70), 0.18) }
    var bottom: Color { mix(character.tintRGB, (0.77, 0.61, 0.39), 0.18) }
    private func mix(_ base: (Double, Double, Double),
                     _ target: (Double, Double, Double),
                     _ amount: Double) -> Color {
        let t = min(max(amount, 0), 1)
        return Color(red: base.0 + (target.0 - base.0) * t,
                     green: base.1 + (target.1 - base.1) * t,
                     blue: base.2 + (target.2 - base.2) * t)
    }
}

/// A workshop pegboard is immediately mechanical, but the tiny low-contrast
/// holes stay quieter behind copy than a literal machine interior photograph.
private struct ClawPegboard: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 34
            let radius: CGFloat = 1.65
            var y: CGFloat = 82
            var row = 0

            while y < size.height - 76 {
                var x = CGFloat(row % 2) * spacing * 0.5 + 17
                while x < size.width {
                    let hole = CGRect(x: x - radius, y: y - radius,
                                      width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: hole), with: .color(color.opacity(0.44)))
                    x += spacing
                }
                y += spacing
                row += 1
            }
        }
    }
}

/// Very soft reflections imply the glass front of a prize machine without the
/// blue shafts and rising bubbles that made the old backdrop read as water.
private struct ClawCabinetGlass: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 80, style: .continuous)
                    .fill(.white.opacity(0.11))
                    .frame(width: proxy.size.width * 0.10,
                           height: proxy.size.height * 0.76)
                    .rotationEffect(.degrees(18))
                    .offset(x: -proxy.size.width * 0.29,
                            y: -proxy.size.height * 0.05)

                RoundedRectangle(cornerRadius: 80, style: .continuous)
                    .fill(color.opacity(0.07))
                    .frame(width: proxy.size.width * 0.055,
                           height: proxy.size.height * 0.54)
                    .rotationEffect(.degrees(18))
                    .offset(x: -proxy.size.width * 0.14,
                            y: -proxy.size.height * 0.12)
            }
        }
        .clipped()
    }
}

private struct InGameNutBed: View {
    private let prizes: [(CGFloat, CGFloat, CGFloat, Double)] = [
        // A stable shuffle of both rows makes neighbouring shells cross over
        // each other irregularly without changing their z-order on redraw.
        (0.45, 0.46, 1.05, 18),  (0.74, 0.85, 1.09, 17),
        (-0.01, 0.50, 0.96, -16), (0.23, 0.82, 1.02, -17),
        (0.92, 0.51, 0.95, -18), (0.57, 0.81, 1.04, -10),
        (0.30, 0.51, 0.94, -8),  (0.91, 0.82, 1.03, -8),
        (0.76, 0.47, 1.02, 9),   (0.06, 0.84, 1.08, 13),
        (1.05, 0.48, 1.00, 10),  (0.40, 0.85, 1.10, 8),
        (0.14, 0.47, 1.03, 11),  (0.61, 0.50, 0.96, -13)
    ]

    var body: some View {
        GeometryReader { proxy in
            let base = min(106, max(72, proxy.size.width * 0.19))

            // Fourteen separate resizable Image views made every menu scroll
            // reconcile and composite fourteen copies of a 1536×1024 texture.
            // One asynchronous Canvas produces the same authored pile in a
            // single display-list node and shares the already decoded image.
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                for prize in prizes {
                    let visualWidth = base * prize.2
                    let imageWidth = visualWidth / ClawConfig.nutContentWidthFraction
                    let imageHeight = imageWidth / ClawConfig.nutCanvasAspect
                    let center = CGPoint(x: size.width * prize.0,
                                         y: size.height * (0.30 + prize.1))
                    let rect = CGRect(x: center.x - imageWidth / 2,
                                      y: center.y - imageHeight / 2,
                                      width: imageWidth,
                                      height: imageHeight)
                    var nutContext = context
                    nutContext.translateBy(x: center.x, y: center.y)
                    nutContext.rotate(by: .degrees(prize.3))
                    nutContext.translateBy(x: -center.x, y: -center.y)
                    nutContext.draw(nutImage, in: rect)
                }
            }
        }
    }

    private var nutImage: Image {
#if canImport(UIKit)
        Image(uiImage: ClawArtworkCache.nut)
#else
        Image(ClawConfig.nutImageName)
#endif
    }
}

/// The character portraits already contain the elephant's grab housing. This
/// line completes that artwork back to the physical top of the display. For
/// the other portraits it disappears behind the top of their transparent
/// canvas, so character switching keeps one stable hanging composition.
struct MenuHangingRope: View {
    let endPoint: CGPoint
    var lineWidth: CGFloat = 4.5

    var body: some View {
        MenuHangingRopeShape(endPoint: endPoint)
            .stroke(
                LinearGradient(
                    colors: [Color(red: 0.70, green: 0.56, blue: 0.32),
                             Color(red: 0.22, green: 0.14, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .shadow(color: .black.opacity(0.20), radius: 1, x: 1, y: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct MenuHangingRopeShape: Shape {
    var endPoint: CGPoint

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(endPoint.x, endPoint.y) }
        set { endPoint = CGPoint(x: newValue.first, y: newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        let end = CGPoint(x: endPoint.x, y: max(0, endPoint.y))
        let start = CGPoint(x: end.x, y: rect.minY)
        let bend = min(5, max(2, end.y * 0.025))
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x - bend, y: start.y + end.y * 0.34),
            control2: CGPoint(x: end.x + bend, y: start.y + end.y * 0.73)
        )
        return path
    }
}
