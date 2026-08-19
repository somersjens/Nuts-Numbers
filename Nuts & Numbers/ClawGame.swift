//
//  ClawGame.swift
//  Nuts & Numbers
//
//  The claw-machine playing surface. The session still lives in `MemoryGame`;
//  this file only steers the hanging elephant, decides which reachable nut was
//  chosen, and plays the grab / return / time-up animations.
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

    static let descendDuration = 0.28
    static let grabPause = 0.08
    static let ascendDuration = 0.24
    static let carryDuration = 0.32
    static let dropDuration = 1.08
    static let returnDuration = 0.26
    static let spitDuration = 1.08

    static let entranceDuration = 0.85
    static let completionDuration = 1.15
    static let timeUpDuration = 1.35

    /// Drawn height of the hanging-elephant PNG. The artwork is a tall canvas
    /// with the character only in the top ~41%, so this is larger than the
    /// visible body on screen.
    static func elephantDrawnHeight(isPad: Bool) -> CGFloat { isPad ? 560 : 430 }
    /// Fraction of the 1024×1536 canvas that actually contains the claw + body
    /// (content ends at row 625). A few extra points keep the front feet inside
    /// the crop after layout rounding.
    static let elephantContentFraction: CGFloat = 640.0 / 1536.0
    static func elephantVisibleHeight(isPad: Bool) -> CGFloat {
        elephantDrawnHeight(isPad: isPad) * elephantContentFraction + (isPad ? 18 : 14)
    }

    static func nutPixelRadius(unit: Double, pile: CGSize) -> CGFloat {
        CGFloat(unit) * pile.width * 1.04
    }
}

// MARK: - Palette

struct ClawPalette {
    let character: AnimalCharacter

    var wood: Color { Color(red: 0.55, green: 0.34, blue: 0.16) }
    var woodDeep: Color { Color(red: 0.32, green: 0.18, blue: 0.08) }
    var woodLight: Color { Color(red: 0.76, green: 0.56, blue: 0.32) }
    var leaf: Color { Color(red: 0.28, green: 0.58, blue: 0.24) }
    var leafLight: Color { Color(red: 0.45, green: 0.74, blue: 0.32) }
    var glass: Color { character.skyColor.opacity(0.35) }
    var interior: Color { Color(red: 0.78, green: 0.88, blue: 0.94) }
    var bin: Color { character.color }
    var binDeep: Color { character.deepColor }
    var button: Color { Color(red: 0.86, green: 0.18, blue: 0.16) }
    var buttonDeep: Color { Color(red: 0.62, green: 0.08, blue: 0.08) }
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
    let spec: ClawNut
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

    @Published var trolleyX: CGFloat = 0.5
    @Published var trolleyY: CGFloat = 0
    @Published var swingAngle: CGFloat = 0
    @Published var phase: ClawPhase = .idle
    @Published var nuts: [ClawNutRuntime] = []
    @Published var heldNutID: UUID?
    @Published var motionClock = 0.0
    @Published var flyingScores: [FlyingScore] = []
    @Published var buttonPressed = false
    @Published var joystickInput: CGFloat = 0
    @Published var elephantVisible = true
    @Published var promptPulse = 0.0

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
    private var phaseAge: Double = 0
    private var grabTarget: UUID?
    private var grabStartX: CGFloat = 0.5
    private var grabDepth: CGFloat = 0.7
    private var carryFromX: CGFloat = 0.5
    private var dropFrom: CGPoint = .zero
    private var dropTo: CGPoint = .zero
    private var dropFlightTime = ClawConfig.dropDuration
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
    private var reduceMotion = false

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
        let panelH: CGFloat = isPad ? 216 : 178
        let top = topReserve + 2
        let headerW = min(size.width - post * 2 - (isPad ? 200 : 150), size.width * 0.50)
        headerRect = CGRect(x: (size.width - headerW) / 2, y: top, width: headerW, height: headerH)
        panelRect = CGRect(x: 0,
                           y: size.height - panelH - max(bottomReserve * 0.12, 2),
                           width: size.width,
                           height: panelH + max(bottomReserve * 0.12, 2))
        playRect = CGRect(x: post,
                          y: headerRect.maxY + 8,
                          width: size.width - post * 2,
                          height: max(180, panelRect.minY - headerRect.maxY - 2))
        pileRect = CGRect(x: playRect.minX + playRect.width * 0.015,
                          y: playRect.minY + playRect.height * 0.22,
                          width: playRect.width * 0.80,
                          height: playRect.height * 0.76)
        let binW = playRect.width * 0.18
        let binH = playRect.height * 0.52
        binRect = CGRect(x: playRect.maxX - binW - playRect.width * 0.01,
                         y: playRect.maxY - binH,
                         width: binW,
                         height: binH)
        restY = 0
        relayoutNuts()
    }

    func install(puzzle: ClawPuzzle?, collected: Int, question: MathQuestion?, targetNutID: UUID?) {
        currentTargetNutID = targetNutID
        currentAnswer = question.map { AnswerValue($0.correctAnswer) }
        promptPulse = 1
        guard let puzzle else {
            nuts = []
            return
        }
        let remaining = puzzle.remainingNuts(afterCollected: collected)
        nuts = remaining.map { spec in
            let rest = screenPoint(spec.position)
            return ClawNutRuntime(spec: spec,
                                  rest: rest,
                                  position: rest,
                                  isPresent: true,
                                  rotation: Double(spec.id.hashValue % 11) * 0.015,
                                  pixelRadius: ClawConfig.nutPixelRadius(unit: spec.radius,
                                                                         pile: pileRect.size))
        }
        refreshReachableCovering()
    }

    func setQuestion(_ question: MathQuestion?, targetNutID: UUID?) {
        currentTargetNutID = targetNutID
        currentAnswer = question.map { AnswerValue($0.correctAnswer) }
        promptPulse = 1
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
        guard phase == .idle || phase == .returning else { return }
        input = max(-1, min(1, value))
        joystickInput = input
        if abs(input) > 0.25, tutorialPlan.wantsMove, !hasReportedMove {
            hasReportedMove = true
            onTutorialEvent?(.movedClaw)
        }
    }

    func pressGrab() {
        guard acceptsGrab else { return }
        onTutorialEvent?(.pressedGrab)
        buttonPressed = true
        startGrab()
    }

    func beginEntrance(completion: @escaping () -> Void) {
        onEntranceComplete = completion
        entranceAge = 0
        trolleyY = -0.55
        swingAngle = 0.35
        elephantVisible = true
    }

    func beginLevelCompletion(reduceMotion: Bool, completion: @escaping () -> Void) {
        self.reduceMotion = reduceMotion
        onLevelCompletionFinished = completion
        phase = .celebrating
        phaseAge = 0
        finaleAge = 0
        heldNutID = nil
        input = 0
    }

    func beginTimeUp(reduceMotion: Bool, completion: @escaping () -> Void) {
        self.reduceMotion = reduceMotion
        onTimeOutFinished = completion
        phase = .timeUp
        phaseAge = 0
        finaleAge = 0
        heldNutID = nil
        input = 0
        isLive = false
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
        let target = nearestReachableNut()
        grabTarget = target?.id
        grabStartX = trolleyX
        grabDepth = depthToward(target)
        phase = .descending
        phaseAge = 0
        input = 0
        joystickInput = 0
    }

    private func depthToward(_ target: ClawNutRuntime?) -> CGFloat {
        let elephant = ClawConfig.elephantVisibleHeight(isPad: isPad)
        let span = max(90, pileRect.maxY - playRect.minY - elephant * 0.22)
        let desiredY: CGFloat
        if let target {
            desiredY = target.rest.y - elephant * 0.78
        } else {
            desiredY = pileRect.minY + 8
        }
        let restY = playRect.minY + 16
        return max(0.28, min(1, (desiredY - restY) / span))
    }

    private func nearestReachableNut() -> ClawNutRuntime? {
        let remaining = nuts.filter(\.isPresent)
        let reachable = remaining.filter { ClawPuzzle.isReachable($0.spec, among: remaining.map(\.spec)) }
        let trolley = trolleyScreen
        let reach = pileRect.width * 0.20
        return reachable
            .map { nut in (nut, abs(nut.position.x - trolley.x)) }
            .filter { $0.1 < max(reach, $0.0.pixelRadius * 1.45) }
            .min { $0.1 < $1.1 }?
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
        promptPulse = max(0, promptPulse - dt * 1.8)
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
        stepFlights(dt: dt)
        objectWillChange.send()
    }

    private func stepTrolley(dt: Double) {
        guard phase == .idle, entranceAge == nil else { return }
        let previous = trolleyX
        trolleyX = max(0.04, min(0.88, trolleyX + input * ClawConfig.trolleySpeed * dt))
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
            buttonPressed = false
        case .descending:
            let t = min(1, phaseAge / ClawConfig.descendDuration)
            trolleyY = easeIn(t) * grabDepth
            if t >= 1 { enter(.grabbing) }
        case .grabbing:
            if let id = grabTarget, let index = nuts.firstIndex(where: { $0.id == id }) {
                heldNutID = id
                nuts[index].position = trunkPoint
            }
            if phaseAge >= ClawConfig.grabPause { enter(.ascending) }
        case .ascending:
            let t = min(1, phaseAge / ClawConfig.ascendDuration)
            trolleyY = grabDepth * (1 - easeOut(t))
            if let id = heldNutID, let index = nuts.firstIndex(where: { $0.id == id }) {
                nuts[index].position = trunkPoint
            }
            if t >= 1 {
                if heldNutID == nil {
                    enter(.returning)
                } else {
                    carryFromX = trolleyX
                    enter(.carrying)
                }
            }
        case .carrying:
            let t = min(1, phaseAge / ClawConfig.carryDuration)
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
            nuts[index].position = ballistic(from: dropFrom, to: dropTo, t: t, duration: dropFlightTime)
            nuts[index].rotation += dt * 1.8
            if t >= 1 {
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
            if t >= 1 {
                nuts[index].position = spitTo
                nuts[index].isPresent = true
                heldNutID = nil
                enter(.returning)
            }
        case .returning:
            let t = min(1, phaseAge / ClawConfig.returnDuration)
            let target = grabStartX
            trolleyX += (target - trolleyX) * min(1, t)
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
        let correct = currentAnswer.map { AnswerValue(nut.text) == $0 } ?? false
        if correct {
            nuts[index].isPresent = false
            heldNutID = nil
            onGrabResolved?(nut, true)
            onScoreBubbleArrived?()
            enter(.returning)
        } else {
            spitFrom = nuts[index].position
            spitTo = nuts[index].rest
            spitFlightTime = flightTime(from: spitFrom, to: spitTo)
            onGrabResolved?(nut, false)
            enter(.spitBack)
        }
    }

    private func prepareDrop() {
        guard let id = heldNutID, let index = nuts.firstIndex(where: { $0.id == id }) else { return }
        dropFrom = nuts[index].position
        dropTo = CGPoint(x: binRect.minX + binRect.width * 0.42,
                         y: binRect.minY + binRect.height * 0.58)
        dropFlightTime = flightTime(from: dropFrom, to: dropTo)
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
        let t = min(1, phaseAge / ClawConfig.timeUpDuration)
        trolleyX += (binUnitX - trolleyX) * min(1, CGFloat(dt) * 3)
        trolleyY = easeIn(t) * 0.85
        swingAngle = sin(t * 9) * 0.18 * (1 - t)
        if t > 0.72 {
            elephantVisible = t < 0.92
        }
        if t >= 1 {
            elephantVisible = false
            onTimeOutFinished?()
            phase = .idle
        }
    }

    private func stepCelebration(dt: Double) {
        let t = min(1, phaseAge / ClawConfig.completionDuration)
        swingAngle = sin(t * 10) * 0.22 * (1 - t)
        trolleyX = 0.5 + sin(t * 6) * 0.04
        if t >= 1 {
            onLevelCompletionFinished?()
            phase = .idle
        }
    }

    private func stepFlights(dt: Double) {
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
        if next == .idle { buttonPressed = false }
    }

    private func refreshReachableCovering() {
        var specs = nuts.map(\.spec)
        for i in specs.indices {
            specs[i].position = ClawPoint(x: Double((nuts[i].rest.x - pileRect.minX) / max(pileRect.width, 1)),
                                          y: Double((nuts[i].rest.y - pileRect.minY) / max(pileRect.height, 1)))
        }
        // Covering is already stored on the spec from generation.
        _ = specs
    }

    private func relayoutNuts() {
        for i in nuts.indices {
            let rest = screenPoint(nuts[i].spec.position)
            nuts[i].rest = rest
            if heldNutID != nuts[i].id {
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
        let span = max(90, pileRect.maxY - playRect.minY - elephant * 0.22)
        return CGPoint(x: playRect.minX + playRect.width * trolleyX,
                       y: playRect.minY + 16 + trolleyY * span)
    }

    var trunkPoint: CGPoint {
        let origin = trolleyScreen
        let length = ClawConfig.elephantVisibleHeight(isPad: isPad) * 0.92
        return CGPoint(x: origin.x + sin(swingAngle) * length,
                       y: origin.y + cos(swingAngle) * length)
    }

    var highlightedNutIDs: Set<UUID> {
        guard let currentAnswer else { return [] }
        let remaining = nuts.filter(\.isPresent)
        let specs = remaining.map(\.spec)
        return Set(remaining.compactMap { nut in
            guard AnswerValue(nut.spec.text) == currentAnswer else { return nil }
            guard ClawPuzzle.isReachable(nut.spec, among: specs) else { return nil }
            return nut.id
        })
    }

    private var binUnitX: CGFloat {
        CGFloat((binRect.midX - playRect.minX) / max(playRect.width, 1))
    }

    var geometry: (play: CGRect, pile: CGRect, bin: CGRect, header: CGRect, panel: CGRect) {
        (playRect, pileRect, binRect, headerRect, panelRect)
    }

    private func startLink() {
#if canImport(UIKit)
        guard displayLink == nil else { return }
        lastFrameTargetTimestamp = nil
        let link = CADisplayLink(target: displayLinkTarget,
                                 selector: #selector(DisplayLinkTarget.advance(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
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
#else
        timer?.invalidate()
        timer = nil
#endif
    }

    private func easeIn(_ t: Double) -> CGFloat { CGFloat(t * t) }
    private func easeOut(_ t: Double) -> CGFloat { CGFloat(1 - (1 - t) * (1 - t)) }
    private func easeInOut(_ t: Double) -> CGFloat {
        CGFloat(t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2)
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

    private var palette: ClawPalette { ClawPalette(character: character) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                MachineCabinet(palette: palette, size: size)

                let geo = engine.geometry
                glassChamber(geo: geo)

                if engine.elephantVisible {
                    hangingElephant(in: geo.play)
                        .frame(width: geo.play.width, height: geo.play.height)
                        .position(x: geo.play.midX, y: geo.play.midY)
                }

                promptPlaque
                    .frame(width: geo.header.width, height: geo.header.height)
                    .position(x: geo.header.midX, y: geo.header.midY)

                controlPanel
                    .frame(width: geo.panel.width, height: geo.panel.height)
                    .position(x: geo.panel.midX, y: geo.panel.midY)
            }
            .frame(width: size.width, height: size.height)
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

    // MARK: Machine

    private func glassChamber(geo: (play: CGRect, pile: CGRect, bin: CGRect, header: CGRect, panel: CGRect)) -> some View {
        let corner: CGFloat = isPad ? 26 : 18
        return ZStack(alignment: .topLeading) {
            SanctuaryScene(palette: palette, character: character, isPad: isPad)
                .frame(width: geo.play.width, height: geo.play.height)

            trolleyRail(in: geo.play)

            Ellipse()
                .fill(Color.black.opacity(0.28))
                .frame(width: geo.pile.width * 0.96, height: isPad ? 32 : 22)
                .position(x: geo.pile.midX - geo.play.minX,
                          y: geo.pile.maxY - geo.play.minY - 4)
                .blur(radius: 4)
                .allowsHitTesting(false)

            ForEach(engine.nuts.filter(\.isPresent).sorted(by: { $0.rest.y > $1.rest.y })) { nut in
                NutView(nut: nut,
                        isTarget: engine.highlightedNutIDs.contains(nut.id) && engine.heldNutID != nut.id)
                    .position(x: nut.position.x - geo.play.minX, y: nut.position.y - geo.play.minY)
            }

            CatchBinView(palette: palette, isPad: isPad)
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
                .strokeBorder(
                    LinearGradient(colors: [palette.woodLight, palette.wood, palette.woodDeep],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: isPad ? 10 : 7
                )
        }
        .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
        .position(x: geo.play.midX, y: geo.play.midY)
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

    private var promptPlaque: some View {
        Text(verbatim: round?.question.prompt ?? "")
            .font(.system(size: isPad ? 38 : 28, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.45)
            .lineLimit(1)
            .scaleEffect(1 + 0.04 * engine.promptPulse)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: isPad ? 16 : 12, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color(red: 0.42, green: 0.26, blue: 0.12),
                                                Color(red: 0.26, green: 0.14, blue: 0.06),
                                                Color(red: 0.16, green: 0.08, blue: 0.04)],
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
            .accessibilityValue(Text(verbatim: L("game.claw.progress \(round?.number ?? 1) \(maximumRounds)")))
    }

    private func hangingElephant(in play: CGRect) -> some View {
        let origin = engine.trolleyScreen
        let drawn = ClawConfig.elephantDrawnHeight(isPad: isPad)
        let visible = ClawConfig.elephantVisibleHeight(isPad: isPad)
        let fullW = drawn * (1024.0 / 1536.0)
        let local = CGPoint(x: origin.x - play.minX, y: origin.y - play.minY)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: local.x, y: 0))
                path.addLine(to: CGPoint(x: local.x + sin(engine.swingAngle) * 4, y: local.y + 4))
            }
            .stroke(
                LinearGradient(colors: [Color(red: 0.55, green: 0.42, blue: 0.22),
                                        Color(red: 0.18, green: 0.12, blue: 0.08)],
                               startPoint: .top, endPoint: .bottom),
                style: StrokeStyle(lineWidth: isPad ? 6 : 4.5, lineCap: .round)
            )

            Image("hanging elephant")
                .resizable()
                .frame(width: fullW, height: drawn)
                .fixedSize()
                .frame(width: fullW, height: visible, alignment: .top)
                .clipped()
                .rotationEffect(.radians(Double(engine.swingAngle)), anchor: .top)
                .position(x: local.x, y: local.y + visible * 0.50)
                .shadow(color: .black.opacity(0.42), radius: 14, y: 12)
        }
        .frame(width: play.width, height: play.height)
        .allowsHitTesting(false)
    }

    private var controlPanel: some View {
        let lipH: CGFloat = isPad ? 38 : 30
        let topInset: CGFloat = isPad ? 34 : 22
        let corner: CGFloat = isPad ? 20 : 15

        return GeometryReader { proxy in
            let board = ArcadeShelfShape(topInset: topInset, bottomRadius: 0)
            VStack(spacing: 0) {
                ZStack {
                    board.fill(
                        LinearGradient(
                            colors: [Color(red: 0.38, green: 0.22, blue: 0.10),
                                     Color(red: 0.62, green: 0.40, blue: 0.20),
                                     Color(red: 0.78, green: 0.56, blue: 0.32)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    board.fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.18), .clear, Color.white.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    ArcadeShelfSideEdge(topInset: topInset, side: .leading)
                        .fill(Color(red: 0.22, green: 0.12, blue: 0.05).opacity(0.55))
                    ArcadeShelfSideEdge(topInset: topInset, side: .trailing)
                        .fill(Color(red: 0.46, green: 0.30, blue: 0.14).opacity(0.35))

                    woodGrain
                        .clipShape(board)
                    woodKnots
                        .clipShape(board)

                    LinearGradient(colors: [Color.black.opacity(0.38), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: isPad ? 22 : 16)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipShape(board)

                    HStack(alignment: .center, spacing: isPad ? 18 : 12) {
                        joystick
                        Spacer(minLength: 0)
                        grabButton
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: isPad ? 22 : 16, weight: .bold))
                            .foregroundStyle(palette.woodDeep.opacity(0.38))
                            .offset(y: isPad ? 10 : 8)
                    }
                    .padding(.horizontal, isPad ? 36 : 24)
                    .padding(.top, isPad ? 14 : 10)
                    .padding(.bottom, isPad ? 10 : 8)
                }
                .frame(maxHeight: .infinity)

                ZStack {
                    UnevenRoundedRectangle(bottomLeadingRadius: corner,
                                           bottomTrailingRadius: corner,
                                           style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.70, green: 0.50, blue: 0.28),
                                         Color(red: 0.42, green: 0.24, blue: 0.10),
                                         Color(red: 0.22, green: 0.12, blue: 0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    LinearGradient(colors: [Color.white.opacity(0.28), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 10)
                        .frame(maxHeight: .infinity, alignment: .top)
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 11)
                }
                .clipShape(
                    UnevenRoundedRectangle(bottomLeadingRadius: corner,
                                           bottomTrailingRadius: corner,
                                           style: .continuous)
                )
                .frame(height: lipH)
                .shadow(color: .black.opacity(0.40), radius: 10, y: 6)
            }
            .shadow(color: .black.opacity(0.28), radius: 12, y: -2)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var woodGrain: some View {
        VStack(spacing: isPad ? 11 : 9) {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(Color.black.opacity(index.isMultiple(of: 2) ? 0.06 : 0.03))
                    .frame(height: 1.2)
                    .padding(.horizontal, CGFloat(6 + index * 3))
            }
        }
        .padding(.vertical, 10)
        .allowsHitTesting(false)
    }

    private var woodKnots: some View {
        ZStack {
            Ellipse()
                .stroke(palette.woodDeep.opacity(0.28), lineWidth: 2)
                .frame(width: isPad ? 22 : 16, height: isPad ? 16 : 12)
                .offset(x: isPad ? 78 : 54, y: isPad ? -18 : -12)
            Ellipse()
                .stroke(palette.woodDeep.opacity(0.20), lineWidth: 1.5)
                .frame(width: isPad ? 16 : 12, height: isPad ? 12 : 9)
                .offset(x: isPad ? -90 : -62, y: isPad ? 16 : 12)
        }
        .allowsHitTesting(false)
    }

    private var joystick: some View {
        HStack(spacing: isPad ? 10 : 6) {
            holdButton(system: "arrowtriangle.left.fill", value: -1)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.18),
                                                Color(red: 0.04, green: 0.05, blue: 0.08)],
                                       center: .center, startRadius: 2, endRadius: isPad ? 50 : 40)
                    )
                    .frame(width: isPad ? 88 : 70, height: isPad ? 88 : 70)
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                    }
                    .overlay {
                        Circle().stroke(Color.black.opacity(0.45), lineWidth: 4).blur(radius: 2)
                            .clipShape(Circle())
                    }
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.44, blue: 0.50),
                                                  Color(red: 0.12, green: 0.12, blue: 0.14)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: isPad ? 15 : 12, height: isPad ? 36 : 28)
                    .offset(x: engine.joystickInput * (isPad ? 20 : 15), y: -8)
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.46, blue: 0.38),
                                                  Color(red: 0.86, green: 0.12, blue: 0.10),
                                                  Color(red: 0.42, green: 0.04, blue: 0.04)],
                                         center: UnitPoint(x: 0.32, y: 0.26),
                                         startRadius: 1, endRadius: 22))
                    .frame(width: isPad ? 42 : 34, height: isPad ? 42 : 34)
                    .offset(x: engine.joystickInput * (isPad ? 20 : 15), y: -20)
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let span: CGFloat = isPad ? 40 : 32
                        engine.setInput(max(-1, min(1, value.translation.width / span)))
                    }
                    .onEnded { _ in engine.setInput(0) }
            )
            holdButton(system: "arrowtriangle.right.fill", value: 1)
        }
        .padding(.horizontal, isPad ? 12 : 8)
        .padding(.vertical, isPad ? 10 : 7)
        .background {
            RoundedRectangle(cornerRadius: isPad ? 22 : 16, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(red: 0.18, green: 0.26, blue: 0.42),
                                            Color(red: 0.08, green: 0.12, blue: 0.22)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: isPad ? 22 : 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1.2)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: isPad ? 22 : 16, style: .continuous)
                        .stroke(Color.black.opacity(0.45), lineWidth: 5)
                        .blur(radius: 3)
                        .clipShape(RoundedRectangle(cornerRadius: isPad ? 22 : 16, style: .continuous))
                }
                .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
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

    private func holdButton(system: String, value: CGFloat) -> some View {
        Image(systemName: system)
            .font(.system(size: isPad ? 20 : 16, weight: .black))
            .foregroundStyle(Color(red: 0.32, green: 0.16, blue: 0.04))
            .frame(width: isPad ? 46 : 36, height: isPad ? 46 : 36)
            .background {
                RoundedRectangle(cornerRadius: isPad ? 12 : 10, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color(red: 1.0, green: 0.88, blue: 0.34),
                                                Color(red: 0.94, green: 0.62, blue: 0.08),
                                                Color(red: 0.72, green: 0.40, blue: 0.04)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: isPad ? 12 : 10, style: .continuous)
                            .stroke(Color.white.opacity(0.40), lineWidth: 1.2)
                    }
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(height: 6)
                            .padding(.horizontal, 8)
                            .padding(.top, 5)
                    }
            }
            .shadow(color: .black.opacity(0.30), radius: 2, y: 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in engine.setInput(value) }
                    .onEnded { _ in engine.setInput(0) }
            )
            .accessibilityHidden(true)
    }

    private var grabButton: some View {
        Button(action: engine.pressGrab) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [Color(red: 0.62, green: 0.42, blue: 0.22),
                                                palette.woodDeep,
                                                Color(red: 0.16, green: 0.08, blue: 0.03)],
                                       center: UnitPoint(x: 0.38, y: 0.30),
                                       startRadius: 8, endRadius: isPad ? 78 : 64)
                    )
                    .frame(width: isPad ? 148 : 122, height: isPad ? 148 : 122)
                    .overlay {
                        Circle().stroke(palette.woodLight.opacity(0.45), lineWidth: 3)
                    }
                    .overlay {
                        Circle().stroke(Color.black.opacity(0.35), lineWidth: 2).padding(7)
                    }
                Circle()
                    .fill(
                        RadialGradient(colors: [Color(red: 1.0, green: 0.38, blue: 0.32),
                                                palette.button,
                                                palette.buttonDeep],
                                       center: UnitPoint(x: 0.38, y: 0.28),
                                       startRadius: 4, endRadius: isPad ? 80 : 64)
                    )
                    .frame(width: isPad ? 124 : 100, height: isPad ? 124 : 100)
                Circle()
                    .stroke(.white.opacity(0.42), lineWidth: 3)
                    .frame(width: isPad ? 110 : 88, height: isPad ? 110 : 88)
                Text("game.claw.grab")
                    .font(.system(size: isPad ? 32 : 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            }
            .scaleEffect(engine.buttonPressed ? 0.94 : 1)
            .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!engine.acceptsGrab)
        .accessibilityIdentifier("claw-grab")
        .accessibilityLabel(Text("game.claw.grab"))
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

// MARK: - Nut

struct NutView: View {
    let nut: ClawNutRuntime
    var isTarget = false

    var body: some View {
        let size = max(28, nut.pixelRadius * 2.0)
        let gold = nut.spec.isGold
        ZStack {
            walnutLobe(size: size, gold: gold)
                .offset(x: -size * 0.12)
            walnutLobe(size: size, gold: gold)
                .offset(x: size * 0.12)
            Capsule()
                .fill(Color(red: 0.26, green: 0.13, blue: 0.04).opacity(0.55))
                .frame(width: size * 0.10, height: size * 0.78)
            Ellipse()
                .fill(Color.white.opacity(0.18))
                .frame(width: size * 0.22, height: size * 0.12)
                .offset(x: -size * 0.22, y: -size * 0.22)
            Text(verbatim: nut.spec.text)
                .font(.system(size: max(10, size * 0.42), weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.05, blue: 0.02))
                .minimumScaleFactor(0.32)
                .lineLimit(1)
                .padding(.horizontal, 2)
        }
        .frame(width: size, height: size)
        .rotationEffect(.radians(nut.rotation))
        .shadow(color: .black.opacity(0.28), radius: 2, y: 1.5)
        .overlay {
            if isTarget {
                Ellipse()
                    .stroke(Color(red: 1.0, green: 0.84, blue: 0.12), lineWidth: 3.5)
                    .scaleEffect(1.14)
                Ellipse()
                    .stroke(Color(red: 1.0, green: 0.92, blue: 0.35).opacity(0.85), lineWidth: 2)
                    .scaleEffect(1.22)
                    .blur(radius: 0.6)
                Ellipse()
                    .fill(Color(red: 1.0, green: 0.82, blue: 0.18).opacity(0.20))
                    .scaleEffect(1.20)
                    .blur(radius: 4)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func walnutLobe(size: CGFloat, gold: Bool) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: gold
                        ? [Color(red: 1.0, green: 0.94, blue: 0.55),
                           Color(red: 0.90, green: 0.66, blue: 0.16),
                           Color(red: 0.52, green: 0.30, blue: 0.05)]
                        : [Color(red: 0.93, green: 0.74, blue: 0.46),
                           Color(red: 0.70, green: 0.44, blue: 0.20),
                           Color(red: 0.34, green: 0.18, blue: 0.06)],
                    center: UnitPoint(x: 0.32, y: 0.28),
                    startRadius: 1,
                    endRadius: size * 0.62
                )
            )
            .overlay {
                Ellipse().stroke(Color(red: 0.28, green: 0.14, blue: 0.04).opacity(0.45), lineWidth: 1.1)
            }
            .frame(width: size * 0.72, height: size * 0.96)
    }
}

// MARK: - Cabinet & sanctuary

private struct MachineCabinet: View {
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
            VStack(spacing: size.height * 0.09) {
                ForEach(0..<7, id: \.self) { index in
                    ZStack {
                        Capsule()
                            .stroke(Color(red: 0.48, green: 0.34, blue: 0.16).opacity(0.7), lineWidth: 4)
                            .frame(width: width * 0.94, height: 11)
                        if index % 2 == 0 {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: width * 0.36, weight: .bold))
                                .foregroundStyle(palette.woodDeep.opacity(0.48))
                        }
                    }
                }
            }
        }
        .frame(width: width)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 0)
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
        path.addCurve(to: CGPoint(x: x + lean * 10, y: size.height * 0.92),
                      control1: CGPoint(x: x - lean * 16, y: size.height * 0.32),
                      control2: CGPoint(x: x + lean * 18, y: size.height * 0.64))
        context.stroke(path,
                       with: .color(palette.leaf.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }

    private func vineLeaves(width: CGFloat, height: CGFloat, lean: CGFloat, x: CGFloat) -> some View {
        ForEach(0..<8, id: \.self) { index in
            let y = height * (0.10 + CGFloat(index) * 0.10)
            Image(systemName: "leaf.fill")
                .font(.system(size: index.isMultiple(of: 2) ? 24 : 17, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [palette.leafLight, palette.leaf],
                                                startPoint: .top, endPoint: .bottom))
                .rotationEffect(.degrees(Double(22 * lean + (index.isMultiple(of: 2) ? -14 : 16))))
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                .position(x: width * x + lean * CGFloat(8 + index % 3 * 4), y: y)
        }
    }
}

private struct SanctuaryScene: View {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.84, blue: 0.66),
                         Color(red: 0.86, green: 0.74, blue: 0.52),
                         Color(red: 0.62, green: 0.42, blue: 0.22)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 6) {
                ForEach(0..<10, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.07 : 0.03))
                        .frame(height: 1)
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 12)

            pawWall
            hangingLamps
            tireSwing

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: isPad ? 12 : 8) {
                    VStack(alignment: .leading, spacing: isPad ? 8 : 5) {
                        warningSign
                        birdhouse
                    }
                    Spacer(minLength: 0)
                    window
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: isPad ? 8 : 5) {
                        homePoster
                        catCubby
                    }
                }
                .padding(.horizontal, isPad ? 16 : 8)
                .padding(.top, isPad ? 28 : 20)

                Spacer(minLength: 0)

                woodenFloor
                    .frame(height: isPad ? 40 : 26)
            }
        }
        .allowsHitTesting(false)
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
                .fill(Color.yellow.opacity(0.22))
                .frame(width: isPad ? 54 : 38, height: isPad ? 54 : 38)
                .blur(radius: 8)
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
                HStack(spacing: 5) {
                    ForEach(0..<9, id: \.self) { _ in
                        Rectangle().fill(Color.black.opacity(0.08))
                    }
                }
            }
    }
}

private struct CatchBinView: View {
    let palette: ClawPalette
    let isPad: Bool

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let depth = w * 0.42
            ZStack(alignment: .bottomLeading) {
                // Far side wall, receding to the right.
                Path { path in
                    path.move(to: CGPoint(x: w - depth, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w, y: h * 0.08))
                    path.addLine(to: CGPoint(x: w, y: h + 48))
                    path.addLine(to: CGPoint(x: w - depth, y: h + 48))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [palette.wood, palette.woodDeep],
                                     startPoint: .top, endPoint: .bottom))

                // Interior of the open top, seen from the side.
                Path { path in
                    path.move(to: CGPoint(x: 4, y: h * 0.22))
                    path.addLine(to: CGPoint(x: w - depth - 2, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w - 2, y: h * 0.08))
                    path.addLine(to: CGPoint(x: depth * 0.45, y: h * 0.12))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(colors: [Color(red: 0.20, green: 0.38, blue: 0.68),
                                            Color(red: 0.08, green: 0.16, blue: 0.32)],
                                   startPoint: .top, endPoint: .bottom)
                )

                // Front face continues into the cabinet so the chute has no floor.
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

                // Blue metal rim along the open top.
                Path { path in
                    path.move(to: CGPoint(x: 1, y: h * 0.22))
                    path.addLine(to: CGPoint(x: w - depth, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w - 1, y: h * 0.08))
                    path.addLine(to: CGPoint(x: depth * 0.42, y: h * 0.12))
                    path.closeSubpath()
                }
                .stroke(Color(red: 0.32, green: 0.52, blue: 0.86), lineWidth: isPad ? 5 : 3.5)

                Image(systemName: "pawprint.fill")
                    .font(.system(size: min(w * 0.42, isPad ? 28 : 20), weight: .bold))
                    .foregroundStyle(palette.woodDeep.opacity(0.40))
                    .position(x: (w - depth) * 0.48, y: h * 0.62)
            }
        }
        .shadow(color: .black.opacity(0.32), radius: 6, y: 4)
        .allowsHitTesting(false)
    }
}
