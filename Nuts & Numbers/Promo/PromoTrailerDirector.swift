//
//  PromoTrailerDirector.swift
//  Nuts & Numbers
//
//  Drives the real ClawEngine + GameViewModel along a fixed teaser timeline.
//

import SwiftUI
import Combine

@MainActor
final class PromoTrailerDirector: ObservableObject {
    @Published private(set) var characterID = "elephant"
    @Published private(set) var headlineText = ""
    @Published private(set) var headlineOpacity: Double = 0
    @Published private(set) var iconOpacity: Double = 0
    @Published private(set) var iconScale: CGFloat = 0.84
    @Published private(set) var iconRotation: Double = -16
    @Published private(set) var playsLevelCompletion = false
    @Published private(set) var backgroundBlur: CGFloat = 0
    @Published private(set) var themeFlash: Double = 0
    @Published private(set) var isFinished = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var headerMaxY: CGFloat = 80
    @Published private(set) var panelMinY: CGFloat = 720

    private weak var engine: ClawEngine?
    private weak var model: GameViewModel?

    private let session = PromoTrailerScript.session()

    private enum Beat: Equatable {
        case entrance
        case hold
        case moveRight
        case moveLeft
        case returnCenter
        case firstGrab
        case unlockAlign
        case wrongGrab
        case correctGrab
        case speed
        case finale
        case icon
        case done
    }

    private var beat: Beat = .entrance
    private var beatAge: TimeInterval = 0
    private var didPressForBeat = false
    private var alignedAge: TimeInterval = 0
    private var edgeDwellAge: TimeInterval = 0
    private var completedGrabs = 0
    private var speedStartedAt: TimeInterval?
    private var speedIndex = 0
    private var lastPhase: ClawPhase = .idle
    private var audioCues: [(time: TimeInterval, file: String, volume: Float)] = []
    private var iconRevealAt: TimeInterval?
    private var finishAt: TimeInterval?
    private var didCueSessionStart = false
    private var didCueUnlock = false
    private var didBeginEntrance = false
    private var didCollapsePile = false
    private var lastCharacterID = "elephant"

    func attach(engine: ClawEngine, model: GameViewModel) {
        self.engine = engine
        self.model = model
        engine.trailerPrepareDeterministicSession()
        engine.trailerSpeedScale = 1
        model.onAnswerResolved = { [weak self] isCorrect, _ in
            self?.handleAnswer(isCorrect: isCorrect)
        }
        GameSettings.characterID = "elephant"
        characterID = "elephant"
        lastCharacterID = "elephant"
        audioCues.removeAll()
        iconRevealAt = nil
        finishAt = nil
        didBeginEntrance = false
        didCollapsePile = false
        didCueUnlock = false
    }

    var trailerAudioCues: [(time: TimeInterval, file: String, volume: Float)] {
        audioCues
    }

    func enableExternalClock() {
        engine?.trailerEnableExternalClock()
    }

    func stepSimulation(dt: Double) {
        engine?.trailerStep(dt: dt)
    }

    func resyncForRecordingStart() {
        guard let engine else { return }
        engine.trailerSpeedScale = 1
        engine.setInput(0)
        if !didBeginEntrance {
            parkForEntrance(engine)
        }
        if !didCueSessionStart {
            cueSFX("sfx_session_start", volume: 0.16, at: 0.04)
            didCueSessionStart = true
        }
        engine.objectWillChange.send()
    }

    func bootstrap() {
        guard let engine, let model else { return }
        parkForEntrance(engine)
        model.trailerInstall(round: session.rounds[0])
        engine.setLive(true)
        engine.setCharacter(CharacterCatalog.character(id: "elephant"))
        applyCharacter("elephant", flash: false)
        headlineOpacity = 0
        beat = .entrance
        beatAge = 0
        elapsed = 0
        completedGrabs = 0
        didPressForBeat = false
        speedIndex = 0
        speedStartedAt = nil
        didBeginEntrance = false
        didCollapsePile = false
        headerMaxY = engine.trailerHeaderMaxY
        panelMinY = engine.trailerPanelMinY
        print("PROMO_TRAILER_BOOTSTRAP trolley=\(String(format: "%.2f", engine.trailerTrolleyX)) size=\(Int(engine.trailerPlayfieldSize.width))x\(Int(engine.trailerPlayfieldSize.height))")
    }

    func tick(elapsed: TimeInterval) {
        let dt = max(0, elapsed - self.elapsed)
        self.elapsed = elapsed
        beatAge += dt
        guard let engine, let model else { return }

        headerMaxY = engine.trailerHeaderMaxY
        panelMinY = engine.trailerPanelMinY
        observePhase(engine)
        updateOverlays()
        updateClock(model: model, dt: dt)
        drive(engine: engine, model: model, dt: dt)
        updateIcon()
        themeFlash = max(0, themeFlash - dt * 3.2)

        if let finishAt, elapsed >= finishAt {
            isFinished = true
        }
        if elapsed >= PromoTrailerRuntime.maximumDuration {
            isFinished = true
        }
    }

    func handleLevelCompletionFinished() {
        guard iconRevealAt == nil else { return }
        iconRevealAt = elapsed
        finishAt = elapsed + PromoTrailerScript.iconHold
        print("PROMO_TRAILER_FINALE_DONE t=\(String(format: "%.2f", elapsed))")
    }

    // MARK: Drive

    private func drive(engine: ClawEngine, model: GameViewModel, dt: Double) {
        switch beat {
        case .entrance:
            engine.setInput(0)
            if !didBeginEntrance {
                engine.trailerBeginEntrance()
                didBeginEntrance = true
            }
            if engine.trailerHasLanded {
                enter(.hold)
            }

        case .hold:
            engine.setInput(0)
            if beatAge >= PromoTrailerScript.openingHold {
                enter(.moveRight)
                engine.setInput(1)
                cueSFX("sfx_move", volume: 0.24)
            }

        case .moveRight:
            engine.setInput(1)
            if engine.trailerTrolleyX >= engine.trailerTrolleyMaxX - 0.008 {
                engine.setInput(0)
                edgeDwellAge += dt
                if edgeDwellAge >= 0.28 {
                    enter(.moveLeft)
                    engine.setInput(-1)
                    cueSFX("sfx_move", volume: 0.24)
                }
            } else {
                edgeDwellAge = 0
            }

        case .moveLeft:
            engine.setInput(-1)
            if engine.trailerTrolleyX <= engine.trailerTrolleyMinX + 0.008 {
                engine.setInput(0)
                edgeDwellAge += dt
                if edgeDwellAge >= 0.28 {
                    enter(.returnCenter)
                }
            } else {
                edgeDwellAge = 0
            }

        case .returnCenter:
            if aim(engine, at: PromoTrailerScript.openingNutID) {
                alignedAge += dt
                if alignedAge >= 0.08 {
                    enter(.firstGrab)
                }
            } else {
                alignedAge = 0
            }

        case .firstGrab:
            engine.trailerReturnTargetX = engine.trailerNutTrolleyX(id: PromoTrailerScript.wrongNutID)
            recoverIdlePress(engine)
            if completedGrabs >= 1, engine.trailerPhase == .idle {
                applyCharacter("octopus")
                model.trailerInstall(round: session.rounds[1])
                enter(.unlockAlign)
                break
            }
            if aim(engine, at: PromoTrailerScript.openingNutID) {
                alignedAge += dt
                if alignedAge >= 0.06 {
                    tryGrab(engine, id: PromoTrailerScript.openingNutID)
                }
            } else {
                alignedAge = 0
            }

        case .unlockAlign:
            engine.trailerSpeedScale = 1
            applyCharacter("octopus", flash: characterID != "octopus")
            engine.trailerReturnTargetX = engine.trailerNutTrolleyX(id: PromoTrailerScript.wrongNutID)
            if aim(engine, at: PromoTrailerScript.wrongNutID) {
                alignedAge += dt
                if alignedAge >= 0.65 {
                    enter(.wrongGrab)
                }
            } else {
                alignedAge = 0
            }

        case .wrongGrab:
            engine.trailerReturnTargetX = engine.trailerNutTrolleyX(id: PromoTrailerScript.showcaseNutID)
            if engine.trailerIsHangingOverBin {
                applyCharacter("bear", flash: false)
            }
            if didPressForBeat, engine.trailerPhase == .idle {
                applyCharacter("bear", flash: false)
                enter(.correctGrab)
                break
            }
            if !didPressForBeat {
                applyCharacter("octopus", flash: false)
                if aim(engine, at: PromoTrailerScript.wrongNutID) {
                    alignedAge += dt
                    if alignedAge >= 0.06 {
                        tryGrab(engine, id: PromoTrailerScript.wrongNutID)
                    }
                } else {
                    alignedAge = 0
                }
            } else {
                engine.setInput(0)
            }

        case .correctGrab:
            engine.trailerReturnTargetX = engine.trailerNutTrolleyX(id: PromoTrailerScript.speedNutIDs[0])
            recoverIdlePress(engine)
            switch engine.trailerPhase {
            case .grabbing, .ascending, .carrying, .dropping, .returning:
                applyCharacter("lion", flash: false)
            case .idle:
                if completedGrabs >= 2 {
                    applyCharacter("elephant", flash: false)
                    collapseToSpeedPile(engine: engine, model: model)
                    enter(.speed)
                    break
                }
                applyCharacter("bear", flash: false)
                if aim(engine, at: PromoTrailerScript.showcaseNutID) {
                    alignedAge += dt
                    if alignedAge >= 0.06 {
                        tryGrab(engine, id: PromoTrailerScript.showcaseNutID)
                    }
                } else {
                    alignedAge = 0
                }
            default:
                engine.setInput(0)
                if characterID != "lion" {
                    applyCharacter("bear", flash: false)
                }
            }

        case .speed:
            applyCharacter("elephant", flash: false)
            if speedIndex == 0, beatAge < 0.36, engine.trailerPhase == .idle {
                engine.setInput(0)
                break
            }
            let ids = PromoTrailerScript.speedNutIDs
            engine.trailerSpeedScale = (speedIndex >= ids.count - 1)
                ? PromoTrailerScript.lastSpeedScale
                : PromoTrailerScript.speedScale
            guard speedIndex < ids.count else {
                engine.setInput(0)
                engine.trailerSpeedScale = PromoTrailerScript.finaleSpeedScale
                if engine.trailerPhase == .celebrating || playsLevelCompletion {
                    enter(.finale)
                }
                break
            }
            let current = ids[speedIndex]
            if speedIndex + 1 < ids.count {
                engine.trailerReturnTargetX = engine.trailerNutTrolleyX(id: ids[speedIndex + 1])
            } else {
                engine.trailerReturnTargetX = nil
            }
            recoverIdlePress(engine)
            if completedGrabs >= 2 + speedIndex + 1 {
                speedIndex += 1
                didPressForBeat = false
                alignedAge = 0
                if speedIndex < ids.count, speedIndex + 2 < session.rounds.count {
                    model.trailerInstall(round: session.rounds[speedIndex + 2])
                }
                break
            }
            if engine.trailerPhase == .idle {
                guard engine.trailerPileSettled else {
                    engine.setInput(0)
                    break
                }
                engine.trailerSnapOver(id: current)
                tryGrab(engine, id: current)
            } else {
                engine.setInput(0)
            }

        case .finale:
            engine.trailerSpeedScale = PromoTrailerScript.finaleSpeedScale
            engine.setInput(0)
            applyCharacter("elephant", flash: false)
            if !playsLevelCompletion, engine.trailerPhase == .celebrating {
                playsLevelCompletion = true
            }
            if iconRevealAt == nil, beatAge > 1.86 {
                handleLevelCompletionFinished()
            }
            if iconRevealAt != nil {
                enter(.icon)
            }

        case .icon:
            engine.setInput(0)
            engine.trailerSpeedScale = 1
            backgroundBlur = min(2.4, backgroundBlur + dt * 3.5)

        case .done:
            engine.setInput(0)
        }
    }

    private func tryGrab(_ engine: ClawEngine, id: UUID) {
        guard !didPressForBeat, engine.trailerIsReadyToGrab else { return }
        engine.setInput(0)
        engine.trailerPressGrab(id: id)
        didPressForBeat = true
        cueSFX("sfx_button_press", volume: 0.31)
    }

    private func recoverIdlePress(_ engine: ClawEngine) {
        guard didPressForBeat, engine.trailerPhase == .idle else { return }
        didPressForBeat = false
        alignedAge = 0
    }

    @discardableResult
    private func aim(_ engine: ClawEngine, at id: UUID) -> Bool {
        guard let target = engine.trailerNutTrolleyX(id: id) else {
            engine.setInput(0)
            return false
        }
        let dist = target - engine.trailerTrolleyX
        if abs(dist) <= 0.038 {
            engine.setInput(0)
            return true
        }
        let steer = min(1, max(-1, dist / 0.07))
        engine.setInput(steer)
        return false
    }

    private func parkForEntrance(_ engine: ClawEngine) {
        let x = engine.trailerNutTrolleyX(id: PromoTrailerScript.openingNutID) ?? 0.42
        engine.trailerParkForEntrance(x: x)
        engine.setInput(0)
    }

    private func collapseToSpeedPile(engine: ClawEngine, model: GameViewModel) {
        guard !didCollapsePile else { return }
        didCollapsePile = true
        engine.trailerCollapseToPyramid(keeping: PromoTrailerScript.speedNutIDs,
                                        positions: PromoTrailerScript.speedPyramid)
        model.trailerInstall(round: session.rounds[2])
        model.trailerSetClock(total: PromoTrailerScript.clockTotal,
                              remaining: PromoTrailerScript.speedClockRemaining)
        engine.trailerSpeedScale = PromoTrailerScript.speedScale
        speedStartedAt = elapsed
        speedIndex = 0
    }

    private func enter(_ next: Beat) {
        beat = next
        beatAge = 0
        didPressForBeat = false
        alignedAge = 0
        edgeDwellAge = 0
        print("PROMO_TRAILER_BEAT \(next) t=\(String(format: "%.2f", elapsed))")
    }

    // MARK: Phase / character / audio

    private func observePhase(_ engine: ClawEngine) {
        let phase = engine.trailerPhase
        if phase != lastPhase {
            switch phase {
            case .grabbing:
                cueSFX("sfx_take_nut", volume: 0.50)
                if beat == .correctGrab {
                    applyCharacter("lion", flash: false)
                }
            case .dropping:
                cueSFX("sfx_release_grip", volume: 0.07)
            case .carrying:
                if beat == .wrongGrab, engine.trailerIsHangingOverBin {
                    applyCharacter("bear", flash: false)
                }
            case .celebrating:
                engine.trailerSpeedScale = PromoTrailerScript.finaleSpeedScale
                if !playsLevelCompletion {
                    playsLevelCompletion = true
                    cueSFX("sfx_level_complete", volume: 0.10)
                }
            default:
                break
            }
            lastPhase = phase
        } else if beat == .wrongGrab, engine.trailerIsHangingOverBin {
            applyCharacter("bear", flash: false)
        }
    }

    private func handleAnswer(isCorrect: Bool) {
        if isCorrect {
            completedGrabs += 1
            cueSFX("sfx_correct", volume: 0.08)
            if completedGrabs >= session.rounds.count {
                model?.trailerForceLevelComplete()
            }
            print("PROMO_TRAILER_GRAB \(completedGrabs)/\(session.rounds.count) t=\(String(format: "%.2f", elapsed))")
        } else {
            cueSFX("sfx_wrong", volume: 0.10)
            print("PROMO_TRAILER_MISS t=\(String(format: "%.2f", elapsed))")
        }
    }

    private func applyCharacter(_ id: String, flash: Bool = true) {
        let changed = characterID != id
        characterID = id
        lastCharacterID = id
        GameSettings.characterID = id
        engine?.setCharacter(CharacterCatalog.character(id: id))
        if flash, changed, id == "octopus", !didCueUnlock {
            didCueUnlock = true
            themeFlash = 1
            cueSFX("sfx_character_unlock", volume: 0.16)
        } else if flash, changed, id != "elephant" {
            themeFlash = 1
        }
    }

    // MARK: Overlays / clock / icon

    private func updateOverlays() {
        switch beat {
        case .entrance:
            headlineText = PromoTrailerScript.instruction
            headlineOpacity = beatAge > 0.42 ? 1 : 0
        case .hold, .moveRight, .moveLeft, .returnCenter:
            headlineText = PromoTrailerScript.instruction
            headlineOpacity = 1
        case .firstGrab:
            headlineText = PromoTrailerScript.instruction
            headlineOpacity = didPressForBeat ? max(0, 1 - beatAge * 2.4) : 1
        case .unlockAlign, .wrongGrab, .correctGrab:
            headlineText = PromoTrailerScript.unlockHeadline
            headlineOpacity = 1
        case .speed:
            headlineText = PromoTrailerScript.speedHeadline
            headlineOpacity = playsLevelCompletion ? max(0, 1 - beatAge) : 1
        case .finale, .icon, .done:
            headlineOpacity = max(0, headlineOpacity - 0.08)
        }
    }

    private func updateClock(model: GameViewModel, dt: Double) {
        switch beat {
        case .entrance, .hold, .moveRight, .moveLeft, .returnCenter,
             .firstGrab, .unlockAlign, .wrongGrab, .correctGrab:
            model.trailerAdvanceClock(by: dt * 0.35)
        case .speed:
            let start = speedStartedAt ?? elapsed
            let remaining = max(0.55, PromoTrailerScript.speedClockRemaining - (elapsed - start))
            model.trailerSetClock(total: PromoTrailerScript.clockTotal, remaining: remaining)
        case .finale, .icon, .done:
            break
        }
    }

    private func updateIcon() {
        guard let iconRevealAt else { return }
        let local = max(0, elapsed - iconRevealAt)
        let t = min(1, local / PromoTrailerScript.iconSpinDuration)
        let eased = 1 - pow(1 - t, 3)
        iconOpacity = eased
        iconScale = 0.84 + 0.16 * CGFloat(eased)
        iconRotation = -16 * (1 - eased)
        if local >= PromoTrailerScript.iconHold - 0.02 {
            beat = .done
            isFinished = true
        }
    }

    private func cueSFX(_ file: String, volume: Float, at time: TimeInterval? = nil) {
        let at = time ?? elapsed
        audioCues.append((at, file, volume))
        print("PROMO_TRAILER_SFX \(file) t=\(String(format: "%.2f", at))")
    }
}
