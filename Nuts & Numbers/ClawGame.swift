//
//  ClawGame.swift
//  Nuts & Numbers
//
//  The claw-machine playing surface. The session still lives in `MemoryGame`;
//  this file only steers the hanging elephant, decides which nut was chosen
//  (including one sitting under another), slides the pile into the hole, and
//  plays the grab / return / time-up animations.
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Tuning

enum ClawConfig {
    static let tick = 1.0 / 60.0

    static let trolleySpeed: CGFloat = 1.05
    static let swingSpring: CGFloat = 20
    static let swingDamping: CGFloat = 6.8
    static let swingDrive: CGFloat = 5.6
    static let maxSwing: CGFloat = 0.42
    /// Downward swipe on the playfield that lowers the claw in place.
    static let screenGrabSwipe: CGFloat = 36
    /// Extra band above the arcade panel (covers the bottom nut row) that stays
    /// on the poke / grab instead of the screen-half steer.
    static func controlSafetyMargin(isPad: Bool) -> CGFloat { isPad ? 108 : 84 }
    static func pokeSafetyWidth(isPad: Bool) -> CGFloat { isPad ? 430 : 200 }
    static func grabSafetyWidth(isPad: Bool) -> CGFloat { isPad ? 300 : 132 }

    /// Full-depth lower; kept gentle so the whole grab loop can breathe.
    static let descendDuration = 0.58
    static let grabPause = 0.20
    static let ascendDuration = 0.50
    static let carryDuration = 0.42
    static let dropDuration = 0.40
    static let dropSettle = 0.20
    static let returnDuration = 0.34
    static let spitDuration = 1.08
    static let cascadeDuration = 0.30
    static let cascadeStagger = 0.08
    /// Gravity for a released nut falling into the crate, in points/s².
    static let dropGravity: CGFloat = 2400

    static let entranceDuration = 0.85
    static let completionDuration = 2.12
    static let timeUpDuration = 1.35
    /// The loaded trolley travels from the collection side to the exact centre
    /// before it stops. Braking there sends the elephant to its left apex.
    static let celebrationCenterArrival = 0.52
    /// The hook stays parked while the elephant accelerates back to the right.
    /// Release happens during that swing, not at its apex, so the body carries
    /// real horizontal speed into the somersault.
    static let celebrationRelease = 1.02
    static let celebrationMouthArrival = 1.70
    static let celebrationLeftAngle: CGFloat = 0.30
    static let celebrationReleaseAngle: CGFloat = -0.22
    static let timeUpRelease = 0.58

    /// The four animated elephant layers share one square canvas. Keep the
    /// assembled character at the same optical height as the previous sprite.
    static func elephantVisibleHeight(isPad: Bool) -> CGFloat {
        isPad ? 251 : 193
    }
    /// Visible free rope between the trolley rail and the hook. The previous
    /// sprite sat almost flush against the rail, leaving no line to flex.
    static func elephantRopeLength(isPad: Bool) -> CGFloat { isPad ? 58 : 44 }
    /// Distance from the hanging attachment to the centre between the front
    /// hands. Both the descent and the carried walnut must use this same point.
    static let elephantGripReach: CGFloat = 0.92

    static func nutPixelRadius(unit: Double, pile: CGSize) -> CGFloat {
        CGFloat(unit) * pile.width
    }

    /// `1_nootje` canvas is 1536×1024; the walnut itself occupies this slice.
    static let nutImageName = "1_nootje"
    static let nutCanvasAspect: CGFloat = 1536.0 / 1024.0
    static let nutContentWidthFraction: CGFloat = 0.7142
    /// Visual walnut height divided by visual width.
    static let nutContentAspect: CGFloat = 0.7575
    /// Draw the shell a little larger than the grid cell so the irregular
    /// outline kisses its neighbours instead of leaving a dark gap.
    static let nutPackScale: CGFloat = 1.08
    /// Cap on the printed answer. Longer values keep this size as a ceiling
    /// and shrink to fit the shell.
    static let nutMaxTextSize: CGFloat = 17
}

#if canImport(UIKit)
/// Decode claw-machine sprites once. The elephant layers and walnut PNG are
/// large canvases; paying decompression on the first gameplay frame is a hitch.
enum ClawArtworkCache {
    static let nut: UIImage = prepared(named: ClawConfig.nutImageName)
    static let elephantClaw: UIImage = prepared(named: "1_claw")
    static let elephantBottom: UIImage = prepared(named: "1_bottom")
    static let elephantHead: UIImage = prepared(named: "1_head")
    static let elephantLeftArm: UIImage = prepared(named: "1_left_arm")
    static let elephantRightArm: UIImage = prepared(named: "1_right_arm")
    static let joystickBase: UIImage = prepared(named: "base")
    static let poke: UIImage = prepared(named: "poke")
    static let lightArrow: UIImage = prepared(named: "light arrow")
    static let grabHousing: UIImage = prepared(named: "button3")
    static let grabCap: UIImage = prepared(named: "button2")
    static let grabLip: UIImage = prepared(named: "button1")
    static let scorePad: UIImage = prepared(named: "score_pad")

    static func prewarm() {
        _ = nut
        _ = elephantClaw
        _ = elephantBottom
        _ = elephantHead
        _ = elephantLeftArm
        _ = elephantRightArm
        _ = joystickBase
        _ = poke
        _ = lightArrow
        _ = grabHousing
        _ = grabCap
        _ = grabLip
        _ = scorePad
    }

    private static func prepared(named name: String) -> UIImage {
        let image = UIImage(named: name) ?? UIImage()
        return image.preparingForDisplay() ?? image
    }
}
#endif

// MARK: - Palette

struct ClawPalette: Equatable {
    let character: AnimalCharacter

    // Keep the material recognisably wood and foliage, but stain every cabinet
    // with the selected animal's colours. The old fixed brown/green treatment
    // made changing character feel like changing only a badge.
    var wood: Color { mix(character.primaryRGB, (0.55, 0.34, 0.16), 0.66) }
    var woodDeep: Color { mix(character.deepRGB, (0.27, 0.14, 0.055), 0.58) }
    var woodLight: Color { mix(character.tintRGB, (0.82, 0.60, 0.31), 0.58) }
    var leaf: Color { mix(character.deepRGB, (0.22, 0.54, 0.19), 0.72) }
    var leafLight: Color { mix(character.primaryRGB, (0.49, 0.79, 0.31), 0.68) }
    var glass: Color { character.skyColor.opacity(0.35) }
    var interior: Color { mix(character.skyRGB, (0.82, 0.86, 0.78), 0.18) }
    var bin: Color { character.color }
    var binDeep: Color { character.deepColor }
    var button: Color { Color(red: 0.86, green: 0.18, blue: 0.16) }
    var buttonDeep: Color { Color(red: 0.62, green: 0.08, blue: 0.08) }

    private func mix(_ base: (Double, Double, Double),
                     _ material: (Double, Double, Double),
                     _ materialAmount: Double) -> Color {
        let t = min(1, max(0, materialAmount))
        return Color(red: base.0 + (material.0 - base.0) * t,
                     green: base.1 + (material.1 - base.1) * t,
                     blue: base.2 + (material.2 - base.2) * t)
    }
}

// MARK: - Tutorial

struct ClawTutorialPlan: Equatable {
    var isActive = false
    var wantsMove = false
    var suppressesGrab = false
}

enum ClawTutorialEvent {
    case movedClaw
    case pressedGrab
}

// MARK: - Runtime nut

struct ClawNutRuntime: Identifiable {
    var spec: ClawNut
    var rest: CGPoint
    var position: CGPoint
    var isPresent: Bool
    var rotation: Double
    var pixelRadius: CGFloat

    var id: UUID { spec.id }
}

struct FlyingScore: Identifiable {
    let id = UUID()
    var start: CGPoint
    var end: CGPoint
    var age: Double
    let duration: Double
}

enum ClawPhase: Equatable {
    case idle
    case descending
    case grabbing
    case ascending
    case carrying
    case dropping
    case spitBack
    case returning
    case timeUp
    case celebrating
}

// MARK: - Engine

@MainActor
final class ClawEngine: ObservableObject {
#if canImport(UIKit)
    private final class DisplayLinkTarget: NSObject {
        weak var owner: ClawEngine?
        init(owner: ClawEngine) { self.owner = owner }
        @objc func advance(_ displayLink: CADisplayLink) {
            owner?.advance(displayLink)
        }
    }
    private lazy var displayLinkTarget = DisplayLinkTarget(owner: self)
    private var displayLink: CADisplayLink?
    private var lastFrameTargetTimestamp: CFTimeInterval?
#else
    private var timer: Timer?
#endif

    // Per-frame pose is *not* `@Published`. Assigning twelve published
    // properties (and then sending `objectWillChange` as well) made SwiftUI
    // invalidate the whole cabinet 60 times a second. One coalesced send at
    // the end of `tick` is enough for the moving layers; static scenery is
    // Equatable and skips those invalidations.
    var trolleyX: CGFloat = 0.5
    var trolleyY: CGFloat = 0
    var swingAngle: CGFloat = 0
    @Published var phase: ClawPhase = .idle
    var nuts: [ClawNutRuntime] = []
    var heldNutID: UUID?
    var motionClock = 0.0
    var flyingScores: [FlyingScore] = []
    var buttonPressed = false
    var joystickInput: CGFloat = 0
    var elephantVisible = true
    var elephantBodyVisible = true
    var promptPulse = 0.0
    private(set) var highlightedNutIDs: Set<UUID> = []
    private var lastHighCadence = true
    private var buttonPressAge: Double?

    var onGrabResolved: ((ClawNut, Bool) -> Void)?
    var onScoreBubbleArrived: (() -> Void)?
    var onEntranceComplete: (() -> Void)?
    var onLevelCompletionFinished: (() -> Void)?
    var onTimeOutFinished: (() -> Void)?
    var onTutorialEvent: ((ClawTutorialEvent) -> Void)?

    private var size: CGSize = .zero
    private var playRect: CGRect = .zero
    private var pileRect: CGRect = .zero
    private var binRect: CGRect = .zero
    private var headerRect: CGRect = .zero
    private var panelRect: CGRect = .zero
    private var restY: CGFloat = 0
    private var isLive = false
    private var isRunning = false
    private var isPad = false
    private var input: CGFloat = 0
    private var swingVelocity: CGFloat = 0
    private var lastTrolleyX: CGFloat = 0.5
    private(set) var phaseAge: Double = 0
    private var grabTarget: UUID?
    private var grabStartX: CGFloat = 0.5
    private var grabDepth: CGFloat = 0.7
    private var grabFrom: CGPoint = .zero
    private var descendTime = ClawConfig.descendDuration
    private var ascendTime = ClawConfig.ascendDuration
    private var carryTime = ClawConfig.carryDuration
    private var returnTime = ClawConfig.returnDuration
    private var returnFromX: CGFloat = 0.5
    private var carryFromX: CGFloat = 0.5
    private var dropFrom: CGPoint = .zero
    private var dropTo: CGPoint = .zero
    private var dropFlightTime = ClawConfig.dropDuration
    private var trolleyMinX: CGFloat = 0.06
    private var trolleyMaxFreeX: CGFloat = 0.72
    private var spitFrom: CGPoint = .zero
    private var spitTo: CGPoint = .zero
    private var spitFlightTime = ClawConfig.spitDuration
    private var currentTargetNutID: UUID?
    private var currentAnswer: AnswerValue?
    private var tutorialPlan = ClawTutorialPlan()
    private var hasReportedMove = false
    private var scoreTarget: CGPoint?
    private var entranceAge: Double?
    private var finaleAge: Double?
    private var finaleStartX: CGFloat = 0.5
    private var reduceMotion = false
    private var slides: [ClawPuzzle.Fall] = []
    private var slideStart: [UUID: CGPoint] = [:]
    private var slideEnd: [UUID: CGPoint] = [:]
    private var slideAge: Double = 0
    private var reversingSlides = false

    var acceptsGrab: Bool {
        isLive && phase == .idle && !tutorialPlan.suppressesGrab
    }

    func layout(size: CGSize,
                topReserve: CGFloat,
                bottomReserve: CGFloat,
                isPad: Bool) {
        self.size = size
        self.isPad = isPad
        let post: CGFloat = isPad ? 38 : 26
        let headerH: CGFloat = isPad ? 64 : 52
        let shortSide = min(size.width, size.height)
        // The controls are authored as deep, perspective canvases. Giving the
        // shelf a width-led height keeps their feet on the wood instead of
        // shrinking the whole assembly into a thin toolbar on iPad.
        let panelH: CGFloat = isPad
            ? min(210, max(164, shortSide * 0.20))
            : min(132, max(112, shortSide * 0.31))
        let top = topReserve + 2
        let headerW = min(size.width - post * 2 - (isPad ? 200 : 150), size.width * 0.50)
        headerRect = CGRect(x: (size.width - headerW) / 2, y: top, width: headerW, height: headerH)
        panelRect = CGRect(x: 0,
                           y: size.height - panelH - max(bottomReserve * 0.12, 2),
                           width: size.width,
                           height: panelH + max(bottomReserve * 0.12, 2))
        let cabinetOverlap = panelH * 0.28
        playRect = CGRect(x: post,
                          y: headerRect.maxY + 8,
                          width: size.width - post * 2,
                          height: max(180, panelRect.minY + cabinetOverlap - headerRect.maxY - 2))
        let binW = playRect.width * 0.18
        let binH = playRect.height * 0.52
        binRect = CGRect(x: playRect.maxX - binW - playRect.width * 0.01,
                         y: playRect.maxY - binH,
                         width: binW,
                         height: binH)
        // Keep the pile clear of the inner left bezel. Removing the old right
        // gap at the same time preserves its exact scale and only translates
        // the mound toward the collection bin.
        let pileLeft = playRect.minX + playRect.width * 0.035
        pileRect = CGRect(x: pileLeft,
                          y: playRect.minY + playRect.height * 0.22,
                          width: max(40, binRect.minX - pileLeft),
                          height: playRect.height * 0.76)
        trolleyMinX = 0.06
        let pileRight = CGFloat((pileRect.maxX - playRect.minX) / max(playRect.width, 1))
        let holeLeft = CGFloat((binRect.minX - playRect.minX) / max(playRect.width, 1))
        trolleyMaxFreeX = min(pileRight, holeLeft - 0.02)
        if phase == .idle {
            trolleyX = min(trolleyMaxFreeX, max(trolleyMinX, trolleyX))
        }
        restY = 0
        relayoutNuts()
    }

    func install(puzzle: ClawPuzzle?, collected: Int, question: MathQuestion?, targetNutID: UUID?) {
        elephantVisible = true
        elephantBodyVisible = true
        currentTargetNutID = targetNutID
        currentAnswer = question.map { AnswerValue($0.correctAnswer) }
        promptPulse = 1
        guard let puzzle else {
            nuts = []
            highlightedNutIDs = []
            return
        }
        let remaining = puzzle.remainingNuts(afterCollected: collected)
        nuts = remaining.map { spec in
            let rest = screenPoint(spec.position)
            return ClawNutRuntime(spec: spec,
                                  rest: rest,
                                  position: rest,
                                  isPresent: true,
                                  rotation: 0,
                                  pixelRadius: ClawConfig.nutPixelRadius(unit: spec.radius,
                                                                         pile: pileRect.size))
        }
        refreshReachableCovering()
        ensureTargetGrabable()
        refreshHighlights()
    }

    func setQuestion(_ question: MathQuestion?, targetNutID: UUID?) {
        currentTargetNutID = targetNutID
        currentAnswer = question.map { AnswerValue($0.correctAnswer) }
        promptPulse = 1
        ensureTargetGrabable()
        refreshHighlights()
    }

    func setLive(_ live: Bool) { isLive = live }

    func setRunning(_ running: Bool) {
        isRunning = running
        if running { startLink() } else { stopLink(); input = 0; joystickInput = 0 }
    }

    func setScoreTarget(_ target: CGPoint?) { scoreTarget = target }

    func applyTutorial(_ plan: ClawTutorialPlan) {
        tutorialPlan = plan
        hasReportedMove = false
    }

    func setInput(_ value: CGFloat) {
        let clamped = max(-1, min(1, value))
        // Always snap the stick back, even if a grab started mid-drag.
        joystickInput = clamped
        guard phase == .idle || phase == .returning else { return }
        input = clamped
        if abs(input) > 0.25, tutorialPlan.wantsMove, !hasReportedMove {
            hasReportedMove = true
            onTutorialEvent?(.movedClaw)
        }
    }

    func pressGrab() {
        guard acceptsGrab else { return }
        onTutorialEvent?(.pressedGrab)
        buttonPressed = true
        buttonPressAge = 0
        startGrab()
    }

    func beginEntrance(completion: @escaping () -> Void) {
        onEntranceComplete = completion
        entranceAge = 0
        trolleyY = -0.55
        swingAngle = 0.35
        elephantVisible = true
        elephantBodyVisible = true
    }

    func beginLevelCompletion(reduceMotion: Bool, completion: @escaping () -> Void) {
        self.reduceMotion = reduceMotion
        onLevelCompletionFinished = completion
        phase = .celebrating
        phaseAge = 0
        finaleAge = 0
        heldNutID = nil
        input = 0
        finaleStartX = binUnitX
        trolleyX = finaleStartX
        lastTrolleyX = trolleyX
        trolleyY = 0
        swingVelocity = 0
        swingAngle = 0
        elephantVisible = true
        elephantBodyVisible = true
    }

    func beginTimeUp(reduceMotion: Bool, completion: @escaping () -> Void) {
        self.reduceMotion = reduceMotion
        onTimeOutFinished = completion
        phase = .timeUp
        phaseAge = 0
        finaleAge = 0
        heldNutID = nil
        input = 0
        finaleStartX = trolleyX
        trolleyY = 0
        swingVelocity = 0
        isLive = false
        elephantVisible = true
        elephantBodyVisible = true
    }

    func stop() {
        stopLink()
        onGrabResolved = nil
        onScoreBubbleArrived = nil
        onEntranceComplete = nil
        onLevelCompletionFinished = nil
        onTimeOutFinished = nil
        onTutorialEvent = nil
    }

    // MARK: Grab

    private func startGrab() {
        let target = nearestNut()
        grabTarget = target?.id
        grabStartX = trolleyX
        grabDepth = depthToward(target)
        descendTime = max(0.38, ClawConfig.descendDuration * Double(grabDepth))
        ascendTime = max(0.34, ClawConfig.ascendDuration * Double(grabDepth))
        phase = .descending
        phaseAge = 0
        input = 0
        joystickInput = 0
    }

    private func depthToward(_ target: ClawNutRuntime?) -> CGFloat {
        let elephant = ClawConfig.elephantVisibleHeight(isPad: isPad)
        let restY = playRect.minY + ClawConfig.elephantRopeLength(isPad: isPad)
        let span = max(90, pileRect.maxY - restY - elephant * 0.22)
        guard let target else {
            let emptyGrabY = pileRect.minY + 8
            return max(0.28, min(1, (emptyGrabY - restY) / span))
        }

        // Solve from the visible hand position back to the trolley. The old
        // calculation used 0.78 here while `trunkPoint` used 0.92, then also
        // forced a 0.28 minimum descent. On a tall pile both errors made the
        // elephant pass the nut before its hands closed around it.
        let gripReach = elephant * ClawConfig.elephantGripReach
        let desiredTrolleyY = target.position.y - cos(swingAngle) * gripReach
        return max(0, min(1, (desiredTrolleyY - restY) / span))
    }

    private func nearestNut() -> ClawNutRuntime? {
        let remaining = nuts.filter(\.isPresent)
        let specs = remaining.map(\.spec)
        let grabable = remaining.filter { ClawPuzzle.isGrabable($0.spec, among: specs) }
        let trolley = trolleyScreen
        let reach = pileRect.width * 0.16
        return grabable
            .map { nut in (nut, abs(nut.position.x - trolley.x)) }
            .filter { $0.1 < max(reach, $0.0.pixelRadius * 1.35) }
            .min { lhs, rhs in
                if abs(lhs.1 - rhs.1) > 4 { return lhs.1 < rhs.1 }
                let freeL = ClawPuzzle.isReachable(lhs.0.spec, among: specs)
                let freeR = ClawPuzzle.isReachable(rhs.0.spec, among: specs)
                if freeL != freeR { return freeL }
                return lhs.0.position.y < rhs.0.position.y
            }?
            .0
    }

    // MARK: Tick

#if canImport(UIKit)
    private func advance(_ displayLink: CADisplayLink) {
        let dt: Double
        if let last = lastFrameTargetTimestamp {
            dt = min(1.0 / 30.0, max(1.0 / 120.0, displayLink.targetTimestamp - last))
        } else {
            dt = ClawConfig.tick
        }
        lastFrameTargetTimestamp = displayLink.targetTimestamp
        tick(dt: dt)
    }
#endif

    private func tick(dt: Double) {
        motionClock += dt
        if promptPulse > 0 {
            promptPulse = max(0, promptPulse - dt * 1.8)
        }
        if let age = entranceAge {
            let next = age + dt
            let t = min(1, next / ClawConfig.entranceDuration)
            let eased = 1 - pow(1 - t, 3)
            trolleyY = -0.55 * (1 - eased)
            swingAngle = 0.35 * cos(t * .pi * 2.2) * (1 - t)
            entranceAge = next
            if t >= 1 {
                entranceAge = nil
                trolleyY = 0
                swingAngle = 0
                onEntranceComplete?()
            }
        }
        stepTrolley(dt: dt)
        stepSwing(dt: dt)
        stepPhase(dt: dt)
        stepCascade(dt: dt)
        stepFlights(dt: dt)
        stepButtonPress(dt: dt)
        applyCadence()
        objectWillChange.send()
    }

    private func stepTrolley(dt: Double) {
        guard phase == .idle, entranceAge == nil else { return }
        let previous = trolleyX
        trolleyX = max(trolleyMinX, min(trolleyMaxFreeX, trolleyX + input * ClawConfig.trolleySpeed * dt))
        lastTrolleyX = previous
    }

    private func stepSwing(dt: Double) {
        let dtg = CGFloat(dt)
        let velocity = (trolleyX - lastTrolleyX) / max(dtg, 0.0001)
        swingVelocity += -velocity * ClawConfig.swingDrive * dtg
        swingVelocity += -swingAngle * ClawConfig.swingSpring * dtg
        swingVelocity += -swingVelocity * ClawConfig.swingDamping * dtg
        if phase == .idle, abs(input) < 0.04, entranceAge == nil {
            swingVelocity += CGFloat(sin(motionClock * 1.35)) * 0.018 * dtg
        }
        swingAngle += swingVelocity * dtg
        swingAngle = max(-ClawConfig.maxSwing, min(ClawConfig.maxSwing, swingAngle))
        lastTrolleyX = trolleyX
    }

    private func stepPhase(dt: Double) {
        phaseAge += dt
        switch phase {
        case .idle:
            break
        case .descending:
            let t = min(1, phaseAge / descendTime)
            // The swing keeps settling during the descent. Re-solve the end
            // depth each frame so the hands still finish on the nut centre.
            if let id = grabTarget,
               let target = nuts.first(where: { $0.id == id }) {
                grabDepth = depthToward(target)
            }
            trolleyY = easeInOut(t) * grabDepth
            if t >= 1 {
                if let id = grabTarget, let index = nuts.firstIndex(where: { $0.id == id }) {
                    grabFrom = nuts[index].position
                    beginCascade(removing: nuts[index])
                }
                enter(.grabbing)
            }
        case .grabbing:
            if let id = grabTarget, let index = nuts.firstIndex(where: { $0.id == id }) {
                heldNutID = id
                let u = easeOut(min(1, phaseAge / ClawConfig.grabPause))
                nuts[index].position = lerp(grabFrom, trunkPoint, u)
            }
            if phaseAge >= ClawConfig.grabPause { enter(.ascending) }
        case .ascending:
            let t = min(1, phaseAge / ascendTime)
            trolleyY = grabDepth * (1 - easeInOut(t))
            if let id = heldNutID, let index = nuts.firstIndex(where: { $0.id == id }) {
                nuts[index].position = trunkPoint
            }
            if t >= 1 {
                if heldNutID == nil {
                    enter(.returning)
                } else {
                    carryFromX = trolleyX
                    let span = abs(binUnitX - carryFromX)
                    carryTime = max(0.38, Double(span) / 0.82)
                    enter(.carrying)
                }
            }
        case .carrying:
            let t = min(1, phaseAge / carryTime)
            let binX = binUnitX
            trolleyX = carryFromX + (binX - carryFromX) * easeInOut(t)
            trolleyY = 0
            if let id = heldNutID, let index = nuts.firstIndex(where: { $0.id == id }) {
                nuts[index].position = trunkPoint
            }
            if t >= 1 {
                prepareDrop()
                enter(.dropping)
            }
        case .dropping:
            guard let id = heldNutID, let index = nuts.firstIndex(where: { $0.id == id }) else {
                enter(.returning)
                return
            }
            let t = min(1, phaseAge / dropFlightTime)
            if t < 1 {
                nuts[index].position = dropFall(t)
            } else {
                nuts[index].position = dropTo
            }
            nuts[index].rotation += dt * 0.6
            if phaseAge >= dropFlightTime + ClawConfig.dropSettle {
                finishDrop(index: index)
            }
        case .spitBack:
            guard let id = heldNutID, let index = nuts.firstIndex(where: { $0.id == id }) else {
                enter(.returning)
                return
            }
            let t = min(1, phaseAge / spitFlightTime)
            nuts[index].position = ballistic(from: spitFrom, to: spitTo, t: t, duration: spitFlightTime)
            nuts[index].rotation += dt * 2.6
            if !reversingSlides, phaseAge >= spitFlightTime - reverseHandoffLead {
                reverseCascade()
            }
            if t >= 1 {
                nuts[index].position = spitTo
                nuts[index].rest = spitTo
                nuts[index].isPresent = true
                heldNutID = nil
                if !reversingSlides { reverseCascade() }
                refreshHighlights()
                enter(.returning)
            }
        case .returning:
            let t = min(1, phaseAge / returnTime)
            let target = min(trolleyMaxFreeX, max(trolleyMinX, grabStartX))
            trolleyX = returnFromX + (target - returnFromX) * easeInOut(t)
            trolleyY = 0
            if t >= 1 {
                trolleyX = target
                enter(.idle)
            }
        case .timeUp:
            stepTimeUp(dt: dt)
        case .celebrating:
            stepCelebration(dt: dt)
        }
    }

    private func finishDrop(index: Int) {
        let nut = nuts[index].spec
        let matchesValue = currentAnswer.map { AnswerValue(nut.text) == $0 } ?? false
        let correct: Bool
        if let targetID = currentTargetNutID,
           nuts.contains(where: { $0.id == targetID }) {
            correct = nut.id == targetID
        } else {
            correct = matchesValue
        }
        if correct {
            nuts[index].isPresent = false
            heldNutID = nil
            commitCascade()
            refreshHighlights()
            onGrabResolved?(nut, true)
            onScoreBubbleArrived?()
            enter(.returning)
        } else {
            spitFrom = binMouth
            spitTo = nuts[index].rest
            nuts[index].position = spitFrom
            spitFlightTime = flightTime(from: spitFrom, to: spitTo)
            onGrabResolved?(nut, false)
            enter(.spitBack)
        }
    }

    private func prepareDrop() {
        guard let id = heldNutID, let index = nuts.firstIndex(where: { $0.id == id }) else { return }
        dropFrom = nuts[index].position
        dropTo = binShaft
        let fall = max(36, dropTo.y - dropFrom.y)
        dropFlightTime = Double(sqrt(2 * fall / ClawConfig.dropGravity))
    }

    /// Released from rest above the crate: straight down, accelerating.
    private func dropFall(_ t: Double) -> CGPoint {
        let elapsed = CGFloat(t) * CGFloat(max(dropFlightTime, 0.01))
        let y = dropFrom.y + 0.5 * ClawConfig.dropGravity * elapsed * elapsed
        let x = dropFrom.x + (dropTo.x - dropFrom.x) * CGFloat(min(1, t * 1.35))
        return CGPoint(x: x, y: min(y, dropTo.y))
    }

    private func flightTime(from: CGPoint, to: CGPoint) -> Double {
        let travel = hypot(to.x - from.x, to.y - from.y)
        return min(1.35, max(0.92, Double(travel) / 360.0))
    }

    private func ballistic(from: CGPoint, to: CGPoint, t: Double, duration: Double) -> CGPoint {
        let duration = CGFloat(max(duration, 0.01))
        let elapsed = CGFloat(t) * duration
        let gravity: CGFloat = 2050
        let vx = (to.x - from.x) / duration
        let vy0 = (to.y - from.y) / duration - 0.5 * gravity * duration
        return CGPoint(x: from.x + vx * elapsed,
                       y: from.y + vy0 * elapsed + 0.5 * gravity * elapsed * elapsed)
    }

    private func stepTimeUp(dt: Double) {
        let move = smoothStep(min(1, phaseAge / 0.48))
        trolleyX = finaleStartX + (binUnitX - finaleStartX) * CGFloat(move)
        trolleyY = 0
        swingAngle = CGFloat(sin(move * .pi)) * 0.10 * (1 - CGFloat(move))
        lastTrolleyX = trolleyX
        if phaseAge >= ClawConfig.timeUpDuration {
            elephantBodyVisible = false
            onTimeOutFinished?()
            phase = .idle
        }
    }

    private func stepCelebration(dt: Double) {
        let center: CGFloat = 0.5
        let leftAngle = ClawConfig.celebrationLeftAngle
        let releaseAngle = ClawConfig.celebrationReleaseAngle

        if reduceMotion {
            trolleyX = center
            swingAngle = 0
        } else if phaseAge < ClawConfig.celebrationCenterArrival {
            let p = smoothStep(phaseAge / ClawConfig.celebrationCenterArrival)
            trolleyX = finaleStartX + (center - finaleStartX) * CGFloat(p)
            // The trolley brakes at centre while the loaded body continues to
            // the left. Both position and angle arrive with zero velocity.
            swingAngle = leftAngle * CGFloat(p)
        } else if phaseAge < ClawConfig.celebrationRelease {
            let span = ClawConfig.celebrationRelease - ClawConfig.celebrationCenterArrival
            let p = min(1, max(0,
                (phaseAge - ClawConfig.celebrationCenterArrival) / span
            ))
            trolleyX = center
            // Starting quadratically from the left apex gives zero initial
            // speed and a non-zero rightward speed at the release frame.
            swingAngle = leftAngle + (releaseAngle - leftAngle) * CGFloat(p * p)
        } else {
            trolleyX = center
            let recoil = smoothStep(min(1, (phaseAge - ClawConfig.celebrationRelease) / 0.30))
            // Only the empty claw settles after it lets go.
            swingAngle = releaseAngle * (1 - CGFloat(recoil))
        }
        trolleyY = 0
        lastTrolleyX = trolleyX

        if phaseAge >= ClawConfig.completionDuration {
            elephantBodyVisible = false
            onLevelCompletionFinished?()
            phase = .idle
        }
    }

    private func stepFlights(dt: Double) {
        guard !flyingScores.isEmpty else { return }
        for i in flyingScores.indices {
            flyingScores[i].age += dt
        }
        let finished = flyingScores.filter { $0.age >= $0.duration }
        flyingScores.removeAll { $0.age >= $0.duration }
        if !finished.isEmpty {
            onScoreBubbleArrived?()
        }
    }

    private func enter(_ next: ClawPhase) {
        phase = next
        phaseAge = 0
        if next == .idle {
            trolleyX = min(trolleyMaxFreeX, max(trolleyMinX, trolleyX))
            ensureTargetGrabable()
            refreshHighlights()
        }
        if next == .returning {
            returnFromX = trolleyX
            let target = min(trolleyMaxFreeX, max(trolleyMinX, grabStartX))
            returnTime = max(0.26, Double(abs(target - returnFromX)) / 0.95)
        }
    }

    private func stepButtonPress(dt: Double) {
        guard let age = buttonPressAge else { return }
        let next = age + dt
        if next >= 0.28 {
            buttonPressed = false
            buttonPressAge = nil
        } else {
            buttonPressAge = next
        }
    }

    private func refreshReachableCovering() {
        var specs = nuts.map(\.spec)
        for i in specs.indices {
            specs[i].position = unitPoint(nuts[i].rest)
        }
        _ = specs
    }

    private func beginCascade(removing grabbed: ClawNutRuntime) {
        let present = nuts.filter(\.isPresent).map(\.spec)
        slides = ClawPuzzle.fallChain(removing: grabbed.spec, among: present)
        reversingSlides = false
        slideAge = 0
        slideStart = [:]
        slideEnd = [:]
        for fall in slides {
            guard let i = nuts.firstIndex(where: { $0.id == fall.id }) else { continue }
            let from = nuts[i].rest
            let to = screenPoint(fall.to)
            slideStart[fall.id] = from
            slideEnd[fall.id] = to
            nuts[i].rest = to
            nuts[i].spec.position = fall.to
        }
    }

    private func stepCascade(dt: Double) {
        guard !slides.isEmpty else { return }
        slideAge += dt
        var allDone = true
        for (index, fall) in slides.enumerated() {
            guard let i = nuts.firstIndex(where: { $0.id == fall.id }),
                  heldNutID != fall.id else { continue }
            let delay = Double(index) * ClawConfig.cascadeStagger
            let t = min(1, max(0, (slideAge - delay) / ClawConfig.cascadeDuration))
            if t < 1 { allDone = false }
            let from = slideStart[fall.id] ?? nuts[i].position
            let to = slideEnd[fall.id] ?? nuts[i].rest
            nuts[i].position = lerp(from, to, easeInOut(t))
        }
        if allDone, reversingSlides {
            slides = []
            reversingSlides = false
            slideStart = [:]
            slideEnd = [:]
        }
    }

    private func reverseCascade() {
        guard !slides.isEmpty, !reversingSlides else { return }
        reversingSlides = true
        slideAge = 0
        for fall in slides.reversed() {
            guard let i = nuts.firstIndex(where: { $0.id == fall.id }) else { continue }
            slideStart[fall.id] = nuts[i].position
            let original = screenPoint(fall.from)
            slideEnd[fall.id] = original
            nuts[i].rest = original
            nuts[i].spec.position = fall.from
        }
        slides.reverse()
        refreshHighlights()
    }

    /// Start reversing early enough that the nut sitting in the vacated hole
    /// is halfway home as the spit nut lands — a handoff, not a stack.
    private var reverseHandoffLead: Double {
        let occupantDelay = Double(max(slides.count - 1, 0)) * ClawConfig.cascadeStagger
        return occupantDelay + ClawConfig.cascadeDuration * 0.5
    }

    private func commitCascade() {
        slides = []
        reversingSlides = false
        slideStart = [:]
        slideEnd = [:]
    }

    func unitPoint(_ screen: CGPoint) -> ClawPoint {
        let scale = max(pileRect.width, 1)
        return ClawPoint(x: Double((screen.x - pileRect.minX) / scale),
                         y: Double(1 - (pileRect.maxY - screen.y) / scale))
    }

    private func relayoutNuts() {
        for i in nuts.indices {
            let rest = screenPoint(nuts[i].spec.position)
            nuts[i].rest = rest
            if heldNutID != nuts[i].id, slideStart[nuts[i].id] == nil {
                nuts[i].position = rest
            }
            nuts[i].pixelRadius = ClawConfig.nutPixelRadius(unit: nuts[i].spec.radius,
                                                            pile: pileRect.size)
        }
    }

    func screenPoint(_ unit: ClawPoint) -> CGPoint {
        // Pack in width-pixels on both axes so hex spacing stays round. The
        // mound sits on the floor of the pile; extra glass height stays empty
        // for the hanging elephant.
        let scale = pileRect.width
        return CGPoint(x: pileRect.minX + scale * CGFloat(unit.x),
                       y: pileRect.maxY - scale * CGFloat(1 - unit.y))
    }

    var trolleyScreen: CGPoint {
        let elephant = ClawConfig.elephantVisibleHeight(isPad: isPad)
        let restY = playRect.minY + ClawConfig.elephantRopeLength(isPad: isPad)
        let span = max(90, pileRect.maxY - restY - elephant * 0.22)
        return CGPoint(x: playRect.minX + playRect.width * trolleyX,
                       y: restY + trolleyY * span)
    }

    var trunkPoint: CGPoint {
        let origin = trolleyScreen
        let length = ClawConfig.elephantVisibleHeight(isPad: isPad)
            * ClawConfig.elephantGripReach
        // Screen-space rotation and a mathematical y-up rotation lean in
        // opposite horizontal directions. Follow the rendered hands so a
        // walnut cannot drift to the other side of a swinging elephant.
        return CGPoint(x: origin.x - sin(swingAngle) * length,
                       y: origin.y + cos(swingAngle) * length)
    }

    private func refreshHighlights() {
        guard let currentAnswer else {
            highlightedNutIDs = []
            return
        }
        let remaining = nuts.filter(\.isPresent)
        let specs = remaining.map(\.spec)
        if let id = currentTargetNutID,
           let nut = remaining.first(where: { $0.id == id }),
           ClawPuzzle.isGrabable(nut.spec, among: specs) {
            highlightedNutIDs = [id]
            return
        }
        if let match = remaining.first(where: {
            AnswerValue($0.spec.text) == currentAnswer
                && ClawPuzzle.isGrabable($0.spec, among: specs)
        }) {
            highlightedNutIDs = [match.id]
            return
        }
        highlightedNutIDs = []
    }

    /// If the assigned shell is buried, swap it onto a nut the claw can
    /// actually take — same printed value first, otherwise a decoy or later
    /// sum. The round still points at the same id; only the slot moves.
    private func ensureTargetGrabable() {
        guard heldNutID == nil else { return }
        guard let targetID = currentTargetNutID,
              let targetIndex = nuts.firstIndex(where: { $0.id == targetID && $0.isPresent })
        else { return }
        let specs = nuts.filter(\.isPresent).map(\.spec)
        if ClawPuzzle.isGrabable(nuts[targetIndex].spec, among: specs) { return }

        let partners = nuts.indices.filter { index in
            nuts[index].isPresent
                && nuts[index].id != targetID
                && ClawPuzzle.isGrabable(nuts[index].spec, among: specs)
        }
        guard let partner = partners.min(by: { a, b in
            let ra = slotPreference(nuts[a])
            let rb = slotPreference(nuts[b])
            if ra.0 != rb.0 { return ra.0 < rb.0 }
            if ra.1 != rb.1 { return ra.1 < rb.1 }
            return ra.2 < rb.2
        }) else { return }
        swapRuntimeSlots(targetIndex, partner)
    }

    private func slotPreference(_ nut: ClawNutRuntime) -> (Int, Int, Double) {
        let sameValue = currentAnswer.map { AnswerValue(nut.spec.text) == $0 } == true ? 0 : 1
        let decoy = nut.spec.isDistractor ? 0 : 1
        return (sameValue, decoy, nut.spec.position.y)
    }

    private func swapRuntimeSlots(_ i: Int, _ j: Int) {
        let position = nuts[i].spec.position
        let radius = nuts[i].spec.radius
        nuts[i].spec.position = nuts[j].spec.position
        nuts[i].spec.radius = nuts[j].spec.radius
        nuts[j].spec.position = position
        nuts[j].spec.radius = radius
        let rest = nuts[i].rest
        let screen = nuts[i].position
        let pixels = nuts[i].pixelRadius
        nuts[i].rest = nuts[j].rest
        nuts[i].position = nuts[j].position
        nuts[i].pixelRadius = nuts[j].pixelRadius
        nuts[j].rest = rest
        nuts[j].position = screen
        nuts[j].pixelRadius = pixels
    }

    /// Centre of the open top — the chute mouth the nut must enter and leave.
    private var binMouth: CGPoint {
        CGPoint(x: binRect.minX + binRect.width * 0.36,
                y: binRect.minY + binRect.height * 0.15)
    }

    /// Just below the rim, inside the shaft, where the front wall hides the nut.
    private var binShaft: CGPoint {
        CGPoint(x: binMouth.x, y: binRect.minY + binRect.height * 0.36)
    }

    private var binUnitX: CGFloat {
        CGFloat((binMouth.x - playRect.minX) / max(playRect.width, 1))
    }

    var geometry: (play: CGRect, pile: CGRect, bin: CGRect, header: CGRect, panel: CGRect) {
        (playRect, pileRect, binRect, headerRect, panelRect)
    }

    private func startLink() {
#if canImport(UIKit)
        guard displayLink == nil else { return }
        lastFrameTargetTimestamp = nil
        lastHighCadence = true
        let link = CADisplayLink(target: displayLinkTarget,
                                 selector: #selector(DisplayLinkTarget.advance(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 45, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
#else
        guard timer == nil else { return }
        let timer = Timer(timeInterval: ClawConfig.tick, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick(dt: ClawConfig.tick) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
#endif
    }

    private func stopLink() {
#if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        lastFrameTargetTimestamp = nil
        lastHighCadence = true
#else
        timer?.invalidate()
        timer = nil
#endif
    }

    private var wantsHighCadence: Bool {
        phase != .idle || abs(input) > 0.04 || entranceAge != nil || finaleAge != nil || !slides.isEmpty
    }

    private func applyCadence() {
#if canImport(UIKit)
        guard let displayLink else { return }
        let high = wantsHighCadence
        guard high != lastHighCadence else { return }
        lastHighCadence = high
        displayLink.preferredFrameRateRange = high
            ? CAFrameRateRange(minimum: 45, maximum: 60, preferred: 60)
            : CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
#endif
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func easeIn(_ t: Double) -> CGFloat { CGFloat(t * t) }
    private func easeOut(_ t: Double) -> CGFloat { CGFloat(1 - (1 - t) * (1 - t)) }
    private func easeInOut(_ t: Double) -> CGFloat {
        CGFloat(t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2)
    }
    private func smoothStep(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Playfield

struct ClawPlayfield: View {
    let round: GameRound?
    let puzzle: ClawPuzzle?
    let collectedAnswers: Int
    let maximumRounds: Int
    let character: AnimalCharacter
    let isPad: Bool
    let isLive: Bool
    let isRunning: Bool
    let playsEntrance: Bool
    let isStreakBoostActive: Bool
    let playsLevelCompletion: Bool
    let playsTimeOutFinale: Bool
    let reduceMotion: Bool
    var tutorialPlan = ClawTutorialPlan()
    let score: Int
    let topReserve: CGFloat
    let bottomReserve: CGFloat
    let scoreTarget: CGPoint?
    let onGrab: (ClawNut, Bool) -> Void
    let onScoreBubbleArrived: () -> Void
    let onEntranceComplete: () -> Void
    let onLevelCompletionFinished: () -> Void
    let onTimeOutFinished: () -> Void
    var onTutorialEvent: (ClawTutorialEvent) -> Void = { _ in }

    @StateObject private var engine = ClawEngine()
    @State private var didTriggerScreenGrab = false

    private var palette: ClawPalette { ClawPalette(character: character) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                MachineCabinet(palette: palette, size: size)
                    .equatable()
                    .drawingGroup()

                let geo = engine.geometry
                CabinetTopAssembly(
                    palette: palette,
                    size: size,
                    header: geo.header,
                    playTop: geo.play.minY,
                    isPad: isPad
                )
                .equatable()

                CabinetLivingDetails(palette: palette, reduceMotion: reduceMotion)

                glassChamber(geo: geo)

                if engine.elephantVisible {
                    ClawElephantView(
                        origin: engine.trolleyScreen,
                        swing: engine.swingAngle,
                        phase: engine.phase,
                        phaseAge: engine.phaseAge,
                        motionClock: engine.motionClock,
                        play: geo.play,
                        bin: geo.bin,
                        bodyVisible: engine.elephantBodyVisible,
                        reduceMotion: reduceMotion,
                        isPad: isPad
                    )
                    .frame(width: geo.play.width, height: geo.play.height)
                    .position(x: geo.play.midX, y: geo.play.midY)
                }

                if engine.phase == .celebrating || engine.phase == .timeUp {
                    finaleBinForeground(geo: geo)
                }

                ClawPromptPlaque(
                    text: round?.question.prompt ?? "",
                    pulse: engine.promptPulse > 0.02 ? engine.promptPulse : 0,
                    isPad: isPad,
                    palette: palette,
                    roundNumber: round?.number ?? 1,
                    maximumRounds: maximumRounds
                )
                    .equatable()
                    .frame(width: geo.header.width, height: geo.header.height)
                    .position(x: geo.header.midX, y: geo.header.midY)
                    .allowsHitTesting(false)

                let controlSafeTop = geo.panel.height > 1
                    ? max(0, geo.panel.minY - ClawConfig.controlSafetyMargin(isPad: isPad))
                    : size.height
                playfieldTouchLayer(size: size, bottomInset: size.height - controlSafeTop)
                pokeSafetyZone(size: size, top: controlSafeTop)
                grabSafetyZone(size: size, top: controlSafeTop)

                controlPanel
                    .frame(width: geo.panel.width, height: geo.panel.height)
                    .position(x: geo.panel.midX, y: geo.panel.midY)
            }
            .frame(width: size.width, height: size.height)
            .simultaneousGesture(screenGrabSwipe)
            .environment(\.layoutDirection, .leftToRight)
            .onAppear {
                bindEngine()
                engine.layout(size: size,
                              topReserve: topReserve,
                              bottomReserve: bottomReserve,
                              isPad: isPad)
                engine.install(puzzle: puzzle,
                               collected: collectedAnswers,
                               question: round?.question,
                               targetNutID: round?.targetNutID)
                engine.setLive(isLive)
                engine.setRunning(isRunning)
                engine.setScoreTarget(scoreTarget)
                engine.applyTutorial(tutorialPlan)
                if playsEntrance {
                    engine.beginEntrance(completion: onEntranceComplete)
                }
                if playsLevelCompletion {
                    engine.beginLevelCompletion(reduceMotion: reduceMotion,
                                                completion: onLevelCompletionFinished)
                }
                if playsTimeOutFinale {
                    engine.beginTimeUp(reduceMotion: reduceMotion,
                                       completion: onTimeOutFinished)
                }
            }
            .onChange(of: size) { _, newSize in
                engine.layout(size: newSize,
                              topReserve: topReserve,
                              bottomReserve: bottomReserve,
                              isPad: isPad)
            }
        }
        .onChange(of: round?.id) { _, _ in
            engine.setQuestion(round?.question, targetNutID: round?.targetNutID)
        }
        .onChange(of: puzzle?.seed) { _, _ in
            engine.install(puzzle: puzzle,
                           collected: collectedAnswers,
                           question: round?.question,
                           targetNutID: round?.targetNutID)
        }
        .onChange(of: isLive) { _, live in engine.setLive(live) }
        .onChange(of: isRunning) { _, running in engine.setRunning(running) }
        .onChange(of: scoreTarget) { _, target in engine.setScoreTarget(target) }
        .onChange(of: tutorialPlan) { _, plan in engine.applyTutorial(plan) }
        .onChange(of: playsEntrance) { _, should in
            if should { engine.beginEntrance(completion: onEntranceComplete) }
        }
        .onChange(of: playsLevelCompletion) { _, should in
            if should {
                engine.beginLevelCompletion(reduceMotion: reduceMotion,
                                            completion: onLevelCompletionFinished)
            }
        }
        .onChange(of: playsTimeOutFinale) { _, should in
            if should {
                engine.beginTimeUp(reduceMotion: reduceMotion,
                                   completion: onTimeOutFinished)
            }
        }
        .onDisappear { engine.stop() }
        .ignoresSafeArea()
    }

    private func bindEngine() {
        engine.onGrabResolved = onGrab
        engine.onScoreBubbleArrived = onScoreBubbleArrived
        engine.onEntranceComplete = onEntranceComplete
        engine.onLevelCompletionFinished = onLevelCompletionFinished
        engine.onTimeOutFinished = onTimeOutFinished
        engine.onTutorialEvent = onTutorialEvent
    }

    /// Hold the left half to steer left, the right half to steer right, or swipe
    /// down anywhere to drop the claw where it currently hangs. Stops above the
    /// poke / grab safety band so the bottom nut row cannot steal those controls.
    private func playfieldTouchLayer(size: CGSize, bottomInset: CGFloat) -> some View {
        Color.clear
            .frame(width: size.width, height: max(0, size.height - bottomInset))
            .contentShape(Rectangle())
            .gesture(playfieldDrag(width: size.width))
            .accessibilityHidden(true)
    }

    /// Bottom-left band, including the lowest nuts: poke left / right, never
    /// "left half of the screen".
    private func pokeSafetyZone(size: CGSize, top: CGFloat) -> some View {
        let width = min(ClawConfig.pokeSafetyWidth(isPad: isPad), size.width * 0.48)
        let height = max(0, size.height - top)
        return Color.clear
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(joystickDrag(width: width))
            .position(x: width / 2, y: top + height / 2)
            .accessibilityHidden(true)
    }

    /// Bottom-right band: treat as the grab button, not screen-right.
    private func grabSafetyZone(size: CGSize, top: CGFloat) -> some View {
        let width = min(ClawConfig.grabSafetyWidth(isPad: isPad), size.width * 0.48)
        let height = max(0, size.height - top)
        return Color.clear
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(grabSafetyDrag)
            .position(x: size.width - width / 2, y: top + height / 2)
            .accessibilityHidden(true)
    }

    private var grabSafetyDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard !isDownwardSwipe(value) else { return }
                engine.pressGrab()
            }
    }

    private func playfieldDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if isDownwardSwipe(value) {
                    triggerScreenGrab()
                    return
                }
                engine.setInput(value.location.x < width / 2 ? -1 : 1)
            }
            .onEnded { value in
                if !didTriggerScreenGrab, isDownwardSwipe(value) {
                    triggerScreenGrab()
                }
                didTriggerScreenGrab = false
                engine.setInput(0)
            }
    }

    private var screenGrabSwipe: some Gesture {
        DragGesture(minimumDistance: ClawConfig.screenGrabSwipe)
            .onChanged { value in
                guard isDownwardSwipe(value) else { return }
                triggerScreenGrab()
            }
            .onEnded { _ in
                didTriggerScreenGrab = false
            }
    }

    private func triggerScreenGrab() {
        guard !didTriggerScreenGrab else { return }
        didTriggerScreenGrab = true
        engine.setInput(0)
        engine.pressGrab()
    }

    private func isDownwardSwipe(_ value: DragGesture.Value) -> Bool {
        let dy = value.translation.height
        let dx = value.translation.width
        return dy > ClawConfig.screenGrabSwipe && dy > abs(dx)
    }

    // MARK: Machine

    private func glassChamber(geo: (play: CGRect, pile: CGRect, bin: CGRect, header: CGRect, panel: CGRect)) -> some View {
        let corner: CGFloat = isPad ? 26 : 18
        return ZStack(alignment: .topLeading) {
            SanctuaryScene(palette: palette, character: character, isPad: isPad)
                .equatable()
                .drawingGroup()
                .frame(width: geo.play.width, height: geo.play.height)

            SanctuaryLivingDetails(
                isPad: isPad,
                reduceMotion: reduceMotion
            )
            .frame(width: geo.play.width, height: geo.play.height)

            trolleyRail(in: geo.play)

            CatchBinBackView(palette: palette, isPad: isPad)
                .equatable()
                .frame(width: geo.bin.width, height: geo.bin.height)
                .position(x: geo.bin.midX - geo.play.minX, y: geo.bin.midY - geo.play.minY)

            ClawNutPile(
                nuts: engine.nuts,
                highlightedIDs: engine.highlightedNutIDs,
                heldNutID: engine.heldNutID,
                playOrigin: CGPoint(x: geo.play.minX, y: geo.play.minY)
            )
            .frame(width: geo.play.width, height: geo.play.height)

            CatchBinFrontView(palette: palette, isPad: isPad)
                .equatable()
                .frame(width: geo.bin.width, height: geo.bin.height)
                .position(x: geo.bin.midX - geo.play.minX, y: geo.bin.midY - geo.play.minY)

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1.4)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .frame(width: geo.play.width, height: geo.play.height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(palette.woodDeep.opacity(0.92),
                              lineWidth: isPad ? 16 : 11)
            RoundedRectangle(cornerRadius: corner - (isPad ? 3 : 2), style: .continuous)
                .inset(by: isPad ? 4 : 3)
                .strokeBorder(
                    LinearGradient(colors: [palette.woodLight, palette.wood, palette.woodDeep],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: isPad ? 10 : 7
                )
            RoundedRectangle(cornerRadius: corner - (isPad ? 7 : 5), style: .continuous)
                .inset(by: isPad ? 10 : 7)
                .strokeBorder(.black.opacity(0.20), lineWidth: isPad ? 3 : 2)
        }
        .overlay(alignment: .bottom) {
            CabinetGlassSill(palette: palette, isPad: isPad)
                .frame(height: isPad ? 38 : 28)
                .padding(.horizontal, isPad ? 8 : 5)
                .offset(y: isPad ? 13 : 10)
        }
        .shadow(color: .black.opacity(0.30), radius: isPad ? 7 : 4, y: 3)
        .position(x: geo.play.midX, y: geo.play.midY)
    }

    /// During the finale the bin is composited once more above the detached
    /// body. Its authored lid and front wall become the mouth mask, so the
    /// elephant genuinely passes behind the rim instead of fading away.
    private func finaleBinForeground(
        geo: (play: CGRect, pile: CGRect, bin: CGRect, header: CGRect, panel: CGRect)
    ) -> some View {
        ZStack {
            CatchBinBackView(palette: palette, isPad: isPad)
            CatchBinFrontView(palette: palette, isPad: isPad)
        }
        .frame(width: geo.bin.width, height: geo.bin.height)
        .position(x: geo.bin.midX, y: geo.bin.midY)
        .allowsHitTesting(false)
    }

    private func trolleyRail(in play: CGRect) -> some View {
        let x = engine.trolleyScreen.x - play.minX
        return ZStack(alignment: .top) {
            Capsule()
                .fill(
                    LinearGradient(colors: [Color(red: 0.62, green: 0.50, blue: 0.28),
                                            Color(red: 0.28, green: 0.18, blue: 0.08)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(height: isPad ? 10 : 7)
                .padding(.horizontal, 10)
                .padding(.top, 6)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.22, green: 0.18, blue: 0.12))
                .frame(width: isPad ? 28 : 20, height: isPad ? 14 : 10)
                .overlay {
                    Capsule().fill(Color(red: 0.85, green: 0.68, blue: 0.22)).padding(3)
                }
                .position(x: x, y: isPad ? 14 : 11)
        }
        .allowsHitTesting(false)
    }

    private var controlPanel: some View {
        GeometryReader { proxy in
            let layout = ArcadeControlLayout(size: proxy.size, isPad: isPad)
            let board = ArcadeShelfShape(topInset: layout.topInset,
                                         bottomRadius: isPad ? 22 : 15)

            ZStack(alignment: .topLeading) {
                ZStack {
                    board.fill(
                        LinearGradient(
                            colors: [palette.woodDeep,
                                     palette.wood,
                                     palette.woodLight],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    ArcadeShelfSideEdge(topInset: layout.topInset, side: .leading,
                                        thickness: isPad ? 16 : 11)
                        .fill(Color(red: 0.22, green: 0.12, blue: 0.05).opacity(0.45))
                    ArcadeShelfSideEdge(topInset: layout.topInset, side: .trailing,
                                        thickness: isPad ? 16 : 11)
                        .fill(palette.woodDeep.opacity(0.36))
                    woodGrain
                        .clipShape(board)
                    LinearGradient(colors: [Color.black.opacity(0.42), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: isPad ? 22 : 15)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipShape(board)
                    LinearGradient(colors: [.clear,
                                            Color.black.opacity(0.18),
                                            Color.white.opacity(0.20)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: isPad ? 15 : 10)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .clipShape(board)

                    // Thick rear console edge: the dark top is the glass seal,
                    // the warmer face is the wooden lip below it.
                    RoundedRectangle(cornerRadius: isPad ? 5 : 3, style: .continuous)
                        .fill(
                            LinearGradient(colors: [palette.woodDeep,
                                                    palette.wood,
                                                    palette.woodLight,
                                                    palette.woodDeep],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(height: isPad ? 18 : 13)
                        .padding(.horizontal, layout.topInset)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(.black.opacity(0.30))
                                .frame(height: isPad ? 3 : 2)
                                .padding(.horizontal, layout.topInset + 2)
                        }
                        .shadow(color: .black.opacity(0.42), radius: 3, y: 4)
                }
                .frame(width: proxy.size.width, height: layout.shelfHeight)
                .position(x: proxy.size.width / 2,
                          y: layout.shelfTop + layout.shelfHeight / 2)
                .allowsHitTesting(false)

                joystick
                    .frame(width: layout.joystickWidth,
                           height: layout.joystickHeight)
                    .position(x: layout.joystickCenter.x,
                              y: layout.joystickCenter.y)

                ClawPanelScore(score: score, isPad: isPad)
                    .frame(width: layout.scoreWidth,
                           height: layout.scoreHeight)
                    .position(x: layout.scoreCenter.x,
                              y: layout.scoreCenter.y)

                grabButton(side: layout.grabSide)
                    .position(x: layout.grabCenter.x,
                              y: layout.grabCenter.y)
            }
        }
    }

    private var woodGrain: some View {
        VStack(spacing: isPad ? 11 : 9) {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(Color.black.opacity(index.isMultiple(of: 2) ? 0.06 : 0.03))
                    .frame(height: 1.2)
                    .padding(.horizontal, CGFloat(8 + index * 4))
            }
        }
        .padding(.vertical, 10)
        .allowsHitTesting(false)
    }

    private var joystick: some View {
        ClawJoystickChrome(input: engine.joystickInput)
            .equatable()
            .aspectRatio(JoystickArt.canvas.width / JoystickArt.canvas.height, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(joystickDrag(width: proxy.size.width))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("game.claw.joystick"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: engine.setInput(1)
                case .decrement: engine.setInput(-1)
                default: break
                }
            }
    }

    private func joystickDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if value.startLocation.x < width / 3 {
                    engine.setInput(-1)
                } else if value.startLocation.x > width * 2 / 3 {
                    engine.setInput(1)
                } else {
                    let span: CGFloat = isPad ? 40 : 32
                    engine.setInput(max(-1, min(1, value.translation.width / span)))
                }
            }
            .onEnded { _ in engine.setInput(0) }
    }

    private func grabButton(side: CGFloat) -> some View {
        let travel = side * (GrabButtonArt.pressTravel / GrabButtonArt.canvas)
        let faceOffset = side * (GrabButtonArt.labelCenterY - 0.5)

        return Button(action: engine.pressGrab) {
            ZStack {
                grabHousingImage
                    .resizable()
                    .interpolation(.high)

                ZStack {
                    grabCapImage
                        .resizable()
                        .interpolation(.high)
                    Text("game.claw.grab")
                        .font(.system(size: side * 0.20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.32)
                        .allowsTightening(true)
                        .multilineTextAlignment(.center)
                        .frame(width: side * 0.54)
                        .offset(y: faceOffset)
                }
                .offset(y: engine.buttonPressed ? travel : 0)

                grabLipImage
                    .resizable()
                    .interpolation(.high)
            }
            .frame(width: side, height: side)
            .contentShape(Circle())
            .animation(engine.buttonPressed
                           ? .easeIn(duration: 0.08)
                           : .easeOut(duration: 0.24),
                       value: engine.buttonPressed)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("claw-grab")
        .accessibilityLabel(Text("game.claw.grab"))
    }

    private var grabHousingImage: Image {
#if canImport(UIKit)
        Image(uiImage: ClawArtworkCache.grabHousing)
#else
        Image("button3")
#endif
    }

    private var grabCapImage: Image {
#if canImport(UIKit)
        Image(uiImage: ClawArtworkCache.grabCap)
#else
        Image("button2")
#endif
    }

    private var grabLipImage: Image {
#if canImport(UIKit)
        Image(uiImage: ClawArtworkCache.grabLip)
#else
        Image("button1")
#endif
    }
}

/// Optical layout for the three authored control canvases. The reference art
/// is composed on a 1024-point cabinet; `stageWidth` preserves those ratios on
/// portrait screens and keeps the group centred instead of stretching it on a
/// wide iPad. Positions are based on the visible artwork, not equal HStack
/// cells (the score pad intentionally has large transparent side margins).
private struct ArcadeControlLayout {
    let size: CGSize
    let isPad: Bool

    var stageWidth: CGFloat {
        min(size.width, size.height * (isPad ? 5.0 : 5.3))
    }

    var stageOriginX: CGFloat { (size.width - stageWidth) / 2 }
    var shelfTop: CGFloat { size.height * (isPad ? 0.27 : 0.25) }
    var shelfHeight: CGFloat { max(1, size.height - shelfTop) }
    var topInset: CGFloat {
        min(isPad ? 82 : 36, max(isPad ? 44 : 18, size.width * 0.075))
    }

    var joystickWidth: CGFloat { stageWidth * 0.38 }
    var joystickHeight: CGFloat {
        joystickWidth * JoystickArt.canvas.height / JoystickArt.canvas.width
    }
    var scoreWidth: CGFloat { stageWidth * 0.285 }
    var scoreHeight: CGFloat {
        scoreWidth * ScorePadArt.canvas.height / ScorePadArt.canvas.width
    }
    var grabSide: CGFloat { stageWidth * 0.265 }

    var joystickCenter: CGPoint {
        CGPoint(x: stageOriginX + stageWidth * 0.27, y: size.height * 0.50)
    }
    var scoreCenter: CGPoint {
        CGPoint(x: stageOriginX + stageWidth * 0.568, y: size.height * 0.53)
    }
    var grabCenter: CGPoint {
        CGPoint(x: stageOriginX + stageWidth * 0.79, y: size.height * 0.55)
    }
}

private enum GrabButtonArt {
    static let canvas: CGFloat = 1254
    /// Cap travel into the housing, in canvas pixels.
    static let pressTravel: CGFloat = 88
    /// Centre of the red top face, as a fraction of the square canvas.
    static let labelCenterY: CGFloat = 470 / 1254
}

private struct ClawPanelScore: View {
    let score: Int
    let isPad: Bool

    private var digits: [Int] {
        let clamped = min(99, max(0, score))
        return [clamped / 10, clamped % 10]
    }

    var body: some View {
        ZStack {
            scorePadImage
                .resizable()
                .interpolation(.high)
            GeometryReader { proxy in
                let sx = proxy.size.width / ScorePadArt.canvas.width
                let sy = proxy.size.height / ScorePadArt.canvas.height
                let well = CGRect(x: ScorePadArt.well.minX * sx,
                                  y: ScorePadArt.well.minY * sy,
                                  width: ScorePadArt.well.width * sx,
                                  height: ScorePadArt.well.height * sy)
                HStack(spacing: well.width * 0.10) {
                    ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                        SevenSegmentDigit(value: digit)
                    }
                }
                .frame(width: well.width, height: well.height * 0.78, alignment: .center)
                .position(x: well.midX, y: well.midY)
            }
        }
        .aspectRatio(ScorePadArt.canvas.width / ScorePadArt.canvas.height, contentMode: .fit)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ScoreIconCenterPreferenceKey.self,
                    value: CGPoint(x: proxy.frame(in: .global).midX,
                                   y: proxy.frame(in: .global).midY)
                )
            }
        }
        .accessibilityIdentifier("progress")
        .accessibilityLabel(Text(L("game.bubblesCollected \(score)")))
        .allowsHitTesting(false)
    }

    private var scorePadImage: Image {
#if canImport(UIKit)
        Image(uiImage: ClawArtworkCache.scorePad)
#else
        Image("score_pad")
#endif
    }
}

private enum ScorePadArt {
    static let canvas = CGSize(width: 387, height: 244)
    /// Recessed LED face on `score_pad`.
    static let well = CGRect(x: 136, y: 104, width: 112, height: 76)
}

/// Classic 7-segment digit with unlit ghost segments and a warm gold glow.
private struct SevenSegmentDigit: View {
    var value: Int?

    private static let gold = Color(red: 1.0, green: 0.86, blue: 0.38)
    private static let core = Color(red: 1.0, green: 0.96, blue: 0.62)
    private static let dim = Color(red: 0.16, green: 0.17, blue: 0.18).opacity(0.9)

    var body: some View {
        GeometryReader { proxy in
            let lit = Self.bits(value)
            ZStack {
                SevenSegmentShape(on: Array(repeating: true, count: 7))
                    .fill(Self.dim)
                SevenSegmentShape(on: lit)
                    .fill(Self.core)
                    .shadow(color: Self.gold.opacity(0.95), radius: max(2, proxy.size.height * 0.10))
                    .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.12).opacity(0.75),
                            radius: max(3, proxy.size.height * 0.22))
            }
        }
        .aspectRatio(0.58, contentMode: .fit)
    }

    private static func bits(_ value: Int?) -> [Bool] {
        switch value {
        case 0: return [true, true, true, true, true, true, false]
        case 1: return [false, true, true, false, false, false, false]
        case 2: return [true, true, false, true, true, false, true]
        case 3: return [true, true, true, true, false, false, true]
        case 4: return [false, true, true, false, false, true, true]
        case 5: return [true, false, true, true, false, true, true]
        case 6: return [true, false, true, true, true, true, true]
        case 7: return [true, true, true, false, false, false, false]
        case 8: return [true, true, true, true, true, true, true]
        case 9: return [true, true, true, true, false, true, true]
        default: return Array(repeating: false, count: 7)
        }
    }
}

/// Segments a–g as short trapezoids, in order: A B C D E F G.
private struct SevenSegmentShape: Shape {
    var on: [Bool]

    func path(in rect: CGRect) -> Path {
        let t = min(rect.width, rect.height) * 0.16
        let g = t * 0.18
        let x0 = rect.minX
        let x1 = rect.maxX
        let y0 = rect.minY
        let y1 = rect.maxY
        let ym = rect.midY
        let hx = t * 0.55

        func hBar(y: CGFloat, left: CGFloat, right: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: left + g + hx, y: y))
            p.addLine(to: CGPoint(x: right - g - hx, y: y))
            p.addLine(to: CGPoint(x: right - g, y: y + t / 2))
            p.addLine(to: CGPoint(x: right - g - hx, y: y + t))
            p.addLine(to: CGPoint(x: left + g + hx, y: y + t))
            p.addLine(to: CGPoint(x: left + g, y: y + t / 2))
            p.closeSubpath()
            return p
        }

        func vBar(x: CGFloat, top: CGFloat, bottom: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: x + t / 2, y: top + g))
            p.addLine(to: CGPoint(x: x + t, y: top + g + hx))
            p.addLine(to: CGPoint(x: x + t, y: bottom - g - hx))
            p.addLine(to: CGPoint(x: x + t / 2, y: bottom - g))
            p.addLine(to: CGPoint(x: x, y: bottom - g - hx))
            p.addLine(to: CGPoint(x: x, y: top + g + hx))
            p.closeSubpath()
            return p
        }

        var path = Path()
        let segs: [Path] = [
            hBar(y: y0, left: x0, right: x1),
            vBar(x: x1 - t, top: y0, bottom: ym),
            vBar(x: x1 - t, top: ym, bottom: y1),
            hBar(y: y1 - t, left: x0, right: x1),
            vBar(x: x0, top: ym, bottom: y1),
            vBar(x: x0, top: y0, bottom: ym),
            hBar(y: ym - t / 2, left: x0, right: x1)
        ]
        for (index, segment) in segs.enumerated() where index < on.count && on[index] {
            path.addPath(segment)
        }
        return path
    }
}

struct ScoreIconCenterPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint? = nil

    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}

private enum JoystickArt {
    static let canvas = CGSize(width: 387, height: 244)
    static let maxTilt: Double = 24
    /// Socket lip — the visible stem pivots here so the foot stays in the ring.
    static let pokeAnchor = UnitPoint(x: 207 / 387, y: 124 / 244)
    /// Midpoint of the baked-in arrows on `base`, used to mirror the light.
    static let flipAnchor = UnitPoint(x: 201 / 387, y: 0.5)
}

/// Circular clip at the inner ring; hides everything below the socket lip.
private struct PokeSocketMask: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / JoystickArt.canvas.width
        let sy = rect.height / JoystickArt.canvas.height
        var path = Path()
        path.addRect(CGRect(x: 0, y: 0, width: rect.width, height: 99 * sy))
        path.addEllipse(in: CGRect(x: 182 * sx, y: 74 * sy, width: 50 * sx, height: 50 * sy))
        return path
    }
}

/// The lower glass seal and wooden threshold. It overlaps the control shelf by
/// a few points so the play chamber and console read as one cabinet instead of
/// two rectangles touching edge-to-edge.
private struct CabinetGlassSill: View, Equatable {
    let palette: ClawPalette
    let isPad: Bool

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack {
                CabinetSillShape(bevel: height * 0.20)
                    .fill(
                        LinearGradient(colors: [Color(red: 0.18, green: 0.09, blue: 0.03),
                                                palette.woodDeep,
                                                palette.wood,
                                                Color(red: 0.67, green: 0.43, blue: 0.19),
                                                Color(red: 0.29, green: 0.14, blue: 0.04)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                CabinetSillShape(bevel: height * 0.20)
                    .stroke(.black.opacity(0.46), lineWidth: isPad ? 3 : 2)
                Rectangle()
                    .fill(.black.opacity(0.52))
                    .frame(height: isPad ? 5 : 4)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, height * 0.22)
                Rectangle()
                    .fill(.white.opacity(0.17))
                    .frame(height: isPad ? 2 : 1)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, height * 0.30)
                    .padding(.top, isPad ? 6 : 5)
                LinearGradient(colors: [.clear, .black.opacity(0.26)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: height * 0.48)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .clipShape(CabinetSillShape(bevel: height * 0.20))
                HStack {
                    fastener
                    Spacer()
                    fastener
                }
                .padding(.horizontal, height * 0.62)
            }
        }
        .allowsHitTesting(false)
    }

    private var fastener: some View {
        Circle()
            .fill(palette.woodDeep.opacity(0.75))
            .frame(width: isPad ? 7 : 5, height: isPad ? 7 : 5)
            .overlay {
                Capsule()
                    .fill(palette.woodLight.opacity(0.7))
                    .frame(width: isPad ? 4 : 3, height: 1)
                    .rotationEffect(.degrees(-18))
            }
    }
}

private struct CabinetSillShape: Shape {
    let bevel: CGFloat

    func path(in rect: CGRect) -> Path {
        let b = min(bevel, min(rect.width, rect.height) * 0.30)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + b, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - b, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + b))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - b * 0.45))
        path.addLine(to: CGPoint(x: rect.maxX - b * 0.55, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + b * 0.55, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - b * 0.45))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + b))
        path.closeSubpath()
        return path
    }
}

/// Control shelf seen from the front: narrower at the glass, wider toward the player.
private struct ArcadeShelfShape: Shape {
    var topInset: CGFloat
    var bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = min(max(0, topInset), rect.width * 0.28)
        let radius = min(max(0, bottomRadius), rect.height * 0.35)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        if radius > 0.5 {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                              control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                              control: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

/// Dark sliver along a slanted shelf edge so the board reads as thick wood.
private struct ArcadeShelfSideEdge: Shape {
    enum Side { case leading, trailing }
    var topInset: CGFloat
    var side: Side
    var thickness: CGFloat = 11

    func path(in rect: CGRect) -> Path {
        let inset = min(max(0, topInset), rect.width * 0.28)
        let thick = min(thickness, rect.width * 0.08)
        var path = Path()
        switch side {
        case .leading:
            path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + thick, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + inset + thick * 0.35, y: rect.minY))
        case .trailing:
            path.move(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - thick, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - inset - thick * 0.35, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}

private struct ClawPromptPlaque: View, Equatable {
    let text: String
    let pulse: Double
    let isPad: Bool
    let palette: ClawPalette
    let roundNumber: Int
    let maximumRounds: Int

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: isPad ? 38 : 28, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.45)
            .lineLimit(1)
            .scaleEffect(1 + 0.04 * pulse)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: isPad ? 16 : 12, style: .continuous)
                    .fill(
                        LinearGradient(colors: [palette.wood,
                                                palette.woodDeep,
                                                Color.black.opacity(0.74)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: isPad ? 16 : 12, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [palette.woodLight.opacity(0.7),
                                                        palette.woodDeep.opacity(0.8)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 2
                            )
                    }
            }
            .shadow(color: .black.opacity(0.32), radius: 8, y: 4)
            .accessibilityIdentifier("claw-prompt")
            .accessibilityValue(Text(verbatim: L("game.claw.progress \(roundNumber) \(maximumRounds)")))
    }
}

private struct ClawElephantView: View {
    let origin: CGPoint
    let swing: CGFloat
    let phase: ClawPhase
    let phaseAge: Double
    let motionClock: Double
    let play: CGRect
    let bin: CGRect
    let bodyVisible: Bool
    let reduceMotion: Bool
    let isPad: Bool

    var body: some View {
        let side = ClawConfig.elephantVisibleHeight(isPad: isPad)
        let local = CGPoint(x: origin.x - play.minX, y: origin.y - play.minY)
        let grip = armGrip
        let isFinale = phase == .celebrating || phase == .timeUp
        // The elephant hangs from its back feet, so the loose response grows
        // gently down the body: the face and front arms travel a touch farther
        // than the legs nearest the rope. A tiny phase delay keeps the layers
        // connected while still suggesting soft weight below the attachment.
        let bottomLag = isFinale
            ? Angle.zero
            : Angle.radians(Double(-swing) * 0.11 + sin(motionClock * 2.15) * 0.012)
        let headLag = isFinale
            ? Angle.zero
            : Angle.radians(Double(-swing) * 0.13 + sin(motionClock * 2.15 - 0.08) * 0.015)
        let armLag = isFinale
            ? Angle.zero
            : Angle.radians(Double(-swing) * 0.15 + sin(motionClock * 2.15 - 0.12) * 0.017)
        let motion = bodyMotion(side: side)
        ZStack(alignment: .topLeading) {
            swayingRope(to: local)

            // Once the body lets go, this empty mechanical claw continues to
            // follow the trolley and settles independently.
            elephantLayer(.claw)
                .frame(width: side, height: side)
                .rotationEffect(.radians(Double(swing)), anchor: .top)
                .position(x: local.x, y: local.y + side * 0.50)

            ZStack {
                elephantLayer(.bottom)
                    .rotationEffect(bottomLag, anchor: .top)

                elephantLayer(.leftArm)
                    .rotationEffect(.degrees(-17 * grip),
                                    anchor: UnitPoint(x: 0.36, y: 0.76))
                    .rotationEffect(armLag, anchor: .top)

                elephantLayer(.rightArm)
                    .rotationEffect(.degrees(17 * grip),
                                    anchor: UnitPoint(x: 0.64, y: 0.76))
                    .rotationEffect(armLag, anchor: .top)

                // The face deliberately renders last: it hides the arm and
                // torso seams while the loose layers are moving.
                elephantLayer(.head)
                    .rotationEffect(headLag, anchor: .top)
            }
            .frame(width: side, height: side)
            .scaleEffect(motion.scale, anchor: .top)
            .rotationEffect(motion.attachmentRotation, anchor: .top)
            .rotationEffect(motion.spinRotation, anchor: .center)
            .position(x: local.x + motion.offset.width,
                      y: local.y + side * 0.50 + motion.offset.height)
            .opacity(bodyVisible ? 1 : 0)
        }
        .frame(width: play.width, height: play.height)
        .allowsHitTesting(false)
    }

    /// Arms close while the walnut moves into the grip, stay closed during the
    /// lift and carry, then open as soon as the walnut is released over the bin.
    private var armGrip: Double {
        switch phase {
        case .grabbing:
            return smooth(min(1, phaseAge / ClawConfig.grabPause))
        case .ascending, .carrying:
            return 1
        case .dropping:
            return 1 - smooth(min(1, phaseAge / 0.16))
        case .celebrating:
            // Pull the front legs together before the release so the body
            // forms one clean diving silhouette through the bin mouth.
            return smooth(min(1, phaseAge / 0.24))
        default:
            return 0
        }
    }

    private func smooth(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private struct BodyMotion {
        let offset: CGSize
        let attachmentRotation: Angle
        let spinRotation: Angle
        let scale: CGFloat
    }

    /// The body remains mechanically attached through the leftward wind-up
    /// and the return swing. It gets its own centre-axis rotation only after
    /// the rightward release, then reaches the authored mouth before plunging
    /// behind the foreground bin. Time-up uses the same exact target without
    /// the somersault.
    private func bodyMotion(side: CGFloat) -> BodyMotion {
        switch phase {
        case .celebrating:
            guard phaseAge >= ClawConfig.celebrationRelease else {
                return attachedBody
            }

            let releaseAngle: CGFloat = reduceMotion
                ? 0
                : ClawConfig.celebrationReleaseAngle
            let approachDuration = ClawConfig.celebrationMouthArrival - ClawConfig.celebrationRelease
            let approach = min(1, max(0,
                (phaseAge - ClawConfig.celebrationRelease) / approachDuration
            ))
            let mouth = CGPoint(x: bin.minX + bin.width * 0.36,
                                y: bin.minY + bin.height * 0.15)
            let approachScale: CGFloat = reduceMotion ? 0.68 : 0.62
            let mouthOffset = CGSize(
                width: mouth.x - origin.x,
                height: mouth.y - origin.y - side * 0.78 * approachScale
            )
            let insideOffset = CGSize(
                width: mouth.x - origin.x,
                height: bin.minY + bin.height * 0.31 - origin.y
            )
            let plungeDuration = ClawConfig.completionDuration - ClawConfig.celebrationMouthArrival

            // Match the detached body's first velocity to the angular speed
            // it had on the final attached frame. This is the continuity that
            // makes the release read as momentum instead of a new animation.
            let swingDuration = CGFloat(
                ClawConfig.celebrationRelease - ClawConfig.celebrationCenterArrival
            )
            let angularVelocity = reduceMotion ? 0 : 2
                * (ClawConfig.celebrationReleaseAngle - ClawConfig.celebrationLeftAngle)
                / max(0.01, swingDuration)
            let pendulumRadius = side * 0.50
            let initialVelocity = CGSize(
                width: -CGFloat(cos(Double(releaseAngle))) * pendulumRadius * angularVelocity,
                height: -CGFloat(sin(Double(releaseAngle))) * pendulumRadius * angularVelocity
            )
            let mouthVelocity = CGSize(
                width: 0,
                height: (insideOffset.height - mouthOffset.height)
                    * 0.35 / CGFloat(max(0.01, plungeDuration))
            )

            if approach < 1 {
                let approachEase = smooth(approach)
                return BodyMotion(
                    offset: cubicHermite(from: .zero,
                                         to: mouthOffset,
                                         initialVelocity: initialVelocity,
                                         finalVelocity: mouthVelocity,
                                         duration: CGFloat(approachDuration),
                                         progress: CGFloat(approach)),
                    attachmentRotation: .radians(
                        Double(releaseAngle * CGFloat(1 - approachEase))
                    ),
                    spinRotation: reduceMotion ? .zero : .degrees(-360 * approach),
                    scale: 1 + (approachScale - 1) * CGFloat(approachEase)
                )
            }

            let plunge = min(1, max(0,
                (phaseAge - ClawConfig.celebrationMouthArrival) / plungeDuration
            ))
            let plungeEase = smooth(plunge)
            // A linear component preserves the downward mouth-arrival speed;
            // the quadratic remainder accelerates the elephant into the bin.
            let plungeTravel = 0.35 * plunge + 0.65 * plunge * plunge
            let finalScale = diveScale(side: side)
            return BodyMotion(
                offset: interpolate(mouthOffset, insideOffset, CGFloat(plungeTravel)),
                attachmentRotation: .radians(Double(releaseAngle * CGFloat(1 - plungeEase))),
                spinRotation: reduceMotion ? .zero : .degrees(-360),
                scale: approachScale + (finalScale - approachScale) * CGFloat(plungeEase)
            )

        case .timeUp:
            guard phaseAge >= ClawConfig.timeUpRelease else {
                return attachedBody
            }
            let duration = ClawConfig.timeUpDuration - ClawConfig.timeUpRelease
            let raw = min(1, max(0, (phaseAge - ClawConfig.timeUpRelease) / duration))
            let eased = smooth(raw)
            let mouthX = bin.minX + bin.width * 0.36
            let finalScale = diveScale(side: side)
            return BodyMotion(
                offset: CGSize(
                    width: (mouthX - origin.x) * CGFloat(eased),
                    height: (bin.minY + bin.height * 0.31 - origin.y) * CGFloat(raw * raw)
                ),
                attachmentRotation: .radians(Double(swing * CGFloat(1 - eased))),
                spinRotation: .zero,
                scale: 1 + (finalScale - 1) * CGFloat(eased)
            )

        default:
            return attachedBody
        }
    }

    private var attachedBody: BodyMotion {
        BodyMotion(offset: .zero,
                   attachmentRotation: .radians(Double(swing)),
                   spinRotation: .zero,
                   scale: 1)
    }

    private func diveScale(side: CGFloat) -> CGFloat {
        max(0.38, min(0.52, bin.width / max(1, side * 0.78)))
    }

    private func interpolate(_ from: CGSize, _ to: CGSize, _ progress: CGFloat) -> CGSize {
        CGSize(width: from.width + (to.width - from.width) * progress,
               height: from.height + (to.height - from.height) * progress)
    }

    private func cubicHermite(
        from: CGSize,
        to: CGSize,
        initialVelocity: CGSize,
        finalVelocity: CGSize,
        duration: CGFloat,
        progress: CGFloat
    ) -> CGSize {
        let t2 = progress * progress
        let t3 = t2 * progress
        let fromWeight = 2 * t3 - 3 * t2 + 1
        let initialVelocityWeight = t3 - 2 * t2 + progress
        let toWeight = -2 * t3 + 3 * t2
        let finalVelocityWeight = t3 - t2
        return CGSize(
            width: fromWeight * from.width
                + initialVelocityWeight * duration * initialVelocity.width
                + toWeight * to.width
                + finalVelocityWeight * duration * finalVelocity.width,
            height: fromWeight * from.height
                + initialVelocityWeight * duration * initialVelocity.height
                + toWeight * to.height
                + finalVelocityWeight * duration * finalVelocity.height
        )
    }

    /// A flexible two-curve rope makes acceleration travel through the line
    /// instead of reading as a rigid diagonal attached to the hook.
    private func swayingRope(to hook: CGPoint) -> some View {
        let sway = sin(Double(swing))
        let idleFlutter = sin(motionClock * 2.0) * 0.8
        let start = CGPoint(x: hook.x - CGFloat(sway * 2.0), y: 9)
        let end = CGPoint(x: hook.x, y: hook.y + 3)
        let length = max(4, end.y - start.y)
        let bend = CGFloat(sway) * min(isPad ? 28 : 21, length * 0.38) + CGFloat(idleFlutter)

        return Path { path in
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x + bend * 0.35, y: start.y + length * 0.28),
                control2: CGPoint(x: end.x - bend, y: start.y + length * 0.72)
            )
        }
        .stroke(
            LinearGradient(colors: [Color(red: 0.70, green: 0.56, blue: 0.32),
                                    Color(red: 0.22, green: 0.14, blue: 0.08)],
                           startPoint: .top, endPoint: .bottom),
            style: StrokeStyle(lineWidth: isPad ? 6 : 4.5, lineCap: .round)
        )
        .shadow(color: .black.opacity(0.28), radius: 1.2, x: 1, y: 1)
    }

    private enum Layer {
        case claw
        case bottom
        case head
        case leftArm
        case rightArm
    }

    private func elephantLayer(_ layer: Layer) -> some View {
        layerImage(layer)
            .resizable()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func layerImage(_ layer: Layer) -> Image {
#if canImport(UIKit)
        switch layer {
        case .claw: Image(uiImage: ClawArtworkCache.elephantClaw)
        case .bottom: Image(uiImage: ClawArtworkCache.elephantBottom)
        case .head: Image(uiImage: ClawArtworkCache.elephantHead)
        case .leftArm: Image(uiImage: ClawArtworkCache.elephantLeftArm)
        case .rightArm: Image(uiImage: ClawArtworkCache.elephantRightArm)
        }
#else
        switch layer {
        case .claw: Image("1_claw")
        case .bottom: Image("1_bottom")
        case .head: Image("1_head")
        case .leftArm: Image("1_left_arm")
        case .rightArm: Image("1_right_arm")
        }
#endif
    }
}

private struct ClawJoystickChrome: View, Equatable {
    let input: CGFloat

    var body: some View {
        let leftLit = input < -0.18
        let rightLit = input > 0.18
        let tilt = Angle.degrees(Double(input) * JoystickArt.maxTilt)

        return ZStack {
            baseImage
                .resizable()
                .allowsHitTesting(false)

            lightArrow(lit: leftLit, mirrored: false)
            lightArrow(lit: rightLit, mirrored: true)

            pokeImage
                .resizable()
                .rotationEffect(tilt, anchor: JoystickArt.pokeAnchor)
                .compositingGroup()
                .mask {
                    PokeSocketMask()
                }
                .allowsHitTesting(false)
        }
    }

    private func lightArrow(lit: Bool, mirrored: Bool) -> some View {
        arrowImage
            .resizable()
            .mask {
                GeometryReader { proxy in
                    Rectangle()
                        .frame(height: proxy.size.height * (236 / JoystickArt.canvas.height))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .scaleEffect(x: mirrored ? -1 : 1, y: 1, anchor: JoystickArt.flipAnchor)
            .opacity(lit ? 1 : 0)
            .allowsHitTesting(false)
    }

    private var baseImage: Image {
#if canImport(UIKit)
        Image(uiImage: ClawArtworkCache.joystickBase)
#else
        Image("base")
#endif
    }

    private var pokeImage: Image {
#if canImport(UIKit)
        Image(uiImage: ClawArtworkCache.poke)
#else
        Image("poke")
#endif
    }

    private var arrowImage: Image {
#if canImport(UIKit)
        Image(uiImage: ClawArtworkCache.lightArrow)
#else
        Image("light arrow")
#endif
    }
}

// MARK: - Nut pile

/// One Canvas pass for the whole mound. Forty-plus SwiftUI walnuts, each with
/// its own Gaussian blur, were the most expensive thing in the grab loop.
private struct ClawNutPile: View {
    let nuts: [ClawNutRuntime]
    let highlightedIDs: Set<UUID>
    let heldNutID: UUID?
    let playOrigin: CGPoint

    var body: some View {
        Canvas { context, _ in
            let ordered = nuts.filter(\.isPresent).sorted { $0.rest.y > $1.rest.y }
            for nut in ordered {
                draw(nut,
                     highlighted: highlightedIDs.contains(nut.id) && heldNutID != nut.id,
                     in: &context)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ nut: ClawNutRuntime, highlighted: Bool, in context: inout GraphicsContext) {
        let visualWidth = max(18, nut.pixelRadius * 2.0 * ClawConfig.nutPackScale)
        let visualHeight = visualWidth * ClawConfig.nutContentAspect
        let imageWidth = visualWidth / ClawConfig.nutContentWidthFraction
        let imageHeight = imageWidth / ClawConfig.nutCanvasAspect
        let center = CGPoint(x: nut.position.x - playOrigin.x,
                             y: nut.position.y - playOrigin.y)
        let visualRect = CGRect(x: center.x - visualWidth / 2,
                                y: center.y - visualHeight / 2,
                                width: visualWidth,
                                height: visualHeight)
        let imageRect = CGRect(x: center.x - imageWidth / 2,
                               y: center.y - imageHeight / 2,
                               width: imageWidth,
                               height: imageHeight)

        var drawContext = context
        if nut.rotation != 0 {
            drawContext.translateBy(x: center.x, y: center.y)
            drawContext.rotate(by: .radians(nut.rotation))
            drawContext.translateBy(x: -center.x, y: -center.y)
        }

        drawContext.draw(nutImage, in: imageRect)
        if nut.spec.isGold {
            drawContext.blendMode = .multiply
            drawContext.fill(Path(ellipseIn: visualRect.insetBy(dx: visualWidth * 0.08,
                                                                dy: visualHeight * 0.08)),
                             with: .color(Color(red: 1.0, green: 0.90, blue: 0.55).opacity(0.55)))
            drawContext.blendMode = .normal
        }

        let textSize = min(ClawConfig.nutMaxTextSize, visualWidth * 0.34)
        drawContext.draw(
            Text(verbatim: nut.spec.text)
                .font(.system(size: textSize, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.14, green: 0.07, blue: 0.03)),
            at: center,
            anchor: .center
        )

        if highlighted {
            let ring = Path(ellipseIn: visualRect.insetBy(dx: -visualWidth * 0.05,
                                                          dy: -visualHeight * 0.05))
            drawContext.stroke(ring,
                               with: .color(Color(red: 1.0, green: 0.84, blue: 0.12)),
                               lineWidth: 3.5)
            let outer = Path(ellipseIn: visualRect.insetBy(dx: -visualWidth * 0.09,
                                                           dy: -visualHeight * 0.09))
            drawContext.stroke(outer,
                               with: .color(Color(red: 1.0, green: 0.92, blue: 0.35).opacity(0.85)),
                               lineWidth: 2)
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

// MARK: - Cabinet & sanctuary

private struct MachineCabinet: View, Equatable {
    let palette: ClawPalette
    let size: CGSize

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.22, green: 0.12, blue: 0.05),
                                    palette.woodDeep,
                                    Color(red: 0.42, green: 0.26, blue: 0.12)],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: size.height * 0.045) {
                ForEach(0..<14, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.03 : 0.015))
                        .frame(height: 2)
                }
            }

            HStack(spacing: 0) {
                woodPost
                Spacer(minLength: 0)
                woodPost
            }

            VinesOverlay(palette: palette)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var woodPost: some View {
        let width = max(26, size.width * 0.078)
        return ZStack {
            Capsule()
                .fill(
                    LinearGradient(colors: [Color(red: 0.78, green: 0.58, blue: 0.32),
                                            palette.wood,
                                            palette.woodDeep],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .overlay {
                    Capsule()
                        .stroke(palette.woodLight.opacity(0.45), lineWidth: 1.5)
                        .padding(2)
                }

            Canvas { context, postSize in
                for index in 0..<12 {
                    let y = postSize.height * (0.04 + CGFloat(index) * 0.082)
                    var grain = Path()
                    grain.move(to: CGPoint(x: postSize.width * 0.18, y: y))
                    grain.addCurve(
                        to: CGPoint(x: postSize.width * 0.82, y: y + CGFloat(index % 3 - 1) * 3),
                        control1: CGPoint(x: postSize.width * 0.34, y: y - 3),
                        control2: CGPoint(x: postSize.width * 0.64, y: y + 4)
                    )
                    context.stroke(grain,
                                   with: .color(palette.woodDeep.opacity(0.20)),
                                   style: StrokeStyle(lineWidth: 1, lineCap: .round))
                }
            }

            VStack {
                postJoint(width: width, paw: true)
                Spacer()
                RopeBinding(width: width, palette: palette)
                Spacer()
                postJoint(width: width, paw: false)
                Spacer()
                RopeBinding(width: width, palette: palette)
                Spacer()
                postJoint(width: width, paw: true)
            }
            .padding(.vertical, size.height * 0.035)
        }
        .frame(width: width)
        .shadow(color: .black.opacity(0.38), radius: 3, x: 0, y: 2)
    }

    private func postJoint(width: CGFloat, paw: Bool) -> some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(colors: [palette.woodLight, palette.wood, palette.woodDeep],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: width * 1.06, height: max(10, width * 0.34))
                .overlay {
                    Capsule().stroke(.black.opacity(0.28), lineWidth: 1)
                }
            if paw {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: width * 0.32, weight: .bold))
                    .foregroundStyle(palette.woodDeep.opacity(0.58))
            } else {
                HStack(spacing: width * 0.34) {
                    Circle().fill(palette.woodDeep.opacity(0.66))
                    Circle().fill(palette.woodDeep.opacity(0.66))
                }
                .frame(width: width * 0.72, height: 4)
            }
        }
    }
}

/// One continuous fascia behind pause, prompt and timer. The controls still
/// live in the HUD for input, but now read as instruments mounted into the same
/// cabinet instead of three unrelated objects floating over a brown field.
private struct CabinetTopAssembly: View, Equatable {
    let palette: ClawPalette
    let size: CGSize
    let header: CGRect
    let playTop: CGFloat
    let isPad: Bool

    var body: some View {
        let height = max(playTop + (isPad ? 18 : 12), header.maxY + 12)
        let post = max(isPad ? 38 : 26, size.width * 0.078)
        let instrumentTop = max(isPad ? 18 : 44, header.minY - (isPad ? 16 : 11))
        let instrumentHeight = header.height + (isPad ? 32 : 23)

        ZStack(alignment: .topLeading) {
            CabinetCanopyShape(drop: isPad ? 24 : 17)
                .fill(
                    LinearGradient(colors: [palette.woodLight,
                                            palette.wood,
                                            palette.woodDeep],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .overlay {
                    CabinetCanopyShape(drop: isPad ? 24 : 17)
                        .stroke(.black.opacity(0.46), lineWidth: isPad ? 4 : 3)
                }

            Canvas { context, canvasSize in
                for index in 0..<7 {
                    let y = canvasSize.height * (0.12 + CGFloat(index) * 0.105)
                    var grain = Path()
                    grain.move(to: CGPoint(x: post * 0.55, y: y))
                    grain.addCurve(
                        to: CGPoint(x: canvasSize.width - post * 0.55,
                                    y: y + CGFloat(index % 3 - 1) * 2),
                        control1: CGPoint(x: canvasSize.width * 0.32, y: y - 4),
                        control2: CGPoint(x: canvasSize.width * 0.67, y: y + 4)
                    )
                    context.stroke(grain,
                                   with: .color(palette.woodDeep.opacity(0.16)),
                                   style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                }
            }

            RoundedRectangle(cornerRadius: isPad ? 25 : 18, style: .continuous)
                .fill(
                    LinearGradient(colors: [palette.character.deepColor.opacity(0.96),
                                            Color.black.opacity(0.80)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: isPad ? 25 : 18, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [palette.woodLight,
                                                    palette.wood,
                                                    palette.woodDeep],
                                           startPoint: .top,
                                           endPoint: .bottom),
                            lineWidth: isPad ? 7 : 5
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: isPad ? 20 : 14, style: .continuous)
                        .inset(by: isPad ? 9 : 7)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
                .frame(width: max(1, size.width - post * 1.38),
                       height: instrumentHeight)
                .position(x: size.width / 2,
                          y: instrumentTop + instrumentHeight / 2)
                .shadow(color: .black.opacity(0.40), radius: 5, y: 3)

            HStack {
                carvedEndCap(mirrored: false)
                Spacer()
                carvedEndCap(mirrored: true)
            }
            .padding(.horizontal, post * 0.64)
            .padding(.top, instrumentTop + instrumentHeight * 0.30)

            HStack {
                fastener
                Spacer()
                Image(systemName: "pawprint.fill")
                    .font(.system(size: isPad ? 18 : 13, weight: .black))
                    .foregroundStyle(palette.woodDeep.opacity(0.52))
                Spacer()
                fastener
            }
            .padding(.horizontal, post * 0.48)
            .padding(.top, height - (isPad ? 28 : 20))
        }
        .frame(width: size.width, height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func carvedEndCap(mirrored: Bool) -> some View {
        HStack(spacing: isPad ? 5 : 3) {
            Image(systemName: "leaf.fill")
            Image(systemName: "leaf.fill")
                .scaleEffect(0.72)
                .rotationEffect(.degrees(36))
        }
        .font(.system(size: isPad ? 17 : 12, weight: .bold))
        .foregroundStyle(palette.character.color.opacity(0.54))
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
    }

    private var fastener: some View {
        Circle()
            .fill(palette.woodDeep)
            .frame(width: isPad ? 10 : 7, height: isPad ? 10 : 7)
            .overlay {
                Capsule()
                    .fill(palette.woodLight.opacity(0.72))
                    .frame(width: isPad ? 7 : 5, height: 1)
                    .rotationEffect(.degrees(-18))
            }
    }
}

private struct CabinetCanopyShape: Shape {
    let drop: CGFloat

    func path(in rect: CGRect) -> Path {
        let d = min(drop, rect.height * 0.24)
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - d))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control: CGPoint(x: rect.width * 0.76, y: rect.maxY - d * 0.15))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - d),
                          control: CGPoint(x: rect.width * 0.24, y: rect.maxY - d * 0.15))
        path.closeSubpath()
        return path
    }
}

private struct RopeBinding: View {
    let width: CGFloat
    let palette: ClawPalette

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.84, green: 0.67, blue: 0.35),
                                                Color(red: 0.43, green: 0.27, blue: 0.10)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: max(2, width * 0.075)
                    )
                    .frame(width: width * 1.04, height: width * 0.20)
                    .offset(y: CGFloat(index - 2) * width * 0.09)
            }
            Circle()
                .fill(Color(red: 0.49, green: 0.30, blue: 0.11))
                .frame(width: width * 0.22, height: width * 0.22)
                .overlay(Circle().stroke(palette.woodLight.opacity(0.45), lineWidth: 1))
                .offset(x: width * 0.38, y: width * 0.08)
        }
        .frame(height: width * 0.58)
    }
}

private struct VinesOverlay: View {
    let palette: ClawPalette

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Canvas { context, size in
                    drawVine(context: &context, size: size, x: size.width * 0.04, lean: 1)
                    drawVine(context: &context, size: size, x: size.width * 0.96, lean: -1)
                }
                vineLeaves(width: proxy.size.width, height: proxy.size.height, lean: -1, x: 0.04)
                vineLeaves(width: proxy.size.width, height: proxy.size.height, lean: 1, x: 0.96)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawVine(context: inout GraphicsContext, size: CGSize, x: CGFloat, lean: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: size.height * 0.06))
        path.addCurve(to: CGPoint(x: x + lean * 5, y: size.height * 0.42),
                      control1: CGPoint(x: x - lean * 22, y: size.height * 0.17),
                      control2: CGPoint(x: x + lean * 25, y: size.height * 0.29))
        path.addCurve(to: CGPoint(x: x + lean * 10, y: size.height * 0.92),
                      control1: CGPoint(x: x - lean * 28, y: size.height * 0.58),
                      control2: CGPoint(x: x + lean * 27, y: size.height * 0.75))
        context.stroke(path,
                       with: .linearGradient(
                           Gradient(colors: [palette.leafLight, palette.leaf, palette.woodDeep]),
                           startPoint: CGPoint(x: x, y: 0),
                           endPoint: CGPoint(x: x, y: size.height)
                       ),
                       style: StrokeStyle(lineWidth: 5.5, lineCap: .round))

        // Loose spiral tendrils make the greenery feel grown around the frame,
        // rather than pasted on as a straight decorative stripe.
        for index in 0..<5 {
            let cy = size.height * (0.12 + CGFloat(index) * 0.17)
            let radius = CGFloat(8 + index % 2 * 4)
            var curl = Path()
            curl.move(to: CGPoint(x: x, y: cy))
            curl.addCurve(to: CGPoint(x: x + lean * radius * 0.25, y: cy + radius * 1.8),
                          control1: CGPoint(x: x + lean * radius * 1.8, y: cy - radius),
                          control2: CGPoint(x: x + lean * radius * 2.0, y: cy + radius * 2.0))
            curl.addCurve(to: CGPoint(x: x + lean * radius * 0.65, y: cy + radius * 0.75),
                          control1: CGPoint(x: x - lean * radius * 0.9, y: cy + radius * 1.75),
                          control2: CGPoint(x: x - lean * radius * 0.7, y: cy + radius * 0.55))
            context.stroke(curl,
                           with: .color(palette.leaf.opacity(0.82)),
                           style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    private func vineLeaves(width: CGFloat, height: CGFloat, lean: CGFloat, x: CGFloat) -> some View {
        ForEach(0..<8, id: \.self) { index in
            let y = height * (0.10 + CGFloat(index) * 0.10)
            ZStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 26 : 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [palette.leafLight, palette.leaf],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "leaf")
                    .font(.system(size: index.isMultiple(of: 2) ? 20 : 13, weight: .thin))
                    .foregroundStyle(.white.opacity(0.22))
            }
            .rotationEffect(.degrees(Double(22 * lean + (index.isMultiple(of: 2) ? -14 : 16))))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
            .position(x: width * x + lean * CGFloat(8 + index % 3 * 4), y: y)
        }
    }
}

/// A very small living layer over the carved posts. It is deliberately kept
/// separate from the rasterised cabinet so the rest of the scenery stays cheap.
private struct CabinetLivingDetails: View {
    let palette: ClawPalette
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let sway = reduceMotion ? 0 : sin(time * 0.78) * 3.2
                ZStack {
                    leafCluster(mirrored: false)
                        .rotationEffect(.degrees(sway), anchor: .bottom)
                        .position(x: proxy.size.width * 0.055, y: proxy.size.height * 0.18)
                    leafCluster(mirrored: true)
                        .rotationEffect(.degrees(-sway * 0.82), anchor: .bottom)
                        .position(x: proxy.size.width * 0.945, y: proxy.size.height * 0.72)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func leafCluster(mirrored: Bool) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16 + CGFloat(index) * 4, weight: .bold))
                    .foregroundStyle(index == 0 ? palette.leafLight : palette.leaf)
                    .rotationEffect(.degrees(Double(index * 34 - 30)))
                    .offset(x: CGFloat(index - 1) * 10, y: -CGFloat(index % 2) * 5)
            }
        }
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        .shadow(color: .black.opacity(0.24), radius: 2, y: 2)
    }
}

private struct SanctuaryScene: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    var body: some View {
        SavannaHabitatArtwork(palette: palette, character: character, isPad: isPad)
        .allowsHitTesting(false)
    }

    /// Side walls, ceiling and a darker back panel create a real room behind
    /// the glass. Their converging edges remain readable even when the walnut
    /// pile covers the lower half of the sanctuary.
    private var recessedRoom: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let inset = w * (isPad ? 0.105 : 0.09)
            ZStack {
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: inset, y: h * 0.10))
                    path.addLine(to: CGPoint(x: inset, y: h * 0.88))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(colors: [palette.woodDeep.opacity(0.80),
                                            character.deepColor.opacity(0.24)],
                                   startPoint: .leading, endPoint: .trailing)
                )

                Path { path in
                    path.move(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w - inset, y: h * 0.10))
                    path.addLine(to: CGPoint(x: w - inset, y: h * 0.88))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(colors: [character.deepColor.opacity(0.25),
                                            palette.woodDeep.opacity(0.84)],
                                   startPoint: .leading, endPoint: .trailing)
                )

                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w - inset, y: h * 0.10))
                    path.addLine(to: CGPoint(x: inset, y: h * 0.10))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [palette.woodDeep, palette.wood],
                                     startPoint: .top, endPoint: .bottom))

                RoundedRectangle(cornerRadius: isPad ? 18 : 12, style: .continuous)
                    .stroke(character.deepColor.opacity(0.18), lineWidth: isPad ? 3 : 2)
                    .padding(.horizontal, inset)
                    .padding(.top, h * 0.095)
                    .padding(.bottom, h * 0.115)
                    .shadow(color: .black.opacity(0.18), radius: 6)
            }
        }
    }

    private var ceilingBeams: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            LinearGradient(colors: [palette.woodLight, palette.woodDeep],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: proxy.size.width * 0.22,
                               height: isPad ? 8 : 5)
                        .rotationEffect(.degrees(index < 2 ? 8 : -8))
                        .position(x: proxy.size.width * (0.17 + CGFloat(index) * 0.22),
                                  y: proxy.size.height * 0.065)
                        .shadow(color: .black.opacity(0.28), radius: 2, y: 2)
                }
            }
        }
    }

    private var hangingLamps: some View {
        HStack {
            lamp
            Spacer()
            lamp
        }
        .padding(.horizontal, isPad ? 48 : 28)
        .padding(.top, isPad ? 6 : 4)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var lamp: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(palette.woodDeep)
                .frame(width: 2, height: isPad ? 16 : 10)
            Capsule()
                .fill(
                    LinearGradient(colors: [Color(red: 1.0, green: 0.92, blue: 0.62),
                                            Color(red: 0.92, green: 0.70, blue: 0.28)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: isPad ? 22 : 16, height: isPad ? 14 : 10)
            Circle()
                .fill(
                    RadialGradient(colors: [Color.yellow.opacity(0.32), Color.yellow.opacity(0)],
                                   center: .center,
                                   startRadius: 2,
                                   endRadius: isPad ? 27 : 19)
                )
                .frame(width: isPad ? 54 : 38, height: isPad ? 54 : 38)
                .offset(y: -8)
        }
    }

    private var tireSwing: some View {
        GeometryReader { proxy in
            let origin = CGPoint(x: proxy.size.width * 0.30, y: proxy.size.height * 0.02)
            let rest = CGPoint(x: proxy.size.width * 0.28, y: proxy.size.height * 0.28)
            Path { path in
                path.move(to: origin)
                path.addLine(to: rest)
            }
            .stroke(palette.woodDeep.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            Circle()
                .stroke(Color(red: 0.18, green: 0.14, blue: 0.10), lineWidth: isPad ? 8 : 6)
                .frame(width: isPad ? 36 : 26, height: isPad ? 36 : 26)
                .position(rest)
        }
    }

    /// Large, readable furniture replaces the former collection of tiny signs
    /// and icon-sized huts. Each object occupies real floor or wall space and
    /// overlaps another depth plane, so the chamber reads as a habitat at a
    /// glance even behind the walnut pile.
    private var habitatArchitecture: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                outdoorOpening
                    .frame(width: w * 0.42, height: h * 0.48)
                    .position(x: w * 0.51, y: h * 0.37)

                feedingStation
                    .frame(width: w * 0.22, height: h * 0.42)
                    .position(x: w * 0.16, y: h * 0.48)

                animalShelter
                    .frame(width: w * 0.24, height: h * 0.34)
                    .position(x: w * 0.78, y: h * 0.49)

                climbingNet
                    .frame(width: w * 0.19, height: h * 0.23)
                    .position(x: w * 0.82, y: h * 0.28)

                enrichmentToys
                    .frame(width: w * 0.30, height: h * 0.13)
                    .position(x: w * 0.66, y: h * 0.73)

                habitatFloorZone
                    .frame(width: w * 0.24, height: h * 0.10)
                    .position(x: w * 0.27, y: h * 0.76)
            }
        }
    }

    private var outdoorOpening: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack(alignment: .bottom) {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: w * 0.46,
                                                         bottomLeading: w * 0.08,
                                                         bottomTrailing: w * 0.08,
                                                         topTrailing: w * 0.46),
                                       style: .continuous)
                    .fill(
                        LinearGradient(colors: [character.skyColor,
                                                character.tintColor,
                                                palette.leafLight.opacity(0.74)],
                                       startPoint: .top,
                                       endPoint: .bottom)
                    )

                Circle()
                    .fill(.white.opacity(0.56))
                    .frame(width: w * 0.20, height: w * 0.20)
                    .position(x: w * 0.69, y: h * 0.25)

                ForEach(0..<3, id: \.self) { index in
                    Ellipse()
                        .fill(index == 0 ? palette.leafLight.opacity(0.72)
                                         : palette.leaf.opacity(0.82))
                        .frame(width: w * (0.72 - CGFloat(index) * 0.12),
                               height: h * (0.32 - CGFloat(index) * 0.05))
                        .offset(x: CGFloat(index - 1) * w * 0.20,
                                y: h * (0.10 + CGFloat(index) * 0.035))
                }

                HStack(alignment: .bottom, spacing: w * 0.04) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(palette.woodDeep.opacity(0.62))
                            .frame(width: w * 0.045,
                                   height: h * (0.18 + CGFloat(index % 3) * 0.06))
                            .overlay(alignment: .top) {
                                Circle()
                                    .fill(palette.leaf)
                                    .frame(width: w * 0.14, height: w * 0.12)
                            }
                    }
                }
                .padding(.bottom, h * 0.05)

                HStack(alignment: .top, spacing: -w * 0.035) {
                    ForEach(0..<7, id: \.self) { index in
                        Image(systemName: "leaf.fill")
                            .font(.system(size: w * (0.14 + CGFloat(index % 2) * 0.035),
                                          weight: .bold))
                            .foregroundStyle(index.isMultiple(of: 2)
                                             ? palette.leafLight
                                             : palette.leaf)
                            .rotationEffect(.degrees(Double(index * 27 - 78)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .offset(y: -h * 0.035)
            }
            .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: w * 0.46,
                                                                  bottomLeading: w * 0.08,
                                                                  bottomTrailing: w * 0.08,
                                                                  topTrailing: w * 0.46),
                                                style: .continuous))
            .overlay {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: w * 0.46,
                                                          bottomLeading: w * 0.08,
                                                          bottomTrailing: w * 0.08,
                                                          topTrailing: w * 0.46),
                                       style: .continuous)
                    .stroke(
                        LinearGradient(colors: [palette.woodLight,
                                                palette.wood,
                                                palette.woodDeep],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        lineWidth: isPad ? 11 : 7
                    )
            }
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(colors: [palette.woodLight, palette.woodDeep],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: isPad ? 17 : 11)
                    .offset(y: isPad ? 6 : 4)
            }
            .shadow(color: .black.opacity(0.30), radius: 6, y: 4)
        }
    }

    private var feedingStation: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(
                        LinearGradient(colors: [palette.woodLight,
                                                palette.wood,
                                                palette.woodDeep],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .frame(width: w * 0.24, height: h * 0.94)
                    .overlay {
                        VStack(spacing: h * 0.12) {
                            ForEach(0..<4, id: \.self) { _ in
                                Capsule()
                                    .fill(palette.woodDeep.opacity(0.24))
                                    .frame(width: w * 0.16, height: 1.5)
                            }
                        }
                    }

                VStack(spacing: h * 0.08) {
                    feederShelf(width: w, foodCount: 3)
                    feederShelf(width: w * 0.86, foodCount: 2)
                    Spacer(minLength: 0)
                }
                .padding(.top, h * 0.12)

                RopeBinding(width: w * 0.34, palette: palette)
                    .offset(y: -h * 0.21)
            }
            .shadow(color: .black.opacity(0.28), radius: 4, y: 3)
        }
    }

    private func feederShelf(width: CGFloat, foodCount: Int) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [palette.woodLight, palette.woodDeep],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: width * 0.92, height: isPad ? 13 : 8)
                .shadow(color: .black.opacity(0.24), radius: 2, y: 2)
            HStack(spacing: width * 0.04) {
                ForEach(0..<foodCount, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(index.isMultiple(of: 2) ? character.color : palette.leafLight)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: isPad ? 8 : 5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    .frame(width: width * 0.18, height: width * 0.18)
                }
            }
            .offset(y: -(width * 0.12))
        }
    }

    private var animalShelter: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack(alignment: .bottom) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.29))
                    path.addLine(to: CGPoint(x: w * 0.50, y: 0))
                    path.addLine(to: CGPoint(x: w, y: h * 0.29))
                    path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.37))
                    path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.15))
                    path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.37))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [palette.woodLight, palette.woodDeep],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.30), radius: 4, y: 3)

                RoundedRectangle(cornerRadius: isPad ? 13 : 9, style: .continuous)
                    .fill(LinearGradient(colors: [palette.wood, palette.woodDeep],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.82, height: h * 0.70)
                    .overlay {
                        RoundedRectangle(cornerRadius: isPad ? 22 : 15, style: .continuous)
                            .fill(Color.black.opacity(0.55))
                            .padding(.horizontal, w * 0.14)
                            .padding(.top, h * 0.18)
                            .padding(.bottom, h * 0.08)
                    }
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(character.color.opacity(0.72))
                            .frame(width: w * 0.58, height: h * 0.16)
                            .padding(.bottom, h * 0.07)
                    }

                Image(systemName: "pawprint.fill")
                    .font(.system(size: min(w, h) * 0.22, weight: .black))
                    .foregroundStyle(palette.woodLight.opacity(0.72))
                    .offset(y: -h * 0.36)
            }
        }
    }

    private var enrichmentToys: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: h * 0.18, style: .continuous)
                    .fill(palette.woodDeep.opacity(0.80))
                    .frame(height: h * 0.28)
                HStack(alignment: .bottom, spacing: w * 0.025) {
                    ForEach(0..<4, id: \.self) { index in
                        ZStack {
                            Circle()
                                .fill(index.isMultiple(of: 2) ? character.color : palette.leafLight)
                            Circle()
                                .stroke(.white.opacity(0.35), lineWidth: 1)
                                .padding(3)
                            Image(systemName: index == 1 ? "leaf.fill" : "pawprint.fill")
                                .font(.system(size: h * 0.18, weight: .bold))
                                .foregroundStyle(character.skyColor.opacity(0.82))
                        }
                        .frame(width: h * (0.48 + CGFloat(index % 2) * 0.14),
                               height: h * (0.48 + CGFloat(index % 2) * 0.14))
                        .rotationEffect(.degrees(Double(index * 11 - 16)))
                    }
                }
                .padding(.bottom, h * 0.12)
            }
            .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
        }
    }

    private var climbingNet: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                RoundedRectangle(cornerRadius: isPad ? 8 : 5, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [palette.woodLight, palette.woodDeep],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isPad ? 7 : 4.5
                    )
                Canvas { context, size in
                    let rope = Color(red: 0.72, green: 0.53, blue: 0.27).opacity(0.82)
                    for index in -2...4 {
                        var down = Path()
                        down.move(to: CGPoint(x: CGFloat(index) * size.width * 0.24, y: 0))
                        down.addLine(to: CGPoint(x: CGFloat(index + 3) * size.width * 0.24,
                                                 y: size.height))
                        context.stroke(down, with: .color(rope), lineWidth: isPad ? 2.4 : 1.6)

                        var up = Path()
                        up.move(to: CGPoint(x: CGFloat(index) * size.width * 0.24,
                                           y: size.height))
                        up.addLine(to: CGPoint(x: CGFloat(index + 3) * size.width * 0.24, y: 0))
                        context.stroke(up, with: .color(rope), lineWidth: isPad ? 2.4 : 1.6)
                    }
                }
                .padding(isPad ? 7 : 5)

                VStack {
                    HStack {
                        ropeKnot
                        Spacer()
                        ropeKnot
                    }
                    Spacer()
                    HStack {
                        ropeKnot
                        Spacer()
                        ropeKnot
                    }
                }
                .padding(isPad ? 5 : 3)

                Image(systemName: "pawprint.fill")
                    .font(.system(size: min(w, h) * 0.22, weight: .black))
                    .foregroundStyle(character.color)
                    .padding(min(w, h) * 0.10)
                    .background(character.skyColor.opacity(0.92), in: Circle())
                    .shadow(color: .black.opacity(0.24), radius: 3, y: 2)
            }
            .rotationEffect(.degrees(3))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
        }
    }

    private var ropeKnot: some View {
        Circle()
            .fill(Color(red: 0.49, green: 0.30, blue: 0.11))
            .frame(width: isPad ? 9 : 6, height: isPad ? 9 : 6)
            .overlay(Circle().stroke(palette.woodLight.opacity(0.60), lineWidth: 1))
    }

    private var habitatFloorZone: some View {
        let aquatic = ["octopus", "crab", "frog", "penguin"].contains(character.id)
        return ZStack {
            Capsule()
                .fill(
                    aquatic
                        ? LinearGradient(colors: [character.skyColor, character.color.opacity(0.55)],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(red: 0.56, green: 0.37, blue: 0.17),
                                                 Color(red: 0.29, green: 0.18, blue: 0.08)],
                                         startPoint: .top, endPoint: .bottom)
                )
                .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
            Image(systemName: aquatic ? "water.waves" : "leaf.fill")
                .font(.system(size: isPad ? 18 : 12, weight: .bold))
                .foregroundStyle(aquatic ? character.deepColor : palette.leafLight)
        }
        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
    }

    private var habitatNook: some View {
        GeometryReader { proxy in
            let aquatic = ["octopus", "crab", "frog", "penguin"].contains(character.id)
            ZStack {
                if aquatic {
                    Ellipse()
                        .fill(
                            RadialGradient(colors: [character.skyColor.opacity(0.85),
                                                    character.color.opacity(0.34),
                                                    character.deepColor.opacity(0.18)],
                                           center: .center,
                                           startRadius: 2,
                                           endRadius: isPad ? 72 : 50)
                        )
                        .overlay(Ellipse().stroke(.white.opacity(0.42), lineWidth: 1.5))
                        .frame(width: isPad ? 116 : 78, height: isPad ? 34 : 23)
                    Image(systemName: character.id == "penguin" ? "snowflake" : "water.waves")
                        .font(.system(size: isPad ? 23 : 15, weight: .bold))
                        .foregroundStyle(character.deepColor.opacity(0.70))
                } else {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: isPad ? 20 : 13, style: .continuous)
                            .fill(
                                LinearGradient(colors: [palette.woodDeep,
                                                        Color(red: 0.13, green: 0.08, blue: 0.04)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: isPad ? 118 : 80, height: isPad ? 66 : 44)
                            .overlay(alignment: .top) {
                                Capsule()
                                    .fill(character.color.opacity(0.58))
                                    .frame(width: isPad ? 88 : 58, height: isPad ? 17 : 11)
                                    .padding(.top, isPad ? 38 : 25)
                            }
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: isPad ? 21 : 14, weight: .bold))
                            .foregroundStyle(palette.woodLight.opacity(0.52))
                            .padding(.bottom, isPad ? 29 : 19)
                    }
                }
            }
            .position(x: proxy.size.width * 0.18, y: proxy.size.height * 0.69)
            .shadow(color: .black.opacity(0.24), radius: 4, y: 3)
        }
    }

    private var foregroundPlants: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom) {
                plantCluster(mirrored: false)
                Spacer()
                plantCluster(mirrored: true)
            }
            .padding(.horizontal, isPad ? 8 : 4)
            .padding(.bottom, isPad ? 26 : 18)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
    }

    private func plantCluster(mirrored: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(LinearGradient(colors: [palette.wood, palette.woodDeep],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: isPad ? 48 : 34, height: isPad ? 24 : 17)
            ForEach(0..<4, id: \.self) { index in
                Image(systemName: "leaf.fill")
                    .font(.system(size: (isPad ? 25 : 17) + CGFloat(index % 2) * 5,
                                  weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 2) ? palette.leafLight : palette.leaf)
                    .rotationEffect(.degrees(Double(index * 31 - 48)))
                    .offset(x: CGFloat(index - 2) * (isPad ? 9 : 6),
                            y: -(isPad ? 15 : 10) - CGFloat(index % 2) * 5)
            }
        }
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
    }

    private var pawWall: some View {
        GeometryReader { proxy in
            ForEach(0..<6, id: \.self) { index in
                Image(systemName: "pawprint.fill")
                    .font(.system(size: isPad ? 20 : 14, weight: .bold))
                    .foregroundStyle(palette.woodDeep.opacity(0.10))
                    .rotationEffect(.degrees(Double(index * 27 - 20)))
                    .position(x: proxy.size.width * (0.22 + CGFloat(index % 3) * 0.28),
                              y: proxy.size.height * (0.14 + CGFloat(index / 3) * 0.16))
            }
        }
    }

    private var window: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isPad ? 48 : 36, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(red: 0.72, green: 0.88, blue: 0.98),
                                            Color(red: 0.40, green: 0.66, blue: 0.88)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: isPad ? 96 : 64, height: isPad ? 108 : 72)
                .overlay {
                    RoundedRectangle(cornerRadius: isPad ? 48 : 36, style: .continuous)
                        .stroke(palette.wood, lineWidth: isPad ? 7 : 5)
                }
                .overlay {
                    Rectangle().fill(.white.opacity(0.22)).frame(width: 3)
                }
                .overlay(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: 1) {
                        ForEach(0..<5, id: \.self) { index in
                            Capsule()
                                .fill(character.deepColor.opacity(0.25))
                                .frame(width: isPad ? 8 : 5,
                                       height: (isPad ? 18 : 12) + CGFloat(index % 3) * 5)
                        }
                    }
                    .padding(.bottom, isPad ? 9 : 6)
                }
            Circle()
                .fill(.white.opacity(0.45))
                .frame(width: isPad ? 20 : 14, height: isPad ? 20 : 14)
                .offset(x: isPad ? -16 : -11, y: isPad ? -20 : -14)
        }
        .shadow(color: Color.yellow.opacity(0.18), radius: 10)
    }

    private var birdhouse: some View {
        VStack(spacing: 0) {
            Image(systemName: "chevron.up")
                .font(.system(size: isPad ? 22 : 16, weight: .black))
                .foregroundStyle(palette.woodDeep)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [palette.woodLight, palette.wood],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: isPad ? 52 : 38, height: isPad ? 40 : 30)
                .overlay {
                    Circle()
                        .fill(Color(red: 0.16, green: 0.10, blue: 0.05).opacity(0.45))
                        .frame(width: isPad ? 16 : 12, height: isPad ? 16 : 12)
                        .offset(y: 4)
                }
            Image(systemName: "bird.fill")
                .font(.system(size: isPad ? 14 : 11, weight: .bold))
                .foregroundStyle(character.color)
                .offset(y: -12)
        }
    }

    private var catCubby: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [palette.woodLight, palette.wood],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: isPad ? 74 : 54, height: isPad ? 60 : 44)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.14, green: 0.08, blue: 0.04).opacity(0.38))
                    .padding(7)
            }
            .overlay {
                Image(systemName: "cat.fill")
                    .font(.system(size: isPad ? 22 : 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.94, green: 0.55, blue: 0.18))
                    .offset(y: 5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(palette.woodDeep.opacity(0.4), lineWidth: 1.5)
            }
    }

    private var homePoster: some View {
        VStack(spacing: 3) {
            Text("game.claw.sign.home")
                .font(.system(size: isPad ? 10 : 7, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
            Image(systemName: "pawprint.fill")
                .font(.system(size: isPad ? 18 : 13, weight: .bold))
                .foregroundStyle(palette.leaf)
        }
        .foregroundStyle(palette.woodDeep)
        .padding(7)
        .frame(width: isPad ? 76 : 54)
        .background(Color(red: 0.97, green: 0.94, blue: 0.86), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(palette.woodDeep.opacity(0.28), lineWidth: 1)
        }
        .rotationEffect(.degrees(5))
    }

    private var warningSign: some View {
        Text("game.claw.sign.danger")
            .font(.system(size: isPad ? 9 : 7, weight: .heavy, design: .rounded))
            .foregroundStyle(palette.woodDeep)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color(red: 0.98, green: 0.86, blue: 0.34), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(palette.woodDeep.opacity(0.4), lineWidth: 1)
            }
            .rotationEffect(.degrees(-8))
    }

    private var woodenFloor: some View {
        LinearGradient(colors: [Color(red: 0.58, green: 0.38, blue: 0.18),
                                Color(red: 0.36, green: 0.20, blue: 0.08)],
                       startPoint: .top, endPoint: .bottom)
            .overlay {
                GeometryReader { proxy in
                    ForEach(0..<9, id: \.self) { index in
                        Path { path in
                            let x = proxy.size.width * CGFloat(index) / 8
                            path.move(to: CGPoint(x: proxy.size.width / 2, y: 0))
                            path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                        }
                        .stroke(Color.black.opacity(0.14), lineWidth: 1)
                    }
                }
            }
    }
}

/// A fully procedural habitat backdrop. Every coordinate is expressed as a
/// fraction of the chamber, so the same composition works on compact phones,
/// tall phones and iPad without loading or cropping a background asset.
private struct SavannaHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    private let skyTop = Color(red: 0.48, green: 0.79, blue: 0.93)
    private let skyHaze = Color(red: 0.91, green: 0.88, blue: 0.68)
    private let sandLight = Color(red: 0.76, green: 0.61, blue: 0.34)
    private let sandDeep = Color(red: 0.42, green: 0.28, blue: 0.12)
    private let bark = Color(red: 0.34, green: 0.19, blue: 0.075)
    private let barkLight = Color(red: 0.61, green: 0.39, blue: 0.16)
    private let savannaGreen = Color(red: 0.30, green: 0.43, blue: 0.11)
    private let leafLight = Color(red: 0.50, green: 0.60, blue: 0.18)
    private let water = Color(red: 0.18, green: 0.62, blue: 0.76)

    var body: some View {
        Canvas { context, size in
            paintSky(in: &context, size: size)
            paintDistantSavanna(in: &context, size: size)
            paintGround(in: &context, size: size)
            paintSandSurface(in: &context, size: size)
            paintWaterhole(in: &context, size: size)
            paintWaterEdgeDetails(in: &context, size: size)
            paintGroundDetails(in: &context, size: size)
            paintFieldVegetation(in: &context, size: size)
            paintTreesAndCanopy(in: &context, size: size)
            // Habitat structures sit inside the cabinet, in front of the
            // framing trees. This overlap is important for believable depth.
            paintHabitatFurniture(in: &context, size: size)
            paintForeground(in: &context, size: size)
        }
        .overlay {
            // A restrained glass tint unifies the scenery without washing out
            // the black answer labels on the walnut pile.
            LinearGradient(colors: [.white.opacity(0.08),
                                    .clear,
                                    palette.woodDeep.opacity(0.035)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        }
    }

    private func paintSky(in context: inout GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [skyTop, character.skyColor.opacity(0.76), skyHaze]),
                startPoint: CGPoint(x: size.width * 0.35, y: 0),
                endPoint: CGPoint(x: size.width * 0.58, y: size.height * 0.58)
            )
        )

        // Keep the hazy savanna sun clear of the right canopy: slightly lower
        // and closer to centre lets its full disc remain visible.
        let sun = CGRect(x: size.width * 0.60,
                         y: size.height * 0.195,
                         width: size.width * 0.135,
                         height: size.width * 0.135)
        context.fill(Path(ellipseIn: sun.insetBy(dx: -sun.width * 0.8, dy: -sun.height * 0.8)),
                     with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.32), .clear]),
                        center: CGPoint(x: sun.midX, y: sun.midY),
                        startRadius: 2,
                        endRadius: sun.width * 1.25
                     ))
        context.fill(Path(ellipseIn: sun), with: .color(Color(red: 1, green: 0.91, blue: 0.55).opacity(0.72)))

        // Thin, irregular cloud strokes add atmospheric scale while keeping
        // the centre quiet for the hanging character.
        let clouds: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.17, 0.26, 0.18, 0.020), (0.54, 0.19, 0.14, 0.015),
            (0.72, 0.31, 0.20, 0.018), (0.39, 0.34, 0.11, 0.012)
        ]
        for (index, cloud) in clouds.enumerated() {
            var path = Path()
            let x = size.width * cloud.0
            let y = size.height * cloud.1
            let width = size.width * cloud.2
            path.move(to: CGPoint(x: x - width * 0.50, y: y))
            path.addCurve(to: CGPoint(x: x + width * 0.50, y: y),
                          control1: CGPoint(x: x - width * 0.24, y: y - size.height * cloud.3),
                          control2: CGPoint(x: x + width * 0.20, y: y + size.height * cloud.3 * 0.35))
            context.stroke(path,
                           with: .color(Color.white.opacity(index.isMultiple(of: 2) ? 0.24 : 0.16)),
                           style: StrokeStyle(lineWidth: isPad ? 3.0 : 1.8, lineCap: .round))
        }
    }

    private func paintDistantSavanna(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let horizon = h * 0.43

        var mountains = Path()
        mountains.move(to: CGPoint(x: 0, y: horizon + h * 0.05))
        mountains.addLine(to: CGPoint(x: w * 0.18, y: horizon - h * 0.035))
        mountains.addLine(to: CGPoint(x: w * 0.31, y: horizon + h * 0.01))
        mountains.addLine(to: CGPoint(x: w * 0.51, y: horizon - h * 0.055))
        mountains.addLine(to: CGPoint(x: w * 0.67, y: horizon + h * 0.005))
        mountains.addLine(to: CGPoint(x: w * 0.84, y: horizon - h * 0.025))
        mountains.addLine(to: CGPoint(x: w, y: horizon + h * 0.03))
        mountains.addLine(to: CGPoint(x: w, y: horizon + h * 0.12))
        mountains.addLine(to: CGPoint(x: 0, y: horizon + h * 0.12))
        mountains.closeSubpath()
        context.fill(mountains, with: .linearGradient(
            Gradient(colors: [Color(red: 0.37, green: 0.48, blue: 0.33).opacity(0.34),
                              Color(red: 0.65, green: 0.57, blue: 0.36).opacity(0.18)]),
            startPoint: CGPoint(x: 0, y: horizon - h * 0.06),
            endPoint: CGPoint(x: 0, y: horizon + h * 0.10)
        ))

        let trees: [(CGFloat, CGFloat, CGFloat)] = [
            (0.13, 0.515, 0.205), (0.33, 0.495, 0.145),
            (0.57, 0.520, 0.225), (0.79, 0.500, 0.155), (0.93, 0.510, 0.185)
        ]
        for tree in trees {
            paintAcacia(in: &context,
                        center: CGPoint(x: w * tree.0, y: h * tree.1),
                        scale: h * tree.2,
                        distant: true)
        }
    }

    private func paintGround(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: h * 0.45))
        ground.addQuadCurve(to: CGPoint(x: w, y: h * 0.44),
                            control: CGPoint(x: w * 0.52, y: h * 0.49))
        ground.addLine(to: CGPoint(x: w, y: h))
        ground.addLine(to: CGPoint(x: 0, y: h))
        ground.closeSubpath()
        context.fill(ground, with: .linearGradient(
            Gradient(colors: [Color(red: 0.73, green: 0.66, blue: 0.39),
                              sandLight,
                              sandDeep]),
            startPoint: CGPoint(x: w * 0.50, y: h * 0.42),
            endPoint: CGPoint(x: w * 0.50, y: h)
        ))

        // A widening game trail gives the flat chamber genuine depth.
        var trail = Path()
        trail.move(to: CGPoint(x: w * 0.49, y: h * 0.55))
        trail.addCurve(to: CGPoint(x: w * 0.30, y: h),
                       control1: CGPoint(x: w * 0.58, y: h * 0.69),
                       control2: CGPoint(x: w * 0.31, y: h * 0.79))
        trail.addLine(to: CGPoint(x: w * 0.73, y: h))
        trail.addCurve(to: CGPoint(x: w * 0.54, y: h * 0.55),
                       control1: CGPoint(x: w * 0.72, y: h * 0.80),
                       control2: CGPoint(x: w * 0.48, y: h * 0.70))
        trail.closeSubpath()
        context.fill(trail, with: .color(Color(red: 0.82, green: 0.66, blue: 0.39).opacity(0.52)))
    }

    private func paintSandSurface(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        // Broad, low-contrast mineral patches make the soil read as a surface
        // with history, not as a smooth gradient with noise sprinkled on top.
        let patches: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (0.08, 0.49, 0.24, 0.055, Color(red: 0.48, green: 0.37, blue: 0.18).opacity(0.14)),
            (0.42, 0.475, 0.28, 0.050, Color(red: 0.92, green: 0.75, blue: 0.43).opacity(0.18)),
            (0.71, 0.50, 0.22, 0.060, Color(red: 0.45, green: 0.34, blue: 0.16).opacity(0.13)),
            (0.11, 0.66, 0.29, 0.095, Color(red: 0.36, green: 0.25, blue: 0.11).opacity(0.12)),
            (0.47, 0.70, 0.34, 0.090, Color(red: 0.91, green: 0.69, blue: 0.37).opacity(0.13)),
            (0.70, 0.78, 0.27, 0.105, Color(red: 0.33, green: 0.23, blue: 0.10).opacity(0.13)),
            (0.20, 0.88, 0.34, 0.100, Color(red: 0.87, green: 0.63, blue: 0.31).opacity(0.12))
        ]
        for (index, patch) in patches.enumerated() {
            let rect = CGRect(x: w * patch.0,
                              y: h * patch.1,
                              width: w * patch.2,
                              height: h * patch.3)
            paintSandPatch(in: &context, rect: rect, color: patch.4, phase: index)
        }

        // Wind-combed ridges become wider and farther apart toward the camera.
        for index in 0..<28 {
            let depth = CGFloat((index * 17) % 29) / 28
            let y = h * (0.485 + depth * 0.46)
            let xSeed = CGFloat((index * 43) % 101) / 100
            let x = w * (0.035 + xSeed * 0.91)
            let length = w * (0.020 + depth * 0.050)
            let lift = h * (0.0012 + depth * 0.0022)
            var ridge = Path()
            ridge.move(to: CGPoint(x: x - length * 0.50, y: y))
            ridge.addCurve(to: CGPoint(x: x + length * 0.50, y: y + lift * 0.15),
                           control1: CGPoint(x: x - length * 0.18, y: y - lift),
                           control2: CGPoint(x: x + length * 0.20, y: y + lift))
            context.stroke(ridge,
                           with: .color(index.isMultiple(of: 3)
                                ? Color.white.opacity(0.12)
                                : bark.opacity(0.105)),
                           style: StrokeStyle(lineWidth: isPad ? 1.3 : 0.75, lineCap: .round))
        }

        // Tiny paired specks create gravel beds rather than evenly distributed
        // confetti. Each cluster shares a shadow direction.
        for cluster in 0..<15 {
            let cx = w * (0.07 + CGFloat((cluster * 31) % 89) / 100)
            let cy = h * (0.51 + CGFloat((cluster * 19) % 43) / 100)
            let depth = cy / h
            for grain in 0..<4 {
                let gx = cx + CGFloat(grain - 2) * w * 0.006 + CGFloat(cluster % 2) * w * 0.003
                let gy = cy + CGFloat((grain * 3) % 4) * h * 0.0025
                let radius = max(0.55, depth * (isPad ? 1.8 : 1.15))
                let dot = CGRect(x: gx, y: gy, width: radius * 1.7, height: radius)
                context.fill(Path(ellipseIn: dot),
                             with: .color(grain.isMultiple(of: 2)
                                ? bark.opacity(0.24)
                                : Color.white.opacity(0.13)))
            }
        }

        // Paired shadow/light scallops describe shallow wind ripples in the
        // loose sand. Their scale increases toward the cabinet glass.
        for index in 0..<13 {
            let depth = CGFloat(index) / 12
            let y = h * (0.535 + depth * 0.40)
            let seed = CGFloat((index * 47) % 97) / 96
            let x = w * (0.08 + seed * 0.84)
            let length = w * (0.025 + depth * 0.055)
            let rise = h * (0.0015 + depth * 0.0025)
            var ripple = Path()
            ripple.move(to: CGPoint(x: x - length * 0.50, y: y))
            ripple.addCurve(to: CGPoint(x: x + length * 0.50, y: y),
                            control1: CGPoint(x: x - length * 0.22, y: y - rise),
                            control2: CGPoint(x: x + length * 0.18, y: y + rise * 0.45))
            context.stroke(ripple,
                           with: .color(bark.opacity(0.13)),
                           style: StrokeStyle(lineWidth: isPad ? 1.45 : 0.85, lineCap: .round))
            var light = context
            light.translateBy(x: 0, y: -(isPad ? 1.5 : 0.8))
            light.stroke(ripple,
                         with: .color(Color(red: 0.96, green: 0.79, blue: 0.48).opacity(0.16)),
                         style: StrokeStyle(lineWidth: isPad ? 1.0 : 0.6, lineCap: .round))
        }

        // A few angular seed husks and twig fragments add close-range detail
        // without turning the ground into evenly distributed noise.
        for index in 0..<10 {
            let x = w * (0.10 + CGFloat((index * 37) % 83) / 100)
            let y = h * (0.60 + CGFloat((index * 23) % 35) / 100)
            let length = w * (0.008 + CGFloat(index % 3) * 0.004)
            var husk = Path()
            husk.move(to: CGPoint(x: x - length, y: y))
            husk.addQuadCurve(to: CGPoint(x: x + length, y: y + length * 0.18),
                              control: CGPoint(x: x, y: y - length * 0.34))
            context.stroke(husk,
                           with: .color(Color(red: 0.32, green: 0.22, blue: 0.09).opacity(0.30)),
                           style: StrokeStyle(lineWidth: isPad ? 1.5 : 0.9, lineCap: .round))
        }
    }

    private func paintSandPatch(in context: inout GraphicsContext,
                                rect: CGRect,
                                color: Color,
                                phase: Int) {
        let wobble = rect.width * (phase.isMultiple(of: 2) ? 0.08 : 0.12)
        var patch = Path()
        patch.move(to: CGPoint(x: rect.minX + wobble, y: rect.midY))
        patch.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.10),
                       control2: CGPoint(x: rect.midX - wobble, y: rect.minY + rect.height * 0.12))
        patch.addCurve(to: CGPoint(x: rect.maxX - wobble * 0.55, y: rect.midY),
                       control1: CGPoint(x: rect.midX + wobble, y: rect.minY - rect.height * 0.08),
                       control2: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + rect.height * 0.22))
        patch.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                       control1: CGPoint(x: rect.maxX + wobble * 0.12, y: rect.maxY - rect.height * 0.22),
                       control2: CGPoint(x: rect.midX + wobble, y: rect.maxY + rect.height * 0.05))
        patch.addCurve(to: CGPoint(x: rect.minX + wobble, y: rect.midY),
                       control1: CGPoint(x: rect.midX - wobble, y: rect.maxY - rect.height * 0.02),
                       control2: CGPoint(x: rect.minX - wobble * 0.12, y: rect.maxY - rect.height * 0.18))
        patch.closeSubpath()
        context.fill(patch, with: .color(color))
    }

    private func paintWaterhole(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        // An asymmetric, perspective-flattened shoreline. The far edge is
        // narrow and quiet; the near bank is broader and more broken up.
        var bank = Path()
        bank.move(to: CGPoint(x: w * 0.285, y: h * 0.578))
        bank.addCurve(to: CGPoint(x: w * 0.405, y: h * 0.526),
                      control1: CGPoint(x: w * 0.315, y: h * 0.544),
                      control2: CGPoint(x: w * 0.350, y: h * 0.532))
        bank.addCurve(to: CGPoint(x: w * 0.620, y: h * 0.530),
                      control1: CGPoint(x: w * 0.475, y: h * 0.510),
                      control2: CGPoint(x: w * 0.575, y: h * 0.514))
        bank.addCurve(to: CGPoint(x: w * 0.735, y: h * 0.585),
                      control1: CGPoint(x: w * 0.690, y: h * 0.542),
                      control2: CGPoint(x: w * 0.720, y: h * 0.556))
        bank.addCurve(to: CGPoint(x: w * 0.595, y: h * 0.653),
                      control1: CGPoint(x: w * 0.730, y: h * 0.620),
                      control2: CGPoint(x: w * 0.675, y: h * 0.646))
        bank.addCurve(to: CGPoint(x: w * 0.370, y: h * 0.646),
                      control1: CGPoint(x: w * 0.515, y: h * 0.669),
                      control2: CGPoint(x: w * 0.425, y: h * 0.660))
        bank.addCurve(to: CGPoint(x: w * 0.285, y: h * 0.578),
                      control1: CGPoint(x: w * 0.315, y: h * 0.628),
                      control2: CGPoint(x: w * 0.275, y: h * 0.607))
        bank.closeSubpath()
        context.fill(bank, with: .linearGradient(
            Gradient(colors: [Color(red: 0.70, green: 0.57, blue: 0.31),
                              Color(red: 0.34, green: 0.24, blue: 0.12)]),
            startPoint: CGPoint(x: w * 0.50, y: h * 0.52),
            endPoint: CGPoint(x: w * 0.50, y: h * 0.66)
        ))

        var pond = Path()
        pond.move(to: CGPoint(x: w * 0.310, y: h * 0.579))
        pond.addCurve(to: CGPoint(x: w * 0.420, y: h * 0.541),
                      control1: CGPoint(x: w * 0.335, y: h * 0.552),
                      control2: CGPoint(x: w * 0.372, y: h * 0.546))
        pond.addCurve(to: CGPoint(x: w * 0.612, y: h * 0.544),
                      control1: CGPoint(x: w * 0.480, y: h * 0.526),
                      control2: CGPoint(x: w * 0.565, y: h * 0.530))
        pond.addCurve(to: CGPoint(x: w * 0.706, y: h * 0.584),
                      control1: CGPoint(x: w * 0.665, y: h * 0.551),
                      control2: CGPoint(x: w * 0.696, y: h * 0.564))
        pond.addCurve(to: CGPoint(x: w * 0.585, y: h * 0.628),
                      control1: CGPoint(x: w * 0.696, y: h * 0.610),
                      control2: CGPoint(x: w * 0.650, y: h * 0.626))
        pond.addCurve(to: CGPoint(x: w * 0.382, y: h * 0.624),
                      control1: CGPoint(x: w * 0.515, y: h * 0.641),
                      control2: CGPoint(x: w * 0.430, y: h * 0.636))
        pond.addCurve(to: CGPoint(x: w * 0.310, y: h * 0.579),
                      control1: CGPoint(x: w * 0.338, y: h * 0.614),
                      control2: CGPoint(x: w * 0.304, y: h * 0.600))
        pond.closeSubpath()
        context.fill(pond, with: .linearGradient(
            Gradient(colors: [Color(red: 0.58, green: 0.85, blue: 0.88),
                              water,
                              Color(red: 0.065, green: 0.35, blue: 0.47)]),
            startPoint: CGPoint(x: w * 0.48, y: h * 0.535),
            endPoint: CGPoint(x: w * 0.52, y: h * 0.635)
        ))

        // Broken reflections follow the wide perspective axis instead of
        // tracing concentric ellipses.
        let ripples: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.365, 0.566, 0.555, -0.002), (0.445, 0.585, 0.655, 0.001),
            (0.335, 0.602, 0.485, 0.002), (0.520, 0.614, 0.670, -0.001)
        ]
        for (index, ripple) in ripples.enumerated() {
            var line = Path()
            let y = h * ripple.1
            line.move(to: CGPoint(x: w * ripple.0, y: y))
            line.addCurve(to: CGPoint(x: w * ripple.2, y: y + h * ripple.3),
                          control1: CGPoint(x: w * (ripple.0 + 0.045), y: y - h * 0.006),
                          control2: CGPoint(x: w * (ripple.2 - 0.040), y: y + h * 0.005))
            context.stroke(line,
                           with: .color(Color.white.opacity(0.48 - Double(index) * 0.07)),
                           style: StrokeStyle(lineWidth: isPad ? 2.0 : 1.25, lineCap: .round))
        }

        // Warm shallows along the near edge make the water sit in the sand.
        var shallows = Path()
        shallows.move(to: CGPoint(x: w * 0.365, y: h * 0.622))
        shallows.addCurve(to: CGPoint(x: w * 0.610, y: h * 0.625),
                          control1: CGPoint(x: w * 0.440, y: h * 0.640),
                          control2: CGPoint(x: w * 0.545, y: h * 0.640))
        context.stroke(shallows,
                       with: .color(Color(red: 0.74, green: 0.60, blue: 0.32).opacity(0.42)),
                       style: StrokeStyle(lineWidth: isPad ? 5 : 3, lineCap: .round))
    }

    private func paintWaterEdgeDetails(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        // Paired wet/dry contours give the bank a hand-eroded edge. The lines
        // remain interrupted at the reed beds so it never becomes a hard oval.
        let bankContours: [(CGPoint, CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: 0.315, y: 0.575), CGPoint(x: 0.365, y: 0.535),
             CGPoint(x: 0.500, y: 0.526), CGPoint(x: 0.615, y: 0.544)),
            (CGPoint(x: 0.665, y: 0.556), CGPoint(x: 0.730, y: 0.580),
             CGPoint(x: 0.680, y: 0.624), CGPoint(x: 0.615, y: 0.632)),
            (CGPoint(x: 0.560, y: 0.641), CGPoint(x: 0.485, y: 0.651),
             CGPoint(x: 0.390, y: 0.636), CGPoint(x: 0.335, y: 0.614))
        ]
        for contour in bankContours {
            var lip = Path()
            lip.move(to: CGPoint(x: w * contour.0.x, y: h * contour.0.y))
            lip.addCurve(to: CGPoint(x: w * contour.3.x, y: h * contour.3.y),
                         control1: CGPoint(x: w * contour.1.x, y: h * contour.1.y),
                         control2: CGPoint(x: w * contour.2.x, y: h * contour.2.y))
            context.stroke(lip,
                           with: .color(Color(red: 0.23, green: 0.18, blue: 0.09).opacity(0.42)),
                           style: StrokeStyle(lineWidth: isPad ? 4.3 : 2.7, lineCap: .round))

            var dryHighlight = context
            dryHighlight.translateBy(x: 0, y: -(isPad ? 1.8 : 1.0))
            dryHighlight.stroke(lip,
                                with: .color(Color(red: 0.86, green: 0.70, blue: 0.40).opacity(0.32)),
                                style: StrokeStyle(lineWidth: isPad ? 1.8 : 1.1, lineCap: .round))
        }

        // Small collapsed shelves interrupt the contour and sell soft mud.
        let mudPockets: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.325, 0.610, 0.052, 0.014),
            (0.535, 0.642, 0.072, 0.015),
            (0.681, 0.590, 0.045, 0.012)
        ]
        for pocket in mudPockets {
            let rect = CGRect(x: w * (pocket.0 - pocket.2 * 0.5),
                              y: h * (pocket.1 - pocket.3 * 0.5),
                              width: w * pocket.2,
                              height: h * pocket.3)
            context.fill(Path(ellipseIn: rect),
                         with: .linearGradient(
                            Gradient(colors: [Color.black.opacity(0.20),
                                              Color(red: 0.55, green: 0.39, blue: 0.18).opacity(0.52)]),
                            startPoint: CGPoint(x: rect.midX, y: rect.minY),
                            endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        }

        // Dark wet shelves occur only where the bank is low. They are broken
        // segments, not an outline around the entire pool.
        let wetShelves: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.285, 0.593, 0.385, 0.606),
            (0.575, 0.635, 0.690, 0.610),
            (0.615, 0.545, 0.675, 0.558)
        ]
        for shelf in wetShelves {
            var mud = Path()
            mud.move(to: CGPoint(x: w * shelf.0, y: h * shelf.1))
            mud.addCurve(to: CGPoint(x: w * shelf.2, y: h * shelf.3),
                         control1: CGPoint(x: w * (shelf.0 + 0.028), y: h * (shelf.1 + 0.010)),
                         control2: CGPoint(x: w * (shelf.2 - 0.025), y: h * (shelf.3 - 0.006)))
            context.stroke(mud,
                           with: .color(Color(red: 0.25, green: 0.20, blue: 0.105).opacity(0.38)),
                           style: StrokeStyle(lineWidth: isPad ? 5.5 : 3.4, lineCap: .round))
        }

        // Rocks sit in three uneven groups, leaving long open stretches of mud
        // and reeds. This removes the artificial necklace around the water.
        let stones: [(CGFloat, CGFloat, CGFloat)] = [
            (0.292, 0.582, 0.021), (0.322, 0.602, 0.015), (0.350, 0.611, 0.010),
            (0.642, 0.633, 0.014), (0.675, 0.622, 0.027), (0.714, 0.603, 0.017),
            (0.735, 0.580, 0.011), (0.635, 0.543, 0.012)
        ]
        for (index, stone) in stones.enumerated() {
            let radius = w * stone.2
            let center = CGPoint(x: w * stone.0, y: h * stone.1)
            let contact = CGRect(x: center.x - radius * 1.05,
                                 y: center.y + radius * 0.12,
                                 width: radius * 2.10,
                                 height: radius * 0.52)
            context.fill(Path(ellipseIn: contact), with: .color(Color.black.opacity(0.14)))
            paintRock(in: &context, center: center, radius: radius)
            let glint = CGRect(x: center.x - radius * 0.44,
                               y: center.y - radius * 0.44,
                               width: radius * 0.52,
                               height: radius * 0.18)
            context.fill(Path(ellipseIn: glint),
                         with: .color(Color.white.opacity(index.isMultiple(of: 2) ? 0.18 : 0.10)))
        }

        // Two local reed beds, both offset from the rock groups.
        let reedBeds: [(CGFloat, CGFloat, CGFloat)] = [
            (0.365, 0.558, 0.034), (0.704, 0.585, 0.048)
        ]
        for bed in reedBeds {
            paintReeds(in: &context,
                       base: CGPoint(x: w * bed.0, y: h * bed.1),
                       height: h * bed.2)
        }

        paintDenseGrassClump(in: &context,
                             base: CGPoint(x: w * 0.592, y: h * 0.645),
                             height: h * 0.031,
                             width: w * 0.045,
                             dry: true,
                             bladeCount: 8)
    }

    private func paintGroundDetails(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        for index in 0..<38 {
            let column = CGFloat((index * 37) % 101) / 100
            let depth = CGFloat((index * 19) % 53) / 52
            let y = h * (0.47 + depth * 0.49)
            let x = w * column
            let radius = max(0.7, (y / h) * (isPad ? 2.1 : 1.5))
            let pebble = CGRect(x: x, y: y, width: radius * 1.9, height: radius)
            context.fill(Path(ellipseIn: pebble), with: .color(bark.opacity(0.20)))
        }

        // Short perspective cracks and dry grass marks prevent the sand from
        // reading as one flat gradient. Marks grow subtly toward the viewer.
        for index in 0..<16 {
            let x = w * (0.08 + CGFloat((index * 31) % 83) / 100)
            let y = h * (0.50 + CGFloat((index * 23) % 43) / 100)
            let length = w * (0.010 + (y / h) * 0.018)
            var crack = Path()
            crack.move(to: CGPoint(x: x - length, y: y))
            crack.addLine(to: CGPoint(x: x, y: y + length * 0.22))
            crack.addLine(to: CGPoint(x: x + length * 0.72, y: y - length * 0.12))
            if index.isMultiple(of: 3) {
                crack.move(to: CGPoint(x: x, y: y + length * 0.18))
                crack.addLine(to: CGPoint(x: x - length * 0.12, y: y + length * 0.62))
            }
            context.stroke(crack,
                           with: .color(bark.opacity(0.16)),
                           style: StrokeStyle(lineWidth: isPad ? 1.2 : 0.75, lineCap: .round))
        }

        let middleTufts: [(CGFloat, CGFloat, CGFloat)] = [
            (0.18, 0.52, 0.018), (0.27, 0.56, 0.014), (0.75, 0.52, 0.018),
            (0.82, 0.58, 0.024), (0.48, 0.67, 0.015), (0.59, 0.71, 0.018),
            (0.30, 0.68, 0.022), (0.71, 0.77, 0.025)
        ]
        for tuft in middleTufts {
            paintGrass(in: &context,
                       base: CGPoint(x: w * tuft.0, y: h * tuft.1),
                       height: h * tuft.2)
        }

        let rocks: [(CGFloat, CGFloat, CGFloat)] = [
            (0.27, 0.61, 0.030), (0.72, 0.60, 0.026), (0.22, 0.72, 0.043),
            (0.77, 0.70, 0.038), (0.10, 0.84, 0.060), (0.90, 0.82, 0.055)
        ]
        for rock in rocks {
            paintRock(in: &context,
                      center: CGPoint(x: w * rock.0, y: h * rock.1),
                      radius: w * rock.2)
        }
    }

    private func paintFieldVegetation(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        // A thin, broken vegetation band anchors the horizon without turning
        // it into a uniform green stripe.
        let distantClumps: [(CGFloat, CGFloat, CGFloat)] = [
            (0.06, 0.486, 0.018), (0.18, 0.500, 0.024), (0.29, 0.482, 0.015),
            (0.40, 0.505, 0.020), (0.52, 0.483, 0.016), (0.65, 0.500, 0.022),
            (0.76, 0.482, 0.017), (0.88, 0.502, 0.026), (0.96, 0.487, 0.015)
        ]
        for (index, clump) in distantClumps.enumerated() {
            paintDenseGrassClump(in: &context,
                                 base: CGPoint(x: w * clump.0, y: h * clump.1),
                                 height: h * clump.2,
                                 width: w * clump.2 * 1.65,
                                 dry: index.isMultiple(of: 3),
                                 bladeCount: 7)
        }

        let grasses: [(CGFloat, CGFloat, CGFloat, CGFloat, Bool)] = [
            (0.11, 0.565, 0.038, 0.052, false),
            (0.235, 0.605, 0.050, 0.062, true),
            (0.285, 0.535, 0.026, 0.036, false),
            (0.735, 0.545, 0.032, 0.044, false),
            (0.805, 0.615, 0.060, 0.072, false),
            (0.675, 0.685, 0.046, 0.058, true),
            (0.335, 0.700, 0.052, 0.066, false),
            (0.155, 0.765, 0.070, 0.086, true),
            (0.845, 0.770, 0.080, 0.095, false)
        ]
        for grass in grasses {
            paintDenseGrassClump(in: &context,
                                 base: CGPoint(x: w * grass.0, y: h * grass.1),
                                 height: h * grass.2,
                                 width: w * grass.3,
                                 dry: grass.4,
                                 bladeCount: grass.2 > 0.055 ? 13 : 10)
        }

        let shrubs: [(CGFloat, CGFloat, CGFloat)] = [
            (0.18, 0.535, 0.030), (0.78, 0.515, 0.025),
            (0.255, 0.655, 0.045), (0.735, 0.650, 0.040)
        ]
        for (index, shrub) in shrubs.enumerated() {
            paintLowShrub(in: &context,
                          base: CGPoint(x: w * shrub.0, y: h * shrub.1),
                          radius: w * shrub.2,
                          dry: index == 1 || index == 2)
        }

        paintDryBrush(in: &context,
                      base: CGPoint(x: w * 0.61, y: h * 0.515),
                      height: h * 0.043,
                      width: w * 0.060)
        paintDryBrush(in: &context,
                      base: CGPoint(x: w * 0.43, y: h * 0.675),
                      height: h * 0.060,
                      width: w * 0.075)
    }

    private func paintDenseGrassClump(in context: inout GraphicsContext,
                                      base: CGPoint,
                                      height: CGFloat,
                                      width: CGFloat,
                                      dry: Bool,
                                      bladeCount: Int) {
        // A soft contact shadow seats every plant in the sand.
        let shadow = CGRect(x: base.x - width * 0.48,
                            y: base.y - height * 0.045,
                            width: width * 0.96,
                            height: height * 0.16)
        context.fill(Path(ellipseIn: shadow), with: .color(Color.black.opacity(0.11)))

        for index in 0..<bladeCount {
            let t = bladeCount > 1 ? CGFloat(index) / CGFloat(bladeCount - 1) : 0.5
            let rootX = base.x + (t - 0.5) * width * 0.64
            let lean = (t - 0.5) * width * (0.72 + CGFloat(index % 3) * 0.12)
            let bladeHeight = height * (0.62 + CGFloat((index * 7) % 6) * 0.075)
            let bladeWidth = max(0.6, width * (index.isMultiple(of: 4) ? 0.045 : 0.030))
            let tip = CGPoint(x: rootX + lean, y: base.y - bladeHeight)
            var blade = Path()
            blade.move(to: CGPoint(x: rootX - bladeWidth * 0.5, y: base.y))
            blade.addQuadCurve(to: tip,
                               control: CGPoint(x: rootX + lean * 0.18, y: base.y - bladeHeight * 0.55))
            blade.addQuadCurve(to: CGPoint(x: rootX + bladeWidth * 0.5, y: base.y),
                               control: CGPoint(x: rootX + lean * 0.48 + bladeWidth,
                                                y: base.y - bladeHeight * 0.45))
            blade.closeSubpath()
            let color: Color
            if dry {
                color = index.isMultiple(of: 3)
                    ? Color(red: 0.66, green: 0.48, blue: 0.18)
                    : Color(red: 0.43, green: 0.40, blue: 0.12)
            } else {
                color = index.isMultiple(of: 3) ? leafLight : savannaGreen
            }
            context.fill(blade, with: .linearGradient(
                Gradient(colors: [color.opacity(0.92), color.opacity(0.62)]),
                startPoint: base, endPoint: tip
            ))
        }
    }

    private func paintLowShrub(in context: inout GraphicsContext,
                               base: CGPoint,
                               radius: CGFloat,
                               dry: Bool) {
        for index in 0..<9 {
            let angle = -Double.pi * 0.92 + Double(index) * Double.pi * 0.23
            let length = radius * (0.72 + CGFloat(index % 4) * 0.13)
            var stem = Path()
            stem.move(to: base)
            let tip = CGPoint(x: base.x + CGFloat(cos(angle)) * length,
                              y: base.y + CGFloat(sin(angle)) * length * 0.72)
            stem.addQuadCurve(to: tip,
                              control: CGPoint(x: (base.x + tip.x) * 0.5 + CGFloat(index % 2) * radius * 0.08,
                                               y: (base.y + tip.y) * 0.5))
            context.stroke(stem,
                           with: .color(dry ? barkLight.opacity(0.72) : savannaGreen.opacity(0.80)),
                           style: StrokeStyle(lineWidth: max(0.65, radius * 0.055), lineCap: .round))
            if !dry || index.isMultiple(of: 2) {
                paintLeaf(in: &context,
                          center: tip,
                          length: radius * 0.42,
                          angle: angle + .pi * 0.35,
                          color: dry ? Color(red: 0.58, green: 0.46, blue: 0.18) : leafLight)
            }
        }
    }

    private func paintDryBrush(in context: inout GraphicsContext,
                               base: CGPoint,
                               height: CGFloat,
                               width: CGFloat) {
        for index in 0..<7 {
            let t = CGFloat(index) / 6
            let tip = CGPoint(x: base.x + (t - 0.5) * width,
                              y: base.y - height * (0.55 + CGFloat((index * 5) % 4) * 0.12))
            var stem = Path()
            stem.move(to: base)
            stem.addCurve(to: tip,
                          control1: CGPoint(x: base.x + (t - 0.5) * width * 0.16, y: base.y - height * 0.30),
                          control2: CGPoint(x: tip.x - (t - 0.5) * width * 0.10, y: tip.y + height * 0.18))
            context.stroke(stem,
                           with: .color(Color(red: 0.47, green: 0.35, blue: 0.13).opacity(0.78)),
                           style: StrokeStyle(lineWidth: max(0.6, height * 0.022), lineCap: .round))
            let head = CGRect(x: tip.x - width * 0.025,
                              y: tip.y - height * 0.035,
                              width: width * 0.05,
                              height: height * 0.07)
            context.fill(Path(ellipseIn: head),
                         with: .color(Color(red: 0.76, green: 0.59, blue: 0.25).opacity(0.74)))
        }
    }

    private func paintHabitatFurniture(in context: inout GraphicsContext, size: CGSize) {
        paintLeftRootBank(in: &context, size: size)
        paintClimbingPost(in: &context, size: size)

        // The collection bin occupies the far-right floor. A stump in that
        // location vanished completely, so this bank grows above and just to
        // the left of the bin instead.
        paintSedgeBank(in: &context, size: size)
        paintClimbingNet(in: &context, size: size)

        // A fallen log crosses the ground plane instead of reading as another
        // floating UI badge.
        var log = Path()
        log.move(to: CGPoint(x: size.width * 0.70, y: size.height * 0.72))
        log.addQuadCurve(to: CGPoint(x: size.width * 0.91, y: size.height * 0.75),
                         control: CGPoint(x: size.width * 0.81, y: size.height * 0.70))
        context.stroke(log, with: .color(Color.black.opacity(0.18)),
                       style: StrokeStyle(lineWidth: size.width * 0.055, lineCap: .round))
        context.stroke(log, with: .linearGradient(
            Gradient(colors: [barkLight, bark]),
            startPoint: CGPoint(x: size.width * 0.70, y: size.height * 0.70),
            endPoint: CGPoint(x: size.width * 0.91, y: size.height * 0.77)),
                       style: StrokeStyle(lineWidth: size.width * 0.044, lineCap: .round))
    }

    private func paintTreesAndCanopy(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        var leftTrunk = Path()
        leftTrunk.move(to: CGPoint(x: -w * 0.018, y: h * 0.83))
        leftTrunk.addCurve(to: CGPoint(x: w * 0.058, y: h * 0.43),
                           control1: CGPoint(x: w * 0.025, y: h * 0.70),
                           control2: CGPoint(x: w * 0.010, y: h * 0.55))
        leftTrunk.addCurve(to: CGPoint(x: w * 0.076, y: h * 0.085),
                           control1: CGPoint(x: w * 0.085, y: h * 0.31),
                           control2: CGPoint(x: w * 0.035, y: h * 0.18))
        leftTrunk.addQuadCurve(to: CGPoint(x: w * 0.118, y: h * 0.052),
                               control: CGPoint(x: w * 0.100, y: h * 0.060))
        leftTrunk.addCurve(to: CGPoint(x: w * 0.108, y: h * 0.44),
                           control1: CGPoint(x: w * 0.094, y: h * 0.17),
                           control2: CGPoint(x: w * 0.125, y: h * 0.31))
        leftTrunk.addCurve(to: CGPoint(x: w * 0.040, y: h * 0.86),
                           control1: CGPoint(x: w * 0.090, y: h * 0.62),
                           control2: CGPoint(x: w * 0.105, y: h * 0.74))
        leftTrunk.closeSubpath()
        context.fill(leftTrunk, with: .linearGradient(
            Gradient(colors: [bark, barkLight, bark]),
            startPoint: CGPoint(x: 0, y: h), endPoint: CGPoint(x: w * 0.13, y: 0))
        )
        context.stroke(leftTrunk, with: .color(Color.black.opacity(0.25)),
                       style: StrokeStyle(lineWidth: isPad ? 2.2 : 1.35, lineJoin: .round))

        var rightTrunk = Path()
        rightTrunk.move(to: CGPoint(x: w * 1.018, y: h * 0.84))
        rightTrunk.addCurve(to: CGPoint(x: w * 0.946, y: h * 0.44),
                            control1: CGPoint(x: w * 0.980, y: h * 0.70),
                            control2: CGPoint(x: w * 0.992, y: h * 0.56))
        rightTrunk.addCurve(to: CGPoint(x: w * 0.924, y: h * 0.085),
                            control1: CGPoint(x: w * 0.915, y: h * 0.31),
                            control2: CGPoint(x: w * 0.965, y: h * 0.18))
        rightTrunk.addQuadCurve(to: CGPoint(x: w * 0.882, y: h * 0.052),
                                control: CGPoint(x: w * 0.900, y: h * 0.060))
        rightTrunk.addCurve(to: CGPoint(x: w * 0.892, y: h * 0.45),
                            control1: CGPoint(x: w * 0.906, y: h * 0.17),
                            control2: CGPoint(x: w * 0.875, y: h * 0.31))
        rightTrunk.addCurve(to: CGPoint(x: w * 0.960, y: h * 0.87),
                            control1: CGPoint(x: w * 0.910, y: h * 0.63),
                            control2: CGPoint(x: w * 0.895, y: h * 0.75))
        rightTrunk.closeSubpath()
        context.fill(rightTrunk, with: .linearGradient(
            Gradient(colors: [bark, barkLight, bark]),
            startPoint: CGPoint(x: w, y: h), endPoint: CGPoint(x: w * 0.86, y: 0))
        )
        context.stroke(rightTrunk, with: .color(Color.black.opacity(0.25)),
                       style: StrokeStyle(lineWidth: isPad ? 2.2 : 1.35, lineJoin: .round))

        // Fine bark grooves follow the trunks instead of sitting as generic
        // vertical stripes, with small knots that catch the light.
        for index in 0..<4 {
            let offset = CGFloat(index - 2) * w * 0.010
            var leftGrain = Path()
            leftGrain.move(to: CGPoint(x: w * 0.025 + offset, y: h * 0.76))
            leftGrain.addCurve(to: CGPoint(x: w * 0.095 + offset * 0.35, y: h * 0.10),
                               control1: CGPoint(x: w * 0.055 - offset, y: h * 0.56),
                               control2: CGPoint(x: w * 0.045 + offset, y: h * 0.30))
            context.stroke(leftGrain,
                           with: .color(index.isMultiple(of: 2) ? Color.white.opacity(0.12) : bark.opacity(0.44)),
                           style: StrokeStyle(lineWidth: isPad ? 1.7 : 1.0, lineCap: .round))

            var rightGrain = Path()
            rightGrain.move(to: CGPoint(x: w * 0.975 + offset, y: h * 0.77))
            rightGrain.addCurve(to: CGPoint(x: w * 0.895 + offset * 0.35, y: h * 0.10),
                                control1: CGPoint(x: w * 0.945 - offset, y: h * 0.56),
                                control2: CGPoint(x: w * 0.965 + offset, y: h * 0.30))
            context.stroke(rightGrain,
                           with: .color(index.isMultiple(of: 2) ? bark.opacity(0.48) : Color.white.opacity(0.10)),
                           style: StrokeStyle(lineWidth: isPad ? 1.7 : 1.0, lineCap: .round))
        }
        let knots: [(CGFloat, CGFloat)] = [
            (0.065, 0.43), (0.095, 0.60), (0.945, 0.37), (0.965, 0.57)
        ]
        for knot in knots {
            let rect = CGRect(x: w * knot.0 - w * 0.012, y: h * knot.1 - w * 0.008,
                              width: w * 0.024, height: w * 0.016)
            context.fill(Path(ellipseIn: rect), with: .color(bark.opacity(0.72)))
            context.stroke(Path(ellipseIn: rect.insetBy(dx: w * 0.004, dy: w * 0.003)),
                           with: .color(barkLight.opacity(0.48)), lineWidth: isPad ? 1.2 : 0.8)
        }

        let branches: [(CGPoint, CGPoint, CGPoint, CGFloat)] = [
            (CGPoint(x: 0.07, y: 0.20), CGPoint(x: 0.20, y: 0.10), CGPoint(x: 0.40, y: 0.08), 0.035),
            (CGPoint(x: 0.91, y: 0.18), CGPoint(x: 0.79, y: 0.09), CGPoint(x: 0.58, y: 0.07), 0.032),
            (CGPoint(x: 0.10, y: 0.32), CGPoint(x: 0.18, y: 0.21), CGPoint(x: 0.27, y: 0.18), 0.020),
            (CGPoint(x: 0.90, y: 0.31), CGPoint(x: 0.83, y: 0.22), CGPoint(x: 0.74, y: 0.18), 0.019)
        ]
        for branch in branches {
            var path = Path()
            path.move(to: CGPoint(x: w * branch.0.x, y: h * branch.0.y))
            path.addQuadCurve(to: CGPoint(x: w * branch.2.x, y: h * branch.2.y),
                              control: CGPoint(x: w * branch.1.x, y: h * branch.1.y))
            context.stroke(path, with: .linearGradient(
                Gradient(colors: [bark, barkLight, bark]),
                startPoint: CGPoint(x: w * branch.0.x, y: h * branch.0.y),
                endPoint: CGPoint(x: w * branch.2.x, y: h * branch.2.y)),
                           style: StrokeStyle(lineWidth: w * branch.3, lineCap: .round))
        }

        let foliage: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.02, 0.03, 0.23, 0.12), (0.17, 0.015, 0.25, 0.13),
            (0.35, 0.025, 0.21, 0.11), (0.55, 0.02, 0.23, 0.12),
            (0.73, 0.015, 0.25, 0.13), (0.91, 0.035, 0.20, 0.12),
            (0.02, 0.15, 0.16, 0.12), (0.88, 0.15, 0.16, 0.12)
        ]
        for (index, cluster) in foliage.enumerated() {
            let rect = CGRect(x: w * (cluster.0 - cluster.2 * 0.5),
                              y: h * cluster.1,
                              width: w * cluster.2,
                              height: h * cluster.3)
            context.fill(Path(ellipseIn: rect),
                         with: .color(index.isMultiple(of: 2) ? leafLight : savannaGreen))
            let highlight = rect.insetBy(dx: rect.width * 0.20, dy: rect.height * 0.24)
                .offsetBy(dx: -rect.width * 0.10, dy: -rect.height * 0.12)
            context.fill(Path(ellipseIn: highlight), with: .color(Color.white.opacity(0.10)))
        }

        // Dozens of pointed leaf silhouettes sit over the broad masses. This
        // preserves a lush read from afar and supplies real detail up close.
        for index in 0..<42 {
            let x = w * (0.015 + CGFloat((index * 41) % 97) / 100)
            let topBand = h * (0.035 + CGFloat((index * 17) % 13) / 100)
            let sideDrop = (index % 7 == 0 || index % 11 == 0)
                ? h * (0.08 + CGFloat(index % 4) * 0.034)
                : 0
            let angle = Double((index * 47) % 180) * .pi / 180
            paintLeaf(in: &context,
                      center: CGPoint(x: x, y: topBand + sideDrop),
                      length: w * (0.022 + CGFloat(index % 3) * 0.006),
                      angle: angle,
                      color: index.isMultiple(of: 3) ? leafLight : savannaGreen)
        }

        paintHangingVines(in: &context, size: size)
    }

    private func paintTireSwing(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let ropeStart = CGPoint(x: w * 0.24, y: 0)
        let tireCenter = CGPoint(x: w * 0.255, y: h * 0.255)

        var liana = Path()
        liana.move(to: ropeStart)
        liana.addCurve(to: CGPoint(x: tireCenter.x, y: tireCenter.y - h * 0.022),
                       control1: CGPoint(x: w * 0.20, y: h * 0.075),
                       control2: CGPoint(x: w * 0.30, y: h * 0.15))
        context.stroke(liana, with: .color(Color.black.opacity(0.30)),
                       style: StrokeStyle(lineWidth: isPad ? 6 : 4, lineCap: .round))
        context.stroke(liana, with: .linearGradient(
            Gradient(colors: [savannaGreen, barkLight, bark]),
            startPoint: ropeStart, endPoint: tireCenter),
                       style: StrokeStyle(lineWidth: isPad ? 4.2 : 2.8, lineCap: .round))

        // A real front-facing ring: perfectly round, visually heavy and with
        // an open centre. The previous flattened ellipse read like a pulley.
        let diameter = min(w * 0.115, h * 0.105)
        let tireRect = CGRect(x: tireCenter.x - diameter * 0.50,
                              y: tireCenter.y - diameter * 0.50,
                              width: diameter,
                              height: diameter)
        let rubberWidth = diameter * 0.245
        context.stroke(Path(ellipseIn: tireRect.offsetBy(dx: diameter * 0.035,
                                                         dy: diameter * 0.065)),
                       with: .color(Color.black.opacity(0.34)),
                       style: StrokeStyle(lineWidth: rubberWidth * 1.10))
        context.stroke(Path(ellipseIn: tireRect),
                       with: .linearGradient(
                        Gradient(colors: [Color(red: 0.30, green: 0.27, blue: 0.20),
                                          Color(red: 0.105, green: 0.095, blue: 0.075),
                                          Color(red: 0.035, green: 0.038, blue: 0.032)]),
                        startPoint: CGPoint(x: tireRect.minX, y: tireRect.minY),
                        endPoint: CGPoint(x: tireRect.maxX, y: tireRect.maxY)),
                       style: StrokeStyle(lineWidth: rubberWidth, lineCap: .round))

        // Sidewall bevels define the outer rubber and the recessed inner hole.
        context.stroke(Path(ellipseIn: tireRect.insetBy(dx: rubberWidth * 0.16,
                                                        dy: rubberWidth * 0.16)),
                       with: .color(Color.white.opacity(0.16)),
                       style: StrokeStyle(lineWidth: isPad ? 1.8 : 1.05))
        context.stroke(Path(ellipseIn: tireRect.insetBy(dx: rubberWidth * 0.52,
                                                        dy: rubberWidth * 0.52)),
                       with: .color(Color.black.opacity(0.52)),
                       style: StrokeStyle(lineWidth: isPad ? 2.3 : 1.4))
        var sidewallGlint = Path()
        sidewallGlint.addArc(center: tireCenter,
                             radius: diameter * 0.50,
                             startAngle: .degrees(205),
                             endAngle: .degrees(305),
                             clockwise: false)
        context.stroke(sidewallGlint,
                       with: .color(Color.white.opacity(0.12)),
                       style: StrokeStyle(lineWidth: rubberWidth * 0.22, lineCap: .round))

        // The vine visibly loops and tightens around the top of the tyre.
        let knotY = tireRect.minY + rubberWidth * 0.12
        for index in 0..<3 {
            let knot = CGRect(x: tireCenter.x - rubberWidth * (0.48 + CGFloat(index) * 0.035),
                              y: knotY + CGFloat(index) * rubberWidth * 0.16,
                              width: rubberWidth * (0.96 + CGFloat(index) * 0.07),
                              height: rubberWidth * 0.30)
            context.stroke(Path(ellipseIn: knot),
                           with: .color(index == 1 ? barkLight : bark),
                           style: StrokeStyle(lineWidth: isPad ? 2.4 : 1.55, lineCap: .round))
        }
    }

    private func paintForeground(in context: inout GraphicsContext, size: CGSize) {
        let tufts: [(CGFloat, CGFloat, CGFloat)] = [
            (0.05, 0.64, 0.050), (0.16, 0.73, 0.043), (0.06, 0.88, 0.075),
            (0.25, 0.83, 0.038), (0.76, 0.80, 0.045), (0.86, 0.69, 0.055),
            (0.94, 0.87, 0.080), (0.70, 0.64, 0.030)
        ]
        for tuft in tufts {
            paintGrass(in: &context,
                       base: CGPoint(x: size.width * tuft.0, y: size.height * tuft.1),
                       height: size.height * tuft.2)
        }
    }

    private func paintReeds(in context: inout GraphicsContext,
                            base: CGPoint,
                            height: CGFloat) {
        for index in 0..<5 {
            let offset = (CGFloat(index) - 2) * height * 0.13
            let reedHeight = height * (0.64 + CGFloat((index * 7) % 5) * 0.09)
            var stem = Path()
            stem.move(to: CGPoint(x: base.x + offset, y: base.y))
            stem.addQuadCurve(to: CGPoint(x: base.x + offset * 1.22, y: base.y - reedHeight),
                              control: CGPoint(x: base.x + offset * 0.78, y: base.y - reedHeight * 0.48))
            context.stroke(stem,
                           with: .color(index.isMultiple(of: 2) ? leafLight : savannaGreen),
                           style: StrokeStyle(lineWidth: max(0.8, height * 0.035), lineCap: .round))
            if index == 1 || index == 3 {
                let head = CGRect(x: base.x + offset * 1.22 - height * 0.025,
                                  y: base.y - reedHeight - height * 0.085,
                                  width: height * 0.05,
                                  height: height * 0.13)
                context.fill(Path(ellipseIn: head), with: .color(barkLight.opacity(0.84)))
            }
        }
    }

    private func paintLeftRootBank(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        // These roots visually continue the large frame tree into the ground,
        // replacing the isolated upright stump that looked placed at random.
        let roots: [(CGPoint, CGPoint, CGPoint, CGFloat)] = [
            (CGPoint(x: 0.030, y: 0.715), CGPoint(x: 0.105, y: 0.720), CGPoint(x: 0.245, y: 0.755), 0.030),
            (CGPoint(x: 0.045, y: 0.690), CGPoint(x: 0.110, y: 0.665), CGPoint(x: 0.205, y: 0.690), 0.022),
            (CGPoint(x: 0.020, y: 0.755), CGPoint(x: 0.075, y: 0.785), CGPoint(x: 0.165, y: 0.805), 0.026)
        ]
        for root in roots {
            var path = Path()
            path.move(to: CGPoint(x: w * root.0.x, y: h * root.0.y))
            path.addQuadCurve(to: CGPoint(x: w * root.2.x, y: h * root.2.y),
                              control: CGPoint(x: w * root.1.x, y: h * root.1.y))
            context.stroke(path,
                           with: .color(Color.black.opacity(0.18)),
                           style: StrokeStyle(lineWidth: w * root.3 * 1.25, lineCap: .round))
            context.stroke(path,
                           with: .linearGradient(
                            Gradient(colors: [bark, barkLight, sandDeep]),
                            startPoint: CGPoint(x: w * root.0.x, y: h * root.0.y),
                            endPoint: CGPoint(x: w * root.2.x, y: h * root.2.y)),
                           style: StrokeStyle(lineWidth: w * root.3, lineCap: .round))
        }

        let rocks: [(CGFloat, CGFloat, CGFloat)] = [
            (0.070, 0.760, 0.052), (0.130, 0.785, 0.043),
            (0.185, 0.755, 0.036), (0.095, 0.825, 0.048)
        ]
        for rock in rocks {
            paintRock(in: &context,
                      center: CGPoint(x: w * rock.0, y: h * rock.1),
                      radius: w * rock.2)
        }

        paintDenseGrassClump(in: &context,
                             base: CGPoint(x: w * 0.165, y: h * 0.790),
                             height: h * 0.085,
                             width: w * 0.100,
                             dry: false,
                             bladeCount: 15)
        paintDryBrush(in: &context,
                      base: CGPoint(x: w * 0.075, y: h * 0.735),
                      height: h * 0.075,
                      width: w * 0.070)
    }

    private func paintClimbingPost(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let postX = w * 0.145
        let postTop = h * 0.315
        let postBottom = h * 0.735
        let postWidth = w * 0.052
        let postRect = CGRect(x: postX - postWidth * 0.50,
                              y: postTop,
                              width: postWidth,
                              height: postBottom - postTop)
        let platforms: [(CGFloat, CGFloat, CGFloat)] = [
            (0.355, 0.170, -0.010),
            (0.455, 0.135, 0.018),
            (0.565, 0.175, -0.014),
            (0.680, 0.145, 0.012)
        ]

        // The rear halves are painted first and then naturally disappear
        // behind the trunk. Their exposed shoulders prove the rope continues
        // around the back instead of being drawn as stripes on the front.
        paintRopeWrapBack(in: &context,
                          center: CGPoint(x: postX, y: h * 0.515),
                          width: postWidth * 1.34,
                          height: h * 0.058)
        paintRopeWrapBack(in: &context,
                          center: CGPoint(x: postX, y: h * 0.635),
                          width: postWidth * 1.34,
                          height: h * 0.052)
        paintRopeWrapBack(in: &context,
                          center: CGPoint(x: postX, y: postBottom - h * 0.006),
                          width: postWidth * 1.42,
                          height: h * 0.033)
        for platform in platforms {
            paintRopeWrapBack(in: &context,
                              center: CGPoint(x: postX, y: h * platform.0),
                              width: postWidth * 1.34,
                              height: h * 0.018,
                              turns: 3)
        }

        context.fill(RoundedRectangle(cornerRadius: postWidth * 0.30, style: .continuous)
            .path(in: postRect.offsetBy(dx: w * 0.008, dy: h * 0.006)),
                     with: .color(Color.black.opacity(0.22)))
        context.fill(RoundedRectangle(cornerRadius: postWidth * 0.30, style: .continuous).path(in: postRect),
                     with: .linearGradient(
                        Gradient(colors: [bark, barkLight, Color(red: 0.27, green: 0.14, blue: 0.055)]),
                        startPoint: CGPoint(x: postRect.minX, y: postRect.minY),
                        endPoint: CGPoint(x: postRect.maxX, y: postRect.maxY)
                     ))

        // Irregular longitudinal cuts make this a real debarked trunk.
        for index in 0..<4 {
            let x = postRect.minX + postWidth * (0.18 + CGFloat(index) * 0.21)
            var groove = Path()
            groove.move(to: CGPoint(x: x, y: postTop + h * 0.018))
            groove.addCurve(to: CGPoint(x: x + CGFloat(index - 2) * w * 0.003, y: postBottom - h * 0.018),
                            control1: CGPoint(x: x + CGFloat(index % 2) * w * 0.007, y: h * 0.46),
                            control2: CGPoint(x: x - CGFloat(index % 2) * w * 0.006, y: h * 0.61))
            context.stroke(groove,
                           with: .color(index.isMultiple(of: 2) ? Color.white.opacity(0.13) : bark.opacity(0.48)),
                           style: StrokeStyle(lineWidth: isPad ? 1.5 : 0.9, lineCap: .round))
        }

        // Knots, old peg holes and growth rings break up the straight pole.
        let trunkKnots: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.12, 0.405, 0.19), (0.15, 0.585, 0.16), (-0.08, 0.704, 0.12)
        ]
        for knot in trunkKnots {
            let knotRect = CGRect(x: postX + postWidth * knot.0 - postWidth * knot.2,
                                  y: h * knot.1 - postWidth * knot.2 * 0.55,
                                  width: postWidth * knot.2 * 2,
                                  height: postWidth * knot.2 * 1.10)
            context.fill(Path(ellipseIn: knotRect), with: .color(bark.opacity(0.72)))
            context.stroke(Path(ellipseIn: knotRect.insetBy(dx: postWidth * 0.045,
                                                            dy: postWidth * 0.025)),
                           with: .color(Color(red: 0.75, green: 0.50, blue: 0.21).opacity(0.48)),
                           lineWidth: isPad ? 1.2 : 0.75)
        }

        for (index, platform) in platforms.enumerated() {
            let y = h * platform.0
            let width = w * platform.1
            let shift = w * platform.2
            let start = CGPoint(x: postX - width * 0.50 + shift, y: y)
            let end = CGPoint(x: postX + width * 0.50 + shift, y: y)
            var shelf = Path()
            shelf.move(to: start)
            shelf.addLine(to: end)
            context.stroke(shelf,
                           with: .color(Color.black.opacity(0.24)),
                           style: StrokeStyle(lineWidth: w * 0.030, lineCap: .round))
            context.stroke(shelf,
                           with: .linearGradient(
                            Gradient(colors: [bark, barkLight, bark]),
                            startPoint: start, endPoint: end),
                           style: StrokeStyle(lineWidth: w * 0.023, lineCap: .round))

            var highlight = Path()
            highlight.move(to: CGPoint(x: start.x + w * 0.008, y: start.y - w * 0.006))
            highlight.addCurve(to: CGPoint(x: end.x - w * 0.008, y: end.y - w * 0.005),
                               control1: CGPoint(x: postX - width * 0.18, y: y - w * 0.009),
                               control2: CGPoint(x: postX + width * 0.20, y: y - w * 0.003))
            context.stroke(highlight,
                           with: .color(Color(red: 0.88, green: 0.66, blue: 0.32).opacity(0.36)),
                           style: StrokeStyle(lineWidth: isPad ? 1.5 : 0.9, lineCap: .round))

            // End grain and a dark core make every platform read as a branch.
            for endPoint in [start, end] {
                let endGrain = CGRect(x: endPoint.x - w * 0.011,
                                      y: endPoint.y - w * 0.009,
                                      width: w * 0.022,
                                      height: w * 0.018)
                context.fill(Path(ellipseIn: endGrain),
                             with: .color(Color(red: 0.68, green: 0.44, blue: 0.17)))
                context.stroke(Path(ellipseIn: endGrain.insetBy(dx: w * 0.004, dy: w * 0.003)),
                               with: .color(bark.opacity(0.54)),
                               lineWidth: isPad ? 1.0 : 0.65)
            }

            // Small diagonal brace below alternating shelves.
            let braceDirection: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            var brace = Path()
            brace.move(to: CGPoint(x: postX, y: y + h * 0.008))
            brace.addLine(to: CGPoint(x: postX + braceDirection * width * 0.34,
                                      y: y + h * 0.040))
            context.stroke(brace,
                           with: .color(bark.opacity(0.82)),
                           style: StrokeStyle(lineWidth: w * 0.010, lineCap: .round))

            // The front halves complete the rear lashings painted before the
            // trunk, so every single strand now passes around real depth.
            paintRopeWrap(in: &context,
                          center: CGPoint(x: postX, y: y),
                          width: postWidth * 1.34,
                          height: h * 0.018,
                          turns: 3,
                          showKnot: false)
        }

        // Two substantial sisal scratching zones connect the shelves.
        paintRopeWrap(in: &context,
                      center: CGPoint(x: postX, y: h * 0.515),
                      width: postWidth * 1.34,
                      height: h * 0.058)
        paintRopeWrap(in: &context,
                      center: CGPoint(x: postX, y: h * 0.635),
                      width: postWidth * 1.34,
                      height: h * 0.052)

        // Visible cut ends on the top shelf and trunk.
        let cap = CGRect(x: postX - postWidth * 0.54,
                         y: postTop - postWidth * 0.16,
                         width: postWidth * 1.08,
                         height: postWidth * 0.42)
        context.fill(Path(ellipseIn: cap), with: .color(Color(red: 0.69, green: 0.48, blue: 0.22)))
        context.stroke(Path(ellipseIn: cap.insetBy(dx: postWidth * 0.18, dy: postWidth * 0.06)),
                       with: .color(bark.opacity(0.40)), lineWidth: isPad ? 1.4 : 0.85)

        // A broad, lashed foot grounds the structure instead of letting the
        // narrow pole appear to float over the sand.
        let footY = postBottom + h * 0.006
        var foot = Path()
        foot.move(to: CGPoint(x: postX - w * 0.070, y: footY))
        foot.addQuadCurve(to: CGPoint(x: postX + w * 0.070, y: footY),
                          control: CGPoint(x: postX, y: footY - h * 0.010))
        context.stroke(foot, with: .color(Color.black.opacity(0.22)),
                       style: StrokeStyle(lineWidth: w * 0.029, lineCap: .round))
        context.stroke(foot,
                       with: .linearGradient(Gradient(colors: [bark, barkLight, bark]),
                                             startPoint: CGPoint(x: postX - w * 0.070, y: footY),
                                             endPoint: CGPoint(x: postX + w * 0.070, y: footY)),
                       style: StrokeStyle(lineWidth: w * 0.022, lineCap: .round))
        paintRopeWrap(in: &context,
                      center: CGPoint(x: postX, y: postBottom - h * 0.006),
                      width: postWidth * 1.42,
                      height: h * 0.033)
    }

    private func paintRopeWrap(in context: inout GraphicsContext,
                               center: CGPoint,
                               width: CGFloat,
                               height: CGFloat,
                               turns: Int = 8,
                               showKnot: Bool = true) {
        for index in 0..<turns {
            let divisor = CGFloat(max(1, turns - 1))
            let y = center.y - height * 0.50 + CGFloat(index) * height / divisor
            let left = CGPoint(x: center.x - width * 0.50, y: y)
            let right = CGPoint(x: center.x + width * 0.50, y: y)
            var front = Path()
            front.move(to: left)
            front.addQuadCurve(to: right,
                               control: CGPoint(x: center.x, y: y + height * 0.115))
            context.stroke(front,
                           with: .color(Color(red: 0.32, green: 0.19, blue: 0.065).opacity(0.58)),
                           style: StrokeStyle(lineWidth: max(1.2, height * 0.082), lineCap: .round))
            context.stroke(front,
                           with: .linearGradient(
                            Gradient(colors: [Color(red: 0.58, green: 0.39, blue: 0.14),
                                              Color(red: 0.92, green: 0.73, blue: 0.40),
                                              Color(red: 0.46, green: 0.28, blue: 0.09)]),
                            startPoint: left,
                            endPoint: right),
                           style: StrokeStyle(lineWidth: max(0.85, height * 0.052), lineCap: .round))
        }
        if showKnot {
            let knot = CGRect(x: center.x + width * 0.31,
                              y: center.y + height * 0.20,
                              width: width * 0.24,
                              height: width * 0.20)
            context.fill(Path(ellipseIn: knot), with: .color(Color(red: 0.43, green: 0.25, blue: 0.08)))
        }
    }

    private func paintRopeWrapBack(in context: inout GraphicsContext,
                                   center: CGPoint,
                                   width: CGFloat,
                                   height: CGFloat,
                                   turns: Int = 8) {
        for index in 0..<turns {
            let divisor = CGFloat(max(1, turns - 1))
            let y = center.y - height * 0.50 + CGFloat(index) * height / divisor
            let left = CGPoint(x: center.x - width * 0.50, y: y)
            let right = CGPoint(x: center.x + width * 0.50, y: y)
            var back = Path()
            back.move(to: left)
            back.addQuadCurve(to: right,
                              control: CGPoint(x: center.x, y: y - height * 0.105))
            context.stroke(back,
                           with: .linearGradient(
                            Gradient(colors: [Color(red: 0.42, green: 0.26, blue: 0.075),
                                              Color(red: 0.72, green: 0.52, blue: 0.23),
                                              Color(red: 0.38, green: 0.22, blue: 0.065)]),
                            startPoint: left,
                            endPoint: right),
                           style: StrokeStyle(lineWidth: max(0.85, height * 0.052), lineCap: .round))
        }
    }

    private func paintClimbingNet(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let topLeft = CGPoint(x: w * 0.770, y: h * 0.205)
        let topRight = CGPoint(x: w * 0.982, y: h * 0.192)
        let bottomLeft = CGPoint(x: w * 0.755, y: h * 0.430)
        let bottomRight = CGPoint(x: w * 0.978, y: h * 0.417)

        // Two independent hangers explain how the frame is carried.
        let hangers: [(CGPoint, CGPoint)] = [
            (CGPoint(x: w * 0.805, y: h * 0.074), topLeft),
            (CGPoint(x: w * 0.955, y: h * 0.060), topRight)
        ]
        for hanger in hangers {
            var rope = Path()
            rope.move(to: hanger.0)
            rope.addCurve(to: hanger.1,
                          control1: CGPoint(x: hanger.0.x - w * 0.018, y: h * 0.125),
                          control2: CGPoint(x: hanger.1.x + w * 0.012, y: h * 0.165))
            context.stroke(rope,
                           with: .linearGradient(
                            Gradient(colors: [Color(red: 0.80, green: 0.61, blue: 0.29), bark]),
                            startPoint: hanger.0, endPoint: hanger.1),
                           style: StrokeStyle(lineWidth: isPad ? 3.0 : 1.9, lineCap: .round))
        }

        // Diamond rope lattice, deliberately slightly irregular.
        let ropeColor = Color(red: 0.72, green: 0.50, blue: 0.22)
        for index in 0..<6 {
            let t = CGFloat(index) / 5
            var down = Path()
            down.move(to: CGPoint(x: topLeft.x + (topRight.x - topLeft.x) * t,
                                  y: topLeft.y + (topRight.y - topLeft.y) * t))
            down.addLine(to: CGPoint(x: bottomLeft.x + (bottomRight.x - bottomLeft.x) * min(1, t + 0.34),
                                     y: bottomLeft.y + (bottomRight.y - bottomLeft.y) * min(1, t + 0.34)))
            context.stroke(down, with: .color(ropeColor.opacity(0.90)),
                           style: StrokeStyle(lineWidth: isPad ? 2.4 : 1.45, lineCap: .round))

            var up = Path()
            up.move(to: CGPoint(x: topLeft.x + (topRight.x - topLeft.x) * t,
                                y: topLeft.y + (topRight.y - topLeft.y) * t))
            up.addLine(to: CGPoint(x: bottomLeft.x + (bottomRight.x - bottomLeft.x) * max(0, t - 0.34),
                                   y: bottomLeft.y + (bottomRight.y - bottomLeft.y) * max(0, t - 0.34)))
            context.stroke(up, with: .color(ropeColor.opacity(0.82)),
                           style: StrokeStyle(lineWidth: isPad ? 2.4 : 1.45, lineCap: .round))
        }

        // Knots placed on a staggered grid make the crossings readable.
        for row in 0..<4 {
            for column in 0..<4 {
                let x = w * (0.792 + CGFloat(column) * 0.048 + (row.isMultiple(of: 2) ? 0.0 : 0.022))
                let y = h * (0.247 + CGFloat(row) * 0.047)
                let knot = CGRect(x: x - w * 0.006, y: y - w * 0.005,
                                  width: w * 0.012, height: w * 0.010)
                context.fill(Path(ellipseIn: knot), with: .color(Color(red: 0.45, green: 0.27, blue: 0.085)))
                context.stroke(Path(ellipseIn: knot.insetBy(dx: w * 0.002, dy: w * 0.0015)),
                               with: .color(Color.white.opacity(0.16)), lineWidth: isPad ? 0.9 : 0.55)
            }
        }

        let beams: [(CGPoint, CGPoint)] = [
            (topLeft, topRight), (topRight, bottomRight),
            (bottomRight, bottomLeft), (bottomLeft, topLeft)
        ]
        for beam in beams {
            var log = Path()
            log.move(to: beam.0)
            log.addLine(to: beam.1)
            context.stroke(log, with: .color(Color.black.opacity(0.24)),
                           style: StrokeStyle(lineWidth: w * 0.028, lineCap: .round))
            context.stroke(log,
                           with: .linearGradient(
                            Gradient(colors: [bark, barkLight, bark]),
                            startPoint: beam.0, endPoint: beam.1),
                           style: StrokeStyle(lineWidth: w * 0.021, lineCap: .round))
        }

        for corner in [topLeft, topRight, bottomLeft, bottomRight] {
            let cap = CGRect(x: corner.x - w * 0.011, y: corner.y - w * 0.009,
                             width: w * 0.022, height: w * 0.018)
            context.fill(Path(ellipseIn: cap), with: .color(Color(red: 0.67, green: 0.43, blue: 0.16)))
            context.fill(Path(ellipseIn: cap.insetBy(dx: w * 0.005, dy: w * 0.004)),
                         with: .color(bark.opacity(0.68)))
        }
    }

    private func paintSedgeBank(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let base = CGPoint(x: w * 0.825, y: h * 0.68)

        // Dark soil and rock remain visible immediately left of the bin.
        let mound = CGRect(x: w * 0.725, y: h * 0.635,
                           width: w * 0.19, height: h * 0.065)
        context.fill(Path(ellipseIn: mound),
                     with: .linearGradient(
                        Gradient(colors: [sandDeep.opacity(0.88), bark.opacity(0.72)]),
                        startPoint: CGPoint(x: mound.midX, y: mound.minY),
                        endPoint: CGPoint(x: mound.midX, y: mound.maxY)
                     ))

        for index in 0..<13 {
            let t = CGFloat(index) / 12
            let x = base.x + (t - 0.5) * w * 0.19
            let bladeHeight = h * (0.105 + CGFloat((index * 11) % 7) * 0.013)
            let lean = (t - 0.50) * w * 0.065
            var blade = Path()
            blade.move(to: CGPoint(x: x, y: base.y))
            blade.addCurve(to: CGPoint(x: x + lean, y: base.y - bladeHeight),
                           control1: CGPoint(x: x - lean * 0.18, y: base.y - bladeHeight * 0.42),
                           control2: CGPoint(x: x + lean * 0.65, y: base.y - bladeHeight * 0.72))
            context.stroke(blade,
                           with: .linearGradient(
                            Gradient(colors: [savannaGreen, index.isMultiple(of: 3) ? leafLight : palette.leaf]),
                            startPoint: CGPoint(x: x, y: base.y),
                            endPoint: CGPoint(x: x + lean, y: base.y - bladeHeight)),
                           style: StrokeStyle(lineWidth: isPad ? 3.2 : 2.0, lineCap: .round))
        }

    }

    private func paintLeaf(in context: inout GraphicsContext,
                           center: CGPoint,
                           length: CGFloat,
                           angle: Double,
                           color: Color) {
        let direction = CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
        let normal = CGVector(dx: -direction.dy, dy: direction.dx)
        let tip = CGPoint(x: center.x + direction.dx * length * 0.52,
                          y: center.y + direction.dy * length * 0.52)
        let root = CGPoint(x: center.x - direction.dx * length * 0.52,
                           y: center.y - direction.dy * length * 0.52)
        var leaf = Path()
        leaf.move(to: root)
        leaf.addQuadCurve(to: tip,
                          control: CGPoint(x: center.x + normal.dx * length * 0.30,
                                           y: center.y + normal.dy * length * 0.30))
        leaf.addQuadCurve(to: root,
                          control: CGPoint(x: center.x - normal.dx * length * 0.30,
                                           y: center.y - normal.dy * length * 0.30))
        leaf.closeSubpath()
        context.fill(leaf, with: .linearGradient(
            Gradient(colors: [color.opacity(0.96), color.opacity(0.68)]),
            startPoint: root, endPoint: tip
        ))

        var vein = Path()
        vein.move(to: CGPoint(x: root.x + direction.dx * length * 0.16,
                              y: root.y + direction.dy * length * 0.16))
        vein.addLine(to: CGPoint(x: tip.x - direction.dx * length * 0.12,
                                 y: tip.y - direction.dy * length * 0.12))
        context.stroke(vein,
                       with: .color(Color.white.opacity(0.14)),
                       style: StrokeStyle(lineWidth: max(0.5, length * 0.035), lineCap: .round))
    }

    private func paintHangingVines(in context: inout GraphicsContext, size: CGSize) {
        let vines: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.14, 0.02, 0.16, 0.29), (0.48, 0.01, 0.46, 0.19),
            (0.68, 0.02, 0.70, 0.25), (0.86, 0.02, 0.83, 0.34)
        ]
        for (index, vine) in vines.enumerated() {
            let start = CGPoint(x: size.width * vine.0, y: size.height * vine.1)
            let end = CGPoint(x: size.width * vine.2, y: size.height * vine.3)
            let direction: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            var strand = Path()
            strand.move(to: start)
            strand.addCurve(to: end,
                            control1: CGPoint(x: start.x + direction * size.width * 0.035,
                                              y: size.height * vine.3 * 0.35),
                            control2: CGPoint(x: end.x - direction * size.width * 0.030,
                                              y: size.height * vine.3 * 0.72))
            context.stroke(strand,
                           with: .linearGradient(
                            Gradient(colors: [savannaGreen, barkLight.opacity(0.90)]),
                            startPoint: start, endPoint: end),
                           style: StrokeStyle(lineWidth: isPad ? 2.8 : 1.7, lineCap: .round))

            let curlRadius = size.width * (isPad ? 0.014 : 0.018)
            var curl = Path()
            curl.move(to: end)
            curl.addCurve(to: CGPoint(x: end.x, y: end.y + curlRadius * 1.7),
                          control1: CGPoint(x: end.x + curlRadius * 1.8, y: end.y - curlRadius * 0.30),
                          control2: CGPoint(x: end.x + curlRadius * 1.6, y: end.y + curlRadius * 1.9))
            curl.addCurve(to: CGPoint(x: end.x + curlRadius * 0.35, y: end.y + curlRadius * 0.80),
                          control1: CGPoint(x: end.x - curlRadius * 0.85, y: end.y + curlRadius * 1.8),
                          control2: CGPoint(x: end.x - curlRadius * 0.65, y: end.y + curlRadius * 0.72))
            context.stroke(curl,
                           with: .color(savannaGreen.opacity(0.88)),
                           style: StrokeStyle(lineWidth: isPad ? 2.0 : 1.25, lineCap: .round))

            if index != 1 {
                paintLeaf(in: &context,
                          center: CGPoint(x: end.x + (index.isMultiple(of: 2) ? -curlRadius : curlRadius),
                                          y: end.y - curlRadius * 0.30),
                          length: size.width * 0.026,
                          angle: index.isMultiple(of: 2) ? -0.45 : 0.45,
                          color: leafLight)
            }
        }
    }

    private func paintAcacia(in context: inout GraphicsContext,
                             center: CGPoint,
                             scale: CGFloat,
                             distant: Bool) {
        let trunkColor = bark.opacity(distant ? 0.40 : 0.85)
        let crownY = center.y - scale * 0.57
        var trunk = Path()
        trunk.move(to: center)
        trunk.addCurve(to: CGPoint(x: center.x - scale * 0.025, y: crownY + scale * 0.10),
                       control1: CGPoint(x: center.x - scale * 0.035, y: center.y - scale * 0.18),
                       control2: CGPoint(x: center.x + scale * 0.030, y: center.y - scale * 0.38))
        context.stroke(trunk, with: .color(trunkColor),
                       style: StrokeStyle(lineWidth: max(1, scale * 0.045), lineCap: .round))

        for direction in [-1.0, 1.0] {
            var branch = Path()
            branch.move(to: CGPoint(x: center.x, y: center.y - scale * 0.34))
            branch.addCurve(to: CGPoint(x: center.x + CGFloat(direction) * scale * 0.30,
                                        y: crownY + scale * 0.035),
                            control1: CGPoint(x: center.x + CGFloat(direction) * scale * 0.08,
                                              y: center.y - scale * 0.42),
                            control2: CGPoint(x: center.x + CGFloat(direction) * scale * 0.18,
                                              y: crownY + scale * 0.10))
            context.stroke(branch, with: .color(trunkColor),
                           style: StrokeStyle(lineWidth: max(0.8, scale * 0.022), lineCap: .round))

            var fork = Path()
            fork.move(to: CGPoint(x: center.x + CGFloat(direction) * scale * 0.16,
                                  y: crownY + scale * 0.10))
            fork.addLine(to: CGPoint(x: center.x + CGFloat(direction) * scale * 0.39,
                                     y: crownY + scale * 0.025))
            context.stroke(fork, with: .color(trunkColor.opacity(0.90)),
                           style: StrokeStyle(lineWidth: max(0.65, scale * 0.014), lineCap: .round))
        }

        // Flat-topped but irregular crown, assembled from overlapping masses
        // rather than one recognisable ellipse.
        let lobes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.34, 0.00, 0.34, 0.15), (-0.18, -0.055, 0.36, 0.18),
            (0.02, -0.075, 0.38, 0.20), (0.22, -0.035, 0.34, 0.17),
            (-0.04, 0.035, 0.60, 0.16)
        ]
        for (index, lobe) in lobes.enumerated() {
            let rect = CGRect(x: center.x + scale * lobe.0 - scale * lobe.2 * 0.5,
                              y: crownY + scale * lobe.1 - scale * lobe.3 * 0.5,
                              width: scale * lobe.2,
                              height: scale * lobe.3)
            context.fill(Path(ellipseIn: rect),
                         with: .color((index < 2 ? leafLight : savannaGreen)
                            .opacity(distant ? 0.44 + Double(index) * 0.025 : 0.88)))
        }

        var crownShadow = Path()
        crownShadow.move(to: CGPoint(x: center.x - scale * 0.42, y: crownY + scale * 0.065))
        crownShadow.addQuadCurve(to: CGPoint(x: center.x + scale * 0.43, y: crownY + scale * 0.055),
                                 control: CGPoint(x: center.x, y: crownY + scale * 0.15))
        context.stroke(crownShadow,
                       with: .color(savannaGreen.opacity(distant ? 0.28 : 0.58)),
                       style: StrokeStyle(lineWidth: max(1.2, scale * 0.035), lineCap: .round))
    }

    private func paintRock(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        var rock = Path()
        rock.move(to: CGPoint(x: center.x - radius, y: center.y + radius * 0.34))
        rock.addQuadCurve(to: CGPoint(x: center.x - radius * 0.30, y: center.y - radius * 0.62),
                          control: CGPoint(x: center.x - radius * 0.76, y: center.y - radius * 0.42))
        rock.addQuadCurve(to: CGPoint(x: center.x + radius * 0.78, y: center.y + radius * 0.05),
                          control: CGPoint(x: center.x + radius * 0.30, y: center.y - radius * 0.78))
        rock.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y + radius * 0.34),
                          control: CGPoint(x: center.x + radius * 0.28, y: center.y + radius * 0.58))
        context.fill(rock, with: .linearGradient(
            Gradient(colors: [Color(red: 0.48, green: 0.39, blue: 0.26),
                              Color(red: 0.23, green: 0.18, blue: 0.13)]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)
        ))
        var facet = Path()
        facet.move(to: CGPoint(x: center.x - radius * 0.30, y: center.y - radius * 0.58))
        facet.addLine(to: CGPoint(x: center.x + radius * 0.10, y: center.y - radius * 0.20))
        facet.addLine(to: CGPoint(x: center.x + radius * 0.66, y: center.y + radius * 0.02))
        context.stroke(facet,
                       with: .color(Color.white.opacity(0.13)),
                       style: StrokeStyle(lineWidth: max(0.55, radius * 0.055), lineCap: .round))
        var fissure = Path()
        fissure.move(to: CGPoint(x: center.x + radius * 0.10, y: center.y - radius * 0.19))
        fissure.addLine(to: CGPoint(x: center.x - radius * 0.02, y: center.y + radius * 0.12))
        fissure.addLine(to: CGPoint(x: center.x + radius * 0.13, y: center.y + radius * 0.30))
        context.stroke(fissure,
                       with: .color(Color.black.opacity(0.20)),
                       style: StrokeStyle(lineWidth: max(0.45, radius * 0.040), lineCap: .round))
    }

    private func paintStump(in context: inout GraphicsContext, rect: CGRect) {
        context.fill(RoundedRectangle(cornerRadius: rect.width * 0.18, style: .continuous).path(in: rect),
                     with: .linearGradient(
                        Gradient(colors: [barkLight, bark, Color(red: 0.19, green: 0.10, blue: 0.04)]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                     ))
        let top = CGRect(x: rect.minX - rect.width * 0.04,
                         y: rect.minY - rect.width * 0.15,
                         width: rect.width * 1.08,
                         height: rect.width * 0.40)
        context.fill(Path(ellipseIn: top), with: .color(Color(red: 0.70, green: 0.49, blue: 0.23)))
        for index in 0..<3 {
            let inset = top.width * (0.13 + CGFloat(index) * 0.11)
            context.stroke(Path(ellipseIn: top.insetBy(dx: inset, dy: inset * 0.30)),
                           with: .color(bark.opacity(0.32)),
                           style: StrokeStyle(lineWidth: isPad ? 1.3 : 0.9))
        }
        for index in 0..<3 {
            let x = rect.minX + rect.width * (0.28 + CGFloat(index) * 0.22)
            var grain = Path()
            grain.move(to: CGPoint(x: x, y: rect.minY + rect.width * 0.30))
            grain.addCurve(to: CGPoint(x: x - rect.width * 0.05, y: rect.maxY - rect.width * 0.12),
                           control1: CGPoint(x: x + rect.width * 0.08, y: rect.midY),
                           control2: CGPoint(x: x - rect.width * 0.08, y: rect.midY))
            context.stroke(grain, with: .color(Color.white.opacity(0.10)), lineWidth: 1)
        }
        for index in 0..<5 {
            let angle = Double(index) * 1.18 - 0.55
            let start = CGPoint(x: top.midX + CGFloat(cos(angle)) * top.width * 0.09,
                                y: top.midY + CGFloat(sin(angle)) * top.height * 0.08)
            let end = CGPoint(x: top.midX + CGFloat(cos(angle)) * top.width * 0.40,
                              y: top.midY + CGFloat(sin(angle)) * top.height * 0.38)
            var split = Path()
            split.move(to: start)
            split.addLine(to: end)
            context.stroke(split,
                           with: .color(bark.opacity(0.34)),
                           style: StrokeStyle(lineWidth: isPad ? 1.2 : 0.8, lineCap: .round))
        }

        // Jagged bark tabs keep the base from ending in a machine-perfect line.
        for index in 0..<4 {
            let x = rect.minX + rect.width * (0.14 + CGFloat(index) * 0.24)
            var tab = Path()
            tab.move(to: CGPoint(x: x - rect.width * 0.055, y: rect.maxY - rect.width * 0.03))
            tab.addLine(to: CGPoint(x: x, y: rect.maxY + rect.width * (index.isMultiple(of: 2) ? 0.10 : 0.06)))
            tab.addLine(to: CGPoint(x: x + rect.width * 0.06, y: rect.maxY - rect.width * 0.025))
            tab.closeSubpath()
            context.fill(tab, with: .color(index.isMultiple(of: 2) ? bark : barkLight.opacity(0.72)))
        }
    }

    private func paintGrass(in context: inout GraphicsContext, base: CGPoint, height: CGFloat) {
        for index in 0..<7 {
            let t = CGFloat(index) / 6
            let spread = (t - 0.5) * height * 0.92
            var blade = Path()
            blade.move(to: base)
            blade.addQuadCurve(to: CGPoint(x: base.x + spread, y: base.y - height * (0.58 + 0.42 * abs(t - 0.5) * 2)),
                               control: CGPoint(x: base.x + spread * 0.16, y: base.y - height * 0.58))
            context.stroke(blade,
                           with: .color(index.isMultiple(of: 2) ? leafLight : savannaGreen),
                           style: StrokeStyle(lineWidth: max(1, height * 0.055), lineCap: .round))
        }
    }
}

/// Slow dust and tiny water glints keep the habitat alive without adding
/// decorative symbols or competing with the moving elephant.
private struct SanctuaryLivingDetails: View {
    let isPad: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let travel = reduceMotion ? 0 : CGFloat(time.truncatingRemainder(dividingBy: 8) / 8)

                paintFlyingBirds(in: &context, size: size, time: time)

                // Slow dust motes add life while remaining far quieter than
                // the claw and without introducing decorative UI symbols.
                for index in 0..<6 {
                    let seed = CGFloat((index * 29) % 91) / 91
                    let x = size.width * (0.16 + seed * 0.68)
                    let cycle = (travel + CGFloat(index) * 0.17).truncatingRemainder(dividingBy: 1)
                    let y = size.height * (0.47 - cycle * 0.25)
                    let mote = CGRect(x: x, y: y,
                                      width: isPad ? 3.2 : 2.2,
                                      height: isPad ? 3.2 : 2.2)
                    context.fill(Path(ellipseIn: mote),
                                 with: .color(Color.white.opacity(0.16 * Double(1 - cycle))))
                }

                // Slow travelling wavelets stay inside the irregular water
                // silhouette. Broken strokes feel reflective rather than like
                // a loading indicator placed over the scenery.
                for index in 0..<5 {
                    let phase = reduceMotion ? CGFloat(0) : CGFloat(sin(time * 0.82 + Double(index) * 0.91))
                    let y = size.height * (0.557 + CGFloat(index) * 0.014)
                        + phase * size.height * 0.0018
                    let startX = size.width * (0.365 + CGFloat(index) * 0.012)
                        + phase * size.width * 0.008
                    let endX = size.width * (0.525 + CGFloat(index) * 0.030)
                        + phase * size.width * 0.006
                    let gapCenter = startX + (endX - startX) * (0.44 + phase * 0.06)
                    let gap = size.width * (0.012 + CGFloat(index) * 0.0015)

                    var leftWave = Path()
                    leftWave.move(to: CGPoint(x: startX, y: y))
                    leftWave.addCurve(to: CGPoint(x: gapCenter - gap, y: y),
                                      control1: CGPoint(x: startX + (gapCenter - startX) * 0.34,
                                                        y: y - size.height * 0.0035),
                                      control2: CGPoint(x: startX + (gapCenter - startX) * 0.72,
                                                        y: y + size.height * 0.0020))
                    var rightWave = Path()
                    rightWave.move(to: CGPoint(x: gapCenter + gap, y: y))
                    rightWave.addCurve(to: CGPoint(x: endX, y: y),
                                       control1: CGPoint(x: gapCenter + (endX - gapCenter) * 0.32,
                                                         y: y + size.height * 0.0022),
                                       control2: CGPoint(x: gapCenter + (endX - gapCenter) * 0.72,
                                                         y: y - size.height * 0.0030))
                    let opacity = 0.34 - Double(index) * 0.035
                    let style = StrokeStyle(lineWidth: isPad ? 1.8 : 1.05, lineCap: .round)
                    context.stroke(leftWave, with: .color(Color.white.opacity(opacity)), style: style)
                    context.stroke(rightWave, with: .color(Color.white.opacity(opacity * 0.82)), style: style)
                }

                // Two overlapping rings continuously appear and dissolve, as
                // if an occasional drop or insect touches the surface.
                for index in 0..<2 {
                    let rawPhase = reduceMotion
                        ? CGFloat(index) * 0.42
                        : CGFloat((time * 0.24 + Double(index) * 0.52).truncatingRemainder(dividingBy: 1))
                    let rippleWidth = size.width * (0.025 + rawPhase * 0.105)
                    let rippleHeight = size.height * (0.004 + rawPhase * 0.014)
                    let center = CGPoint(x: size.width * 0.525, y: size.height * 0.588)
                    let ring = CGRect(x: center.x - rippleWidth,
                                      y: center.y - rippleHeight,
                                      width: rippleWidth * 2,
                                      height: rippleHeight * 2)
                    context.stroke(Path(ellipseIn: ring),
                                   with: .color(Color.white.opacity(0.25 * Double(1 - rawPhase))),
                                   style: StrokeStyle(lineWidth: isPad ? 1.5 : 0.9, lineCap: .round))
                }

                // The tyre is intentionally part of this living layer rather
                // than the static habitat Canvas, allowing a very small sway.
                var swingContext = context
                let pivot = CGPoint(x: size.width * 0.24, y: 0)
                let sway = reduceMotion ? 0 : sin(time * 0.68) * 1.65
                swingContext.translateBy(x: pivot.x, y: pivot.y)
                swingContext.rotate(by: .degrees(sway))
                swingContext.translateBy(x: -pivot.x, y: -pivot.y)
                paintTireSwing(in: &swingContext, size: size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func paintFlyingBirds(in context: inout GraphicsContext,
                                  size: CGSize,
                                  time: TimeInterval) {
        let w = size.width
        let h = size.height
        for index in 0..<4 {
            let duration = 13.0 + Double(index) * 2.7
            let offset = Double(index) * 0.23
            let progress = reduceMotion
                ? CGFloat(0.24 + offset * 0.42)
                : CGFloat((time / duration + offset).truncatingRemainder(dividingBy: 1))
            let x = w * (-0.08 + progress * 1.16)
            let baseY = h * (0.245 + CGFloat(index % 3) * 0.038)
            let bob = reduceMotion ? CGFloat(0) : CGFloat(sin(time * 0.72 + Double(index))) * h * 0.004
            let y = baseY + bob
            let halfSpan = w * (0.011 + CGFloat(index % 2) * 0.004)
            let flap = reduceMotion
                ? h * 0.003
                : CGFloat(sin(time * 3.1 + Double(index) * 1.17)) * h * 0.0048

            var wings = Path()
            wings.move(to: CGPoint(x: x - halfSpan, y: y + flap * 0.32))
            wings.addQuadCurve(to: CGPoint(x: x, y: y),
                               control: CGPoint(x: x - halfSpan * 0.48, y: y - flap))
            wings.addQuadCurve(to: CGPoint(x: x + halfSpan, y: y + flap * 0.28),
                               control: CGPoint(x: x + halfSpan * 0.48, y: y - flap * 0.92))
            context.stroke(wings,
                           with: .color(Color(red: 0.13, green: 0.15, blue: 0.12).opacity(0.58)),
                           style: StrokeStyle(lineWidth: isPad ? 2.0 : 1.15,
                                              lineCap: .round,
                                              lineJoin: .round))

            let body = CGRect(x: x - halfSpan * 0.14,
                              y: y - halfSpan * 0.05,
                              width: halfSpan * 0.28,
                              height: halfSpan * 0.18)
            context.fill(Path(ellipseIn: body),
                         with: .color(Color(red: 0.12, green: 0.14, blue: 0.11).opacity(0.54)))
        }
    }

    private func paintTireSwing(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let ropeStart = CGPoint(x: w * 0.24, y: 0)
        let tireCenter = CGPoint(x: w * 0.255, y: h * 0.255)
        let bark = Color(red: 0.34, green: 0.19, blue: 0.075)
        let barkLight = Color(red: 0.61, green: 0.39, blue: 0.16)
        let vine = Color(red: 0.30, green: 0.43, blue: 0.11)

        var liana = Path()
        liana.move(to: ropeStart)
        liana.addCurve(to: CGPoint(x: tireCenter.x, y: tireCenter.y - h * 0.022),
                       control1: CGPoint(x: w * 0.20, y: h * 0.075),
                       control2: CGPoint(x: w * 0.30, y: h * 0.15))
        context.stroke(liana, with: .color(Color.black.opacity(0.30)),
                       style: StrokeStyle(lineWidth: isPad ? 6 : 4, lineCap: .round))
        context.stroke(liana,
                       with: .linearGradient(Gradient(colors: [vine, barkLight, bark]),
                                             startPoint: ropeStart,
                                             endPoint: tireCenter),
                       style: StrokeStyle(lineWidth: isPad ? 4.2 : 2.8, lineCap: .round))

        let diameter = min(w * 0.115, h * 0.105)
        let tireRect = CGRect(x: tireCenter.x - diameter * 0.50,
                              y: tireCenter.y - diameter * 0.50,
                              width: diameter,
                              height: diameter)
        let rubberWidth = diameter * 0.245
        context.stroke(Path(ellipseIn: tireRect.offsetBy(dx: diameter * 0.035,
                                                         dy: diameter * 0.065)),
                       with: .color(Color.black.opacity(0.34)),
                       style: StrokeStyle(lineWidth: rubberWidth * 1.10))
        context.stroke(Path(ellipseIn: tireRect),
                       with: .linearGradient(
                        Gradient(colors: [Color(red: 0.30, green: 0.27, blue: 0.20),
                                          Color(red: 0.105, green: 0.095, blue: 0.075),
                                          Color(red: 0.035, green: 0.038, blue: 0.032)]),
                        startPoint: CGPoint(x: tireRect.minX, y: tireRect.minY),
                        endPoint: CGPoint(x: tireRect.maxX, y: tireRect.maxY)),
                       style: StrokeStyle(lineWidth: rubberWidth, lineCap: .round))
        context.stroke(Path(ellipseIn: tireRect.insetBy(dx: rubberWidth * 0.16,
                                                        dy: rubberWidth * 0.16)),
                       with: .color(Color.white.opacity(0.16)),
                       style: StrokeStyle(lineWidth: isPad ? 1.8 : 1.05))
        context.stroke(Path(ellipseIn: tireRect.insetBy(dx: rubberWidth * 0.52,
                                                        dy: rubberWidth * 0.52)),
                       with: .color(Color.black.opacity(0.52)),
                       style: StrokeStyle(lineWidth: isPad ? 2.3 : 1.4))

        var sidewallGlint = Path()
        sidewallGlint.addArc(center: tireCenter,
                             radius: diameter * 0.50,
                             startAngle: .degrees(205),
                             endAngle: .degrees(305),
                             clockwise: false)
        context.stroke(sidewallGlint,
                       with: .color(Color.white.opacity(0.12)),
                       style: StrokeStyle(lineWidth: rubberWidth * 0.22, lineCap: .round))

        let knotY = tireRect.minY + rubberWidth * 0.12
        for index in 0..<3 {
            let knot = CGRect(x: tireCenter.x - rubberWidth * (0.48 + CGFloat(index) * 0.035),
                              y: knotY + CGFloat(index) * rubberWidth * 0.16,
                              width: rubberWidth * (0.96 + CGFloat(index) * 0.07),
                              height: rubberWidth * 0.30)
            context.stroke(Path(ellipseIn: knot),
                           with: .color(index == 1 ? barkLight : bark),
                           style: StrokeStyle(lineWidth: isPad ? 2.4 : 1.55, lineCap: .round))
        }
    }
}

private struct CatchBinBackView: View, Equatable {
    let palette: ClawPalette
    let isPad: Bool

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let depth = w * 0.42
            ZStack(alignment: .bottomLeading) {
                Path { path in
                    path.move(to: CGPoint(x: w - depth, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w, y: h * 0.08))
                    path.addLine(to: CGPoint(x: w, y: h + 48))
                    path.addLine(to: CGPoint(x: w - depth, y: h + 48))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [palette.wood, palette.woodDeep],
                                     startPoint: .top, endPoint: .bottom))

                Path { path in
                    path.move(to: CGPoint(x: 4, y: h * 0.22))
                    path.addLine(to: CGPoint(x: w - depth - 2, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w - 2, y: h * 0.08))
                    path.addLine(to: CGPoint(x: depth * 0.45, y: h * 0.12))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(colors: [palette.bin,
                                            palette.binDeep],
                                   startPoint: .top, endPoint: .bottom)
                )

                Path { path in
                    path.move(to: CGPoint(x: 1, y: h * 0.22))
                    path.addLine(to: CGPoint(x: w - depth, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w - 1, y: h * 0.08))
                    path.addLine(to: CGPoint(x: depth * 0.42, y: h * 0.12))
                    path.closeSubpath()
                }
                .stroke(palette.bin.opacity(0.90), lineWidth: isPad ? 5 : 3.5)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CatchBinFrontView: View, Equatable {
    let palette: ClawPalette
    let isPad: Bool

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let depth = w * 0.42
            ZStack(alignment: .bottomLeading) {
                Path { path in
                    path.move(to: CGPoint(x: 2, y: h * 0.22))
                    path.addLine(to: CGPoint(x: w - depth, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w - depth, y: h + 48))
                    path.addLine(to: CGPoint(x: 2, y: h + 48))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(colors: [Color(red: 0.78, green: 0.58, blue: 0.34),
                                            palette.wood,
                                            palette.woodDeep],
                                   startPoint: .top, endPoint: .bottom)
                )

                Image(systemName: "pawprint.fill")
                    .font(.system(size: min(w * 0.42, isPad ? 28 : 20), weight: .bold))
                    .foregroundStyle(palette.woodDeep.opacity(0.40))
                    .position(x: (w - depth) * 0.48, y: h * 0.62)
            }
        }
        .allowsHitTesting(false)
    }
}
