//
//  GameViewModel.swift
//  Elephant Challenge: Math Memory
//
//  The bridge between the pure `MemoryGame` engine and SwiftUI. It owns the
//  timing of a round (sum → answers → feedback → next sum), the audio and
//  haptics, and the persistence of a finished session.
//
//  It never re-implements a rule: every tap is forwarded to the engine, and the
//  engine's answer decides what happens. That is what keeps rapid tapping from
//  scoring twice.
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Owns the on-screen countdown so a 10 Hz tick does not invalidate `GameView`.
/// `@ObservedObject` on the session model rebuilds the whole reef on every
/// published change; isolating the clock keeps that cost on the small badge.
@MainActor
final class GameClock: ObservableObject {
    @Published private(set) var remaining: Double = 0
    @Published private(set) var total: Double = 1

    func configure(total: Double, remaining: Double) {
        self.total = max(1, total)
        self.remaining = remaining
    }

    func advance(by dt: Double) {
        remaining = max(0, remaining - dt)
    }

    func expire() {
        remaining = 0
    }
}

@MainActor
final class GameViewModel: ObservableObject {
    private let request: GameSessionRequest
    private var engine: MemoryGame

    /// `MemoryGame` is built on a worker and then transferred exactly once to
    /// the main actor. It is never read on both executors at the same time.
    private struct PreparedEngine: @unchecked Sendable {
        let engine: MemoryGame
        let pausedSession: PausedSession?
    }
    private var preparationTask: Task<PreparedEngine, Never>?

    // Published mirrors of the engine, so SwiftUI observes value changes.
    @Published private(set) var state: GameState = .intro
    @Published private(set) var round: GameRound?
    @Published private(set) var roundNumber = 0
    @Published private(set) var cards = 0
    @Published private(set) var selectedOptionID: UUID?
    @Published private(set) var isGameOver = false
    @Published private(set) var result = SessionResult()
    @Published private(set) var correctStreak = 0
    @Published private(set) var isStreakBoostActive = false
    /// Changes each time the streak boost starts, allowing the view to replay
    /// its bubble-style announcement even after an earlier streak was broken.
    @Published private(set) var streakAnnouncementID = 0
    @Published private(set) var clawPuzzle: ClawPuzzle?
    @Published private(set) var collectedNutIDs: [UUID] = []
    let clock = GameClock()

    /// Set by the tutorial, which needs to know about every answer the moment
    /// the engine accepts it — that is what moves its script on.
    var onAnswerResolved: ((_ isCorrect: Bool, _ startedStreak: Bool) -> Void)?

    /// Invalidates pending timed work when a round is superseded (restart, or
    /// leaving the screen), so a late callback can never touch a newer round.
    private var generation = 0
    private var hasRecordedResult = false
    private var isPaused = false
    /// The walkthrough teaches every control before spending any of the
    /// player's level time. This hold is independent from the pause card: the
    /// machine remains interactive while the countdown stays still.
    private var isTutorialClockPaused = false
    /// A round-resolution callback that became due while the pause card was
    /// covering the reef. It runs once on continue instead of behind the card.
    private var pendingScheduledWork: (() -> Void)?
    /// The rules award cards immediately, while the HUD waits until the
    /// matching currency nut physically reaches it.
    private var pendingScoreRewards: [Int] = []
    private var clockTimer: Timer?

    var maximumRounds: Int { engine.maximumRounds }
    var acceptsInput: Bool { state == .answering && !isPaused }
    var remainingTime: Double { clock.remaining }
    var timeLimit: Double { clock.total }

    init(request: GameSessionRequest) {
        self.request = request
        self.engine = MemoryGame(level: request.level,
                            mixedVariant: request.mixedVariant,
                            mode: request.mode)
        let limit = Double(request.board.maximum) * GameConfig.clawSecondsPerCard
        clock.configure(total: limit, remaining: limit)
    }

    // MARK: - Lifecycle

    /// Builds the first two rounds while the level card (and then the fish
    /// entrance) is still on screen. Round generation is pure CPU work and
    /// does not belong on the frame that responds to Start.
    func prepare() {
        if PromoTrailerRuntime.isActive { return }
        guard engine.state == .intro, preparationTask == nil else { return }
        let paused = PausedSessionStore.shared.session(request.board)
        startPreparation(pausedSession: paused)
        Task { [weak self] in
            guard let self, let prepared = await self.preparationTask?.value else { return }
            guard self.engine.state == .intro else { return }
            // Publish the restored progress before publishing the pile. The
            // playfield derives its remaining nuts from this number; doing it
            // in the opposite order briefly rendered the complete pile and
            // then made the already-collected nuts disappear on Continue.
            self.roundNumber = prepared.engine.roundNumber
            self.clawPuzzle = prepared.engine.clawPuzzle
            self.configureTimer(from: prepared.pausedSession)
        }
    }

    private func startPreparation(pausedSession: PausedSession?) {
        guard preparationTask == nil else { return }
        let level = request.level
        let mixedVariant = request.mixedVariant
        let mode = request.mode
        let seed = pausedSession?.puzzleSeed
        preparationTask = Task.detached(priority: .userInitiated) {
            let prepared = MemoryGame(level: level,
                                      mixedVariant: mixedVariant,
                                      mode: mode,
                                      seed: seed)
            if let pausedSession {
                prepared.resume(from: pausedSession)
            } else {
                prepared.start()
            }
            return PreparedEngine(engine: prepared, pausedSession: pausedSession)
        }
    }

    /// Starts the level, resuming a paused session when one is waiting.
    func begin() async {
        if PromoTrailerRuntime.isActive {
            isPaused = false
            isTutorialClockPaused = true
            trailerOwnsRounds = true
            let session = PromoTrailerScript.session()
            engine.trailerInstallSession(puzzle: session.puzzle, rounds: session.rounds)
            clock.configure(total: PromoTrailerScript.clockTotal,
                            remaining: PromoTrailerScript.clockStart)
            sync()
            return
        }
        guard engine.state == .intro else { return }
        let token = generation
        prepare()
        guard let prepared = await preparationTask?.value,
              generation == token,
              engine.state == .intro else { return }
        engine = prepared.engine
        preparationTask = nil
        isPaused = false
        configureTimer(from: prepared.pausedSession)
        startClock()
        prepareHaptics()
        PlaytimeTracker.shared.challengeStarted()
        AppAudio.shared.setGameplayActive(true, questionText: nil)
        AppAudio.shared.playSessionStart()
        openRound()
        announceRound()
        sync()
    }

    /// Opens a round for play. Under water there is nothing to memorise: the
    /// sum stands on the coral from the first frame, so the round goes straight
    /// through to accepting an answer.
    private func openRound() {
        engine.turnCardsOver()
        engine.beginAnswering()
    }

    private func announceRound() {
        AppAudio.shared.playCardReveal()
        if let prompt = engine.round?.question.prompt {
            AppAudio.shared.speakQuestion(prompt)
        }
    }

    func end() {
        if !PromoTrailerRuntime.isActive {
            savePausedSessionIfNeeded()
            recordResultIfNeeded()
        }
        PlaytimeTracker.shared.challengeEnded()
        AppAudio.shared.setGameplayActive(false, questionText: nil)
        AppAudio.shared.setGameplayRate(1)
        stopClock()
        generation &+= 1
        preparationTask?.cancel()
        preparationTask = nil
        pendingScheduledWork = nil
        pendingScoreRewards.removeAll()
    }

    /// Temporarily stops an active run without ending it. The snapshot also
    /// makes the same run available if the player chooses the main menu from
    /// the pause card instead of continuing immediately.
    func pause() {
        guard engine.state != .gameOver else { return }
        isPaused = true
        stopClock()
        savePausedSessionIfNeeded()
        PlaytimeTracker.shared.challengeEnded()
        AppAudio.shared.setGameplayActive(false, questionText: nil)
        AppAudio.shared.setGameplayRate(1)
    }

    /// Continues the in-memory run after its pause card. No round is rebuilt,
    /// so the player returns to the exact question, score and remaining time.
    func resume() {
        guard engine.state != .intro, engine.state != .gameOver else { return }
        isPaused = false
        startClock()
        prepareHaptics()
        PlaytimeTracker.shared.challengeStarted()
        AppAudio.shared.setGameplayActive(true, questionText: engine.round?.question.prompt)
        AppAudio.shared.setGameplayRate(1)
        let work = pendingScheduledWork
        pendingScheduledWork = nil
        work?()
    }

    /// The close button: the level is put on pause with its cards intact, and
    /// those cards are banked to the player's total straight away.
    func quit() {
        savePausedSessionIfNeeded()
        engine.quit()
        recordResultIfNeeded()
        sync()
    }

    /// Freezes the session for this level, so re-entering it continues from
    /// here. A finished session has nothing to store and clears the record.
    ///
    /// A run that has not banked a single card is not worth coming back to:
    /// storing it would only put a pause marker on the menu for a level the
    /// player would restart from zero anyway.
    private func savePausedSessionIfNeeded() {
        guard !hasRecordedResult,
              let paused = engine.pausedSession(remainingTime: remainingTime)
        else { return }
        guard paused.cards > 0 else {
            PausedSessionStore.shared.clear(request.board)
            return
        }
        PausedSessionStore.shared.save(paused)
    }

    /// Play again always starts a clean run, so any paused record for this
    /// level is spent.
    func restart() async {
        generation &+= 1
        let token = generation
        PausedSessionStore.shared.clear(request.board)
        // Normally this engine has already been built during the result
        // animation. If Play Again somehow wins that race, wait for the worker
        // instead of doing its remaining generation work on the tap frame.
        startPreparation(pausedSession: nil)
        guard let prepared = await preparationTask?.value,
              generation == token else { return }
        engine = prepared.engine
        preparationTask = nil
        hasRecordedResult = false
        isPaused = false
        isTutorialClockPaused = false
        pendingScheduledWork = nil
        pendingScoreRewards.removeAll()
        streakAnnouncementID = 0
        configureTimer(from: nil)
        startClock()
        AppAudio.shared.playSessionStart()
        openRound()
        announceRound()
        sync()
    }

    // MARK: - Round flow

    /// Forwards an answer bubble the fish touched. The engine decides whether
    /// it counts; a touch that arrives while feedback is still playing comes
    /// back as `.ignored` and changes nothing at all. The returned flag tells
    /// the reef whether to burst the bubble.
    @discardableResult
    func select(optionID: UUID) -> Bool {
        let outcome = engine.select(optionID: optionID)
        guard outcome != .ignored else { return false }
        // Every real interaction advances the playtime clock. Without these the
        // tracker only ever sees one gap from the first touch to the last,
        // which its idle limit then discards — a whole session counting as no
        // time.
        PlaytimeTracker.shared.registerInteraction()

        let token = generation
        let delay: Double
        switch outcome {
        case .correct(let cardsEarned):
            pendingScoreRewards.append(cardsEarned)
            sync()
            onAnswerResolved?(true, false)
            AppAudio.shared.playCorrect()
            haptic(.success)
            delay = GameConfig.nextRoundDelay.correct
        case .wrong:
            sync()
            onAnswerResolved?(false, false)
            AppAudio.shared.playWrong()
            haptic(.error)
            delay = GameConfig.nextRoundDelay.wrong
        case .ignored:
            return false
        }

        schedule(after: delay, token: token) { [weak self] in
            guard let self else { return }
            guard self.engine.finishResolving() else { return }
            if self.trailerOwnsRounds {
                // Director will install the next scripted round; stay answering
                // on the current sum so a factory question cannot leak in.
                self.engine.trailerResumeAnswering()
                self.sync()
                return
            }
            let previousRoundID = self.engine.round?.id
            self.engine.advance()
            if self.engine.state == .gameOver {
                self.finishSession()
            } else if self.engine.round?.id != previousRoundID {
                // A new sum is announced and opened. A wrong answer leaves the
                // same sum in place, and play simply resumes.
                self.announceRound()
                self.openRound()
            }
            self.sync()
        }
        return true
    }

    /// Forwards a nut the elephant dropped in the bin. Any shell with the
    /// standing sum's value scores one nut.
    @discardableResult
    func resolveGrab(nut: ClawNut) -> AnswerOutcome {
        let outcome = engine.resolveGrab(nut: nut)
        guard outcome != .ignored else { return .ignored }
        PlaytimeTracker.shared.registerInteraction()

        let token = generation
        let delay: Double
        switch outcome {
        case .correct(let cardsEarned):
            pendingScoreRewards.append(cardsEarned)
            sync()
            onAnswerResolved?(true, false)
            AppAudio.shared.playCorrect()
            haptic(.success)
            // The finale starts from the drop itself. Waiting the usual
            // next-round beat would punch a heavy game-over view update
            // into the middle of the travel to centre.
            delay = engine.roundNumber >= engine.maximumRounds
                ? 0
                : (trailerOwnsRounds ? 0 : GameConfig.nextRoundDelay.correct)
        case .wrong:
            sync()
            onAnswerResolved?(false, false)
            AppAudio.shared.playWrong()
            haptic(.error)
            delay = GameConfig.nextRoundDelay.wrong
        case .ignored:
            return .ignored
        }

        schedule(after: delay, token: token) { [weak self] in
            guard let self else { return }
            guard self.engine.finishResolving() else { return }
            if self.trailerOwnsRounds {
                self.engine.trailerResumeAnswering()
                self.sync()
                return
            }
            let previousRoundID = self.engine.round?.id
            self.engine.advance()
            if self.engine.state == .gameOver {
                self.finishSession()
            } else if self.engine.round?.id != previousRoundID {
                self.announceRound()
                self.openRound()
            }
            self.sync()
        }
        return outcome
    }

    /// Called by the reef at the exact frame a collected currency nut lands
    /// on the HUD icon.
    func scoreBubbleArrived() {
        guard !pendingScoreRewards.isEmpty else { return }
        cards += pendingScoreRewards.removeFirst()
        AppAudio.shared.playCardTotal()
        haptic(.light)
    }

    // MARK: - Tutorial

    /// Holds or releases only the countdown while tutorial gameplay remains
    /// interactive. Releasing after the final five-second clock explanation is
    /// the single point at which a taught level begins spending time.
    func setTutorialClockPaused(_ paused: Bool, resumeClock: Bool = true) {
        guard isTutorialClockPaused != paused else { return }
        isTutorialClockPaused = paused
        if paused {
            stopClock()
        } else if resumeClock,
                  !isPaused,
                  engine.state != .intro,
                  engine.state != .gameOver {
            startClock()
        }
    }

    // MARK: - Finishing

    private func finishSession() {
        AppAudio.shared.setGameplayRate(1)
        stopClock()
        recordResultIfNeeded()
        // Hide replay generation under the reef finale/result card too.
        if !PromoTrailerRuntime.isActive {
            startPreparation(pausedSession: nil)
        }
    }

    /// Writes the session to disk exactly once, whichever way the screen is
    /// left: game over, the close button, or a swipe away.
    private func recordResultIfNeeded() {
        guard engine.state == .gameOver, !hasRecordedResult else { return }
        hasRecordedResult = true
        if PromoTrailerRuntime.isActive {
            result = engine.result
            return
        }
        // A level that reached its end is finished, not paused.
        if engine.gameOverReason != .quit {
            PausedSessionStore.shared.clear(request.board)
        }

        let store = Progress.store
        let previousTotal = store.totalCards
        let board = request.board
        // Only the improvement on this board joins the player's total. A board
        // can therefore contribute its maximum once, even though subsequent
        // maximum runs still count toward the separate ×N completion badge.
        let previousBest = store.bestScore(board)
        let gained = max(0, min(engine.cards, board.maximum) - previousBest)
        let newTotal = store.addCards(gained)
        // The score belongs to the board this session was played on: the card
        // count, and on Supermix the combination, keep separate bests.
        let best = store.recordScore(engine.cards, board: board)
        let unlocked = CharacterUnlocks.newlyUnlocked(from: previousTotal, to: newTotal)

        // Reaching this board's maximum is tallied every time, which is what
        // the ×N badge on a completed card counts.
        let maximum = board.maximum
        if engine.cards >= maximum {
            store.recordMaxCompletion(board)
        }

        engine.applyProgressOutcome(previousBest: best.previousBest,
                                    isNewPersonalBest: best.isNewBest,
                                    unlockedCharacterIDs: unlocked)

        ReviewRequestCoordinator.shared.recordCompletedGame(
            isNewHighScore: best.isNewBest,
            score: engine.cards,
            maximumScore: maximum
        )

        // Leaving a level part-way through is not an achievement: the pause
        // button banks the cards quietly, with no end-of-session fanfare.
        if engine.gameOverReason != .quit {
            if best.isNewBest && engine.cards > 0 { AppAudio.shared.playHighScore() }
            else { AppAudio.shared.playSessionComplete() }
        }
        result = engine.result
    }

    // MARK: - Plumbing

    /// Copies the engine's state onto the published properties in one pass, so
    /// a single tap causes exactly one SwiftUI update rather than eight.
    private func sync() {
        state = engine.state
        round = engine.round
        roundNumber = engine.roundNumber
        if pendingScoreRewards.isEmpty { cards = engine.cards }
        selectedOptionID = engine.selectedOptionID
        // Publish the completed result before the game-over flag. GameView
        // uses its reason to decide whether to play the reef finale first.
        if engine.state == .gameOver { result = engine.result }
        isGameOver = engine.state == .gameOver
        correctStreak = engine.correctStreak
        isStreakBoostActive = engine.isStreakBoostActive
        clawPuzzle = engine.clawPuzzle
        collectedNutIDs = engine.collectedNutIDs
        AppAudio.shared.setGameplayRate(1)
    }

    // MARK: - Clock

    private func configureTimer(from session: PausedSession?) {
        let limit = Double(request.board.maximum) * GameConfig.clawSecondsPerCard
        clock.configure(total: limit, remaining: session?.remainingTime ?? limit)
    }

    private func startClock() {
        stopClock()
        guard !isTutorialClockPaused else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickClock() }
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    private func tickClock() {
        guard !isPaused,
              !isTutorialClockPaused,
              engine.state != .intro,
              engine.state != .gameOver else { return }
        clock.advance(by: 0.1)
        if clock.remaining <= 0 {
            clock.expire()
            engine.expireTime()
            finishSession()
            sync()
        }
    }

    // MARK: - Promo trailer

    /// When true, a correct/wrong answer does not auto-advance into a factory
    /// round — the promo director owns every math beat via `trailerInstall`.
    private var trailerOwnsRounds = false

    func trailerInstall(round: GameRound) {
        engine.trailerInstall(round: round)
        trailerOwnsRounds = true
        sync()
    }

    func trailerSetClock(total: Double, remaining: Double) {
        clock.configure(total: total, remaining: remaining)
    }

    func trailerAdvanceClock(by dt: Double) {
        clock.advance(by: dt)
    }

    func trailerSeedCorrectStreak(_ value: Int) {
        engine.trailerSeedCorrectStreak(value)
        sync()
    }

    func trailerForceLevelComplete() {
        trailerOwnsRounds = false
        engine.trailerForceLevelComplete()
        finishSession()
        sync()
    }

    /// Runs `work` after a delay, unless the session moved on in the meantime.
    private func schedule(after delay: Double, token: Int, work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == token else { return }
            guard !self.isPaused else {
                self.pendingScheduledWork = work
                return
            }
            work()
        }
    }

    private enum Haptic { case light, rigid, success, error }

#if canImport(UIKit)
    // Built once and kept warm. A generator created on the spot has to wake the
    // Taptic Engine from idle on the calling thread, and that landed on the
    // exact main-thread frame in which an answer was taken.
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationHaptic = UINotificationFeedbackGenerator()
#endif

    /// Puts the Taptic Engine on standby while nothing is happening yet, so the
    /// first answer of a round pays no start-up cost either.
    private func prepareHaptics() {
#if canImport(UIKit)
        lightHaptic.prepare()
        rigidHaptic.prepare()
        notificationHaptic.prepare()
#endif
    }

    private func haptic(_ kind: Haptic) {
#if canImport(UIKit)
        switch kind {
        case .light: lightHaptic.impactOccurred()
        case .rigid: rigidHaptic.impactOccurred()
        case .success: notificationHaptic.notificationOccurred(.success)
        case .error: notificationHaptic.notificationOccurred(.error)
        }
        // Firing leaves the engine idle again; this keeps the *next* answer,
        // which in fast play is only a moment away, just as immediate.
        prepareHaptics()
#endif
    }
}
