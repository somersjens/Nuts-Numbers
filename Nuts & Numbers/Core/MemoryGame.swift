//
//  MemoryGame.swift
//  Elephant Challenge: Math Memory
//
//  The session state machine. Every rule that decides what a tap does lives
//  here, and every transition is guarded by the current state — that is what
//  makes double taps and double scoring impossible.
//
//  This type is deliberately free of SwiftUI and of timers: the view drives it
//  with explicit calls and asks it what to show. That keeps it fully testable.
//
//  The reef scene uses the same state machine: it opens a round straight
//  through `turnCardsOver` and `beginAnswering` — there is nothing to memorise
//  under water — and then hands over whichever answer bubble the fish touched.
//

import Foundation

// MARK: - State

nonisolated public enum GameState: String, Equatable, Sendable {
    /// Session created, nothing shown yet.
    case intro
    /// The answer cards lie face up: this is the memorising beat. The question
    /// is still hidden, and a tap turns the cards over.
    case memorising
    /// The cards are mid-flip: they are turning face down while the question
    /// comes up. No input is accepted during the turn.
    case questionVisible
    /// The cards are face down and the question is readable. Exactly one tap
    /// is accepted — the player must remember where the answer was.
    case answering
    /// An answer was taken: feedback is showing, input is locked.
    case resolving
    /// Feedback finished; the next round can be installed.
    case roundComplete
    /// The clock expired, the board was completed, or the player left.
    case gameOver
}

nonisolated public enum GameOverReason: String, Equatable, Sendable {
    case outOfTime
    case roundsCompleted
    case quit
}

/// What resolving a tap produced, so the view knows which feedback to play.
nonisolated public enum AnswerOutcome: Equatable, Sendable {
    case correct(cardsEarned: Int)
    case wrong(correctOptionID: UUID)
    /// The tap was ignored (wrong state, or the round was already answered).
    case ignored
}

// MARK: - Result

nonisolated public struct SessionResult: Equatable, Sendable {
    public var correctAnswers = 0
    public var wrongAnswers = 0
    public var cardsEarned = 0
    /// Kept for paused-session compatibility. New play never awards extra nuts.
    public var bonusCards = 0
    /// Kept for paused-session compatibility. New play never doubles a nut.
    public var doubleCardsAnswered = 0
    public var isNewPersonalBest = false
    public var previousPersonalBest = 0
    public var unlockedCharacterIDs: [String] = []
    public var reason: GameOverReason = .roundsCompleted

    public init() {}
}

// MARK: - Engine

nonisolated public final class MemoryGame {
    // MARK: Configuration

    public let level: MathLevel
    /// Which scoreboard this session plays on, so a paused run can only ever be
    /// resumed onto the exact board it came from.
    public let board: LevelBoard
    public let puzzleSeed: UInt64
    private let factory: RoundFactory
    /// Every sum this board will ask, built before the first nut is shown.
    private var plannedRounds: [GameRound] = []
    /// The physical pile that belongs to `plannedRounds`. Nil only before start.
    public private(set) var clawPuzzle: ClawPuzzle?
    /// Shells already collected, in the order the player took them. Needed so
    /// a later copy of 40 that was grabbed still stays gone after the pile
    /// is rebuilt for the next sum.
    public private(set) var collectedNutIDs: [UUID] = []
    /// Puzzle-question indices not yet answered, including the standing sum.
    private var remainingQuestionIndices: [Int] = []
    /// Which puzzle question is currently on the plaque.
    private var standingQuestionIndex: Int?

    // MARK: Observable state (read by the view)

    public private(set) var state: GameState = .intro
    public private(set) var round: GameRound?
    /// The round after this one, built ahead of time so a transition never
    /// waits on generation.
    private var preparedRound: GameRound?

    public private(set) var roundNumber = 0
    public private(set) var cards = 0
    /// The option the player tapped this round, if any.
    public private(set) var selectedOptionID: UUID?
    public private(set) var lastOutcome: AnswerOutcome?
    public private(set) var result = SessionResult()
    public private(set) var correctStreak = 0

    /// Set once the session is over; nil while playing.
    public private(set) var gameOverReason: GameOverReason?

    /// A wrong answer leaves the sum standing. Only a correct answer moves the
    /// session on to the next sum, so the clock is the mistake's only cost.
    private var repeatsRound = false
    /// Trailer-only cap so a 7-nut teaser can complete without a 45-nut board.
    private var trailerRoundCap: Int?

    // MARK: Derived

    /// Number of physical answer nuts on this board. The session visits every
    /// one of these rounds so the machine is empty when the level completes.
    public var maximumRounds: Int { trailerRoundCap ?? board.maximum }

    /// Whether a tap on an answer card can be accepted right now.
    public var acceptsInput: Bool { state == .answering }
    public var isStreakBoostActive: Bool { false }

    /// Whether the answer values are readable. They are during the memorising
    /// beat, and again while the round resolves so the player can see what they
    /// picked and where the right card was.
    public var showsAnswerValues: Bool {
        state == .memorising || state == .resolving || state == .roundComplete
    }

    /// Whether the question is readable. It appears only once the cards are
    /// face down, which is what makes this a memory game.
    public var showsQuestion: Bool {
        state != .intro && state != .memorising
    }

    // MARK: Init

    public init(level: MathLevel,
                mixedVariant: MixedVariant = .all,
                mode: PracticeMode = .mixed,
                seed: UInt64? = nil) {
        self.level = level
        self.board = LevelBoard(level: level,
                                mixedVariant: mixedVariant,
                                mode: mode)
        let resolvedSeed = seed ?? UInt64.random(in: 1...UInt64.max)
        self.puzzleSeed = resolvedSeed
        self.factory = RoundFactory(level: level,
                                    mixedVariant: mixedVariant,
                                    mode: board.mode,
                                    seed: resolvedSeed)
    }

    // MARK: - Session lifecycle

    /// Starts the session and deals the first round's answer cards face up.
    @discardableResult
    public func start() -> Bool {
        guard state == .intro else { return false }
        installPlan(startingAt: 1)
        state = .memorising
        return true
    }

    /// Resumes a level the player left part-way through, restoring the cards and
    /// round they stopped on. Rejected if the record is not playable.
    @discardableResult
    public func resume(from session: PausedSession) -> Bool {
        guard state == .intro, session.isResumable else { return false }
        roundNumber = session.roundNumber
        cards = session.cards
        result.correctAnswers = session.correctAnswers
        result.wrongAnswers = session.wrongAnswers
        result.doubleCardsAnswered = session.doubleCardsAnswered
        result.bonusCards = session.bonusCards
        result.cardsEarned = session.cards
        correctStreak = session.correctStreak ?? 0
        installPlan(startingAt: session.roundNumber,
                    restoring: session.puzzle,
                    collectedIDs: session.collectedNutIDs,
                    remainingIndices: session.remainingQuestionIndices,
                    standingIndex: session.standingQuestionIndex)
        state = .memorising
        return true
    }

    /// A snapshot of the session as it stands, for storing when the player
    /// leaves. Nil once the session is over — there is nothing to come back to.
    public func pausedSession(remainingTime: Double? = nil) -> PausedSession? {
        guard state != .intro, state != .gameOver else { return nil }
        return PausedSession(boardID: board.storageID,
                             roundNumber: roundNumber,
                             cards: cards,
                             correctAnswers: result.correctAnswers,
                             wrongAnswers: result.wrongAnswers,
                             doubleCardsAnswered: result.doubleCardsAnswered,
                             bonusCards: result.bonusCards,
                             // Legacy field: the helper it counted is gone.
                             flamethrowersUsed: 0,
                             correctStreak: correctStreak,
                             remainingTime: remainingTime,
                             puzzleSeed: puzzleSeed,
                             puzzle: clawPuzzle,
                             collectedNutIDs: collectedNutIDs,
                             remainingQuestionIndices: remainingQuestionIndices,
                             standingQuestionIndex: standingQuestionIndex)
    }

    /// The tap that turns the answer cards face down and brings the question
    /// up. From here on the player is working from memory.
    @discardableResult
    public func turnCardsOver() -> Bool {
        guard state == .memorising else { return false }
        state = .questionVisible
        return true
    }

    /// Called once the cards have finished turning. From here the round accepts
    /// exactly one answer.
    @discardableResult
    public func beginAnswering() -> Bool {
        guard state == .questionVisible else { return false }
        state = .answering
        return true
    }

    // MARK: - Answering

    /// Resolves a tap on an answer card. Any tap that arrives in the wrong
    /// state — a second tap on the same round, a tap during feedback, a tap on
    /// a burned card — is ignored without touching the score.
    @discardableResult
    public func select(optionID: UUID) -> AnswerOutcome {
        guard state == .answering,
              let round,
              selectedOptionID == nil,
              let option = round.options.first(where: { $0.id == optionID })
        else {
            // Deliberately leaves `lastOutcome` alone: an ignored tap must not
            // disturb the feedback the view is currently showing.
            return .ignored
        }
        return resolveAnswer(isCorrect: option.isCorrect,
                             selectedID: optionID,
                             correctOptionID: round.correctOption?.id ?? optionID)
    }

    /// Resolves a grabbed nut against the standing sum. A matching printed
    /// number is correct. The standing sum was chosen because that number is
    /// already grabable, so the digits on the shells never have to move.
    @discardableResult
    public func resolveGrab(nut: ClawNut) -> AnswerOutcome {
        guard state == .answering,
              let round,
              selectedOptionID == nil
        else { return .ignored }
        let isCorrect = AnswerValue(nut.text) == AnswerValue(round.question.correctAnswer)
        if isCorrect {
            collectedNutIDs.append(nut.id)
        }
        let selectedID = isCorrect
            ? (round.targetNutID ?? round.correctOption?.id ?? nut.id)
            : nut.id
        return resolveAnswer(isCorrect: isCorrect,
                             selectedID: selectedID,
                             correctOptionID: round.targetNutID ?? round.correctOption?.id ?? selectedID)
    }

    /// Ends the session because the clock ran out. Safe to call from any live
    /// state, including mid-grab: input is already locked by the view.
    public func expireTime() {
        guard state != .gameOver else { return }
        finish(reason: .outOfTime)
    }

    // MARK: - Round transitions

    /// Called by the view when the feedback animation has finished.
    @discardableResult
    public func finishResolving() -> Bool {
        guard state == .resolving else { return false }
        state = .roundComplete
        return true
    }

    /// Installs the next round, puts the current one back into play after a
    /// wrong answer, or ends the session. Returns the new state.
    @discardableResult
    public func advance() -> GameState {
        guard state == .roundComplete else { return state }

        // A missed answer does not use up a round: the same sum comes straight
        // back while the clock continues to run.
        if repeatsRound {
            repeatsRound = false
            selectedOptionID = nil
            lastOutcome = nil
            state = .answering
            return state
        }
        if roundNumber >= maximumRounds {
            finish(reason: .roundsCompleted)
            return state
        }

        if let standing = standingQuestionIndex {
            remainingQuestionIndices.removeAll { $0 == standing }
        }
        roundNumber += 1
        presentNextAvailableQuestion()
        preparedRound = nil
        selectedOptionID = nil
        lastOutcome = nil
        state = .memorising
        return state
    }

    /// Ends the session early (the player left the game screen).
    public func quit() {
        guard state != .gameOver else { return }
        finish(reason: .quit)
    }

    // MARK: - Private

    /// Builds the full sum list and the matching nut pile once, so a level
    /// never sprouts new answers after the first frame. The next sum is then
    /// chosen from remaining questions whose answer is already grabable.
    nonisolated private func installPlan(startingAt number: Int,
                                         restoring savedPuzzle: ClawPuzzle? = nil,
                                         collectedIDs: [UUID]? = nil,
                                         remainingIndices: [Int]? = nil,
                                         standingIndex: Int? = nil) {
        let puzzle: ClawPuzzle
        if let savedPuzzle, isValidPlan(savedPuzzle) {
            puzzle = savedPuzzle
        } else {
            factory.reset()
            let generated = factory.makeSession(count: board.maximum)
            puzzle = ClawPuzzle.build(
                questions: generated.map(\.question),
                seed: puzzleSeed,
                preservesQuestionOrder: board.mode == .order
            )
        }
        clawPuzzle = puzzle
        trailerRoundCap = nil
        plannedRounds = puzzle.questions.enumerated().map { index, question in
            factory.makeRound(number: index + 1,
                              question: question,
                              targetNutID: puzzle.assignedNut(forQuestionIndex: index)?.id)
        }
        let start = min(max(1, number), max(1, plannedRounds.count))
        if let collectedIDs {
            collectedNutIDs = collectedIDs
        } else {
            collectedNutIDs = (0..<max(0, start - 1)).compactMap { index in
                puzzle.assignedNut(forQuestionIndex: index)?.id
            }
        }
        let fallbackRemaining = Array((start - 1)..<puzzle.questions.count)
        if let remainingIndices {
            let restored = remainingIndices.filter { puzzle.questions.indices.contains($0) }
            remainingQuestionIndices = restored.isEmpty ? fallbackRemaining : restored
        } else {
            remainingQuestionIndices = fallbackRemaining
        }
        roundNumber = start
        if let standingIndex,
           remainingQuestionIndices.contains(standingIndex) {
            presentQuestion(standingIndex)
        } else {
            presentNextAvailableQuestion()
        }
        preparedRound = nil
    }

    /// Picks the next standing sum from remaining questions whose answer is
    /// currently grabable. Reeks keeps the earliest available teaching step;
    /// Random and Mixed draw uniformly from the free answers.
    private func presentNextAvailableQuestion() {
        if trailerRoundCap != nil {
            round = plannedRound(number: roundNumber)
            standingQuestionIndex = round.flatMap { current in
                clawPuzzle?.questions.firstIndex { $0 == current.question }
            }
            return
        }
        guard let puzzle = clawPuzzle else {
            round = plannedRound(number: roundNumber)
            return
        }
        let pile = puzzle.remainingNuts(afterGrabbing: collectedNutIDs)
        let random = RandomSource(seed: puzzleSeed &+ UInt64(collectedNutIDs.count) &+ 0x51E4_A11A)
        let index = ClawPuzzle.chooseAvailableQuestion(
            remainingIndices: remainingQuestionIndices,
            questions: puzzle.questions,
            pile: pile,
            prefersEarliest: board.mode == .order,
            random: random
        )
        guard let index else {
            round = nil
            standingQuestionIndex = nil
            return
        }
        presentQuestion(index)
    }

    private func presentQuestion(_ index: Int) {
        guard let puzzle = clawPuzzle,
              puzzle.questions.indices.contains(index)
        else { return }
        standingQuestionIndex = index
        let pile = puzzle.remainingNuts(afterGrabbing: collectedNutIDs)
        let target = ClawPuzzle.grabableTarget(
            matching: AnswerValue(puzzle.questions[index].correctAnswer),
            in: pile
        )
        round = factory.makeRound(number: roundNumber,
                                  question: puzzle.questions[index],
                                  targetNutID: target?.id)
    }

    /// A persisted plan is accepted only when it still describes this exact
    /// board and every question owns one matching, uniquely identified nut.
    /// Invalid or legacy data falls back to deterministic seed regeneration.
    nonisolated private func isValidPlan(_ puzzle: ClawPuzzle) -> Bool {
        guard puzzle.seed == puzzleSeed,
              puzzle.isPlayablePlan(expectedCount: board.maximum)
        else { return false }
        return true
    }

    private func plannedRound(number: Int) -> GameRound? {
        guard number >= 1, number <= plannedRounds.count else { return nil }
        return plannedRounds[number - 1]
    }

    private func resolveAnswer(isCorrect: Bool,
                               selectedID: UUID,
                               correctOptionID: UUID) -> AnswerOutcome {
        // Lock input for the whole of the resolve phase, before any scoring.
        selectedOptionID = selectedID
        state = .resolving

        let outcome: AnswerOutcome
        if isCorrect {
            let earned = GameConfig.normalCardReward
            cards += earned
            result.correctAnswers += 1
            result.cardsEarned += earned
            correctStreak += 1
            outcome = .correct(cardsEarned: earned)
        } else {
            result.wrongAnswers += 1
            correctStreak = 0
            // The sum stays standing; `advance` puts this very round back
            // into play instead of installing the next one.
            repeatsRound = true
            outcome = .wrong(correctOptionID: correctOptionID)
        }
        lastOutcome = outcome
        return outcome
    }

    private func finish(reason: GameOverReason) {
        gameOverReason = reason
        result.reason = reason
        state = .gameOver
    }

    /// Fills in the persistence-derived parts of the result. Called by the view
    /// model once the score has been recorded, so the engine itself stays free
    /// of storage concerns.
    public func applyProgressOutcome(previousBest: Int,
                                     isNewPersonalBest: Bool,
                                     unlockedCharacterIDs: [String]) {
        result.previousPersonalBest = previousBest
        result.isNewPersonalBest = isNewPersonalBest
        result.unlockedCharacterIDs = unlockedCharacterIDs
    }

    // MARK: - Promo trailer

    /// Replaces the live round with a scripted one. Used only by the App Store
    /// teaser so every math beat is readable and deterministic.
    public func trailerInstall(round: GameRound) {
        self.round = round
        roundNumber = max(1, round.number)
        standingQuestionIndex = clawPuzzle.flatMap { puzzle in
            puzzle.questions.firstIndex { $0 == round.question }
        }
        selectedOptionID = nil
        lastOutcome = nil
        repeatsRound = false
        if state == .intro {
            state = .memorising
        }
        if state == .memorising || state == .questionVisible || state == .resolving
            || state == .roundComplete {
            state = .answering
        }
    }

    /// Replaces the factory pile with a scripted teaser session.
    public func trailerInstallSession(puzzle: ClawPuzzle, rounds: [GameRound]) {
        clawPuzzle = puzzle
        plannedRounds = rounds
        trailerRoundCap = max(1, rounds.count)
        remainingQuestionIndices = Array(puzzle.questions.indices)
        standingQuestionIndex = rounds.first.flatMap { first in
            puzzle.questions.firstIndex { $0 == first.question }
        }
        collectedNutIDs = []
        cards = 0
        result = SessionResult()
        correctStreak = 0
        selectedOptionID = nil
        lastOutcome = nil
        repeatsRound = false
        roundNumber = 1
        round = rounds.first
        preparedRound = rounds.dropFirst().first
        state = .answering
    }

    /// After a trailer answer resolves, stay on the current scripted sum so the
    /// director can swap the next beat without a factory round sneaking in.
    public func trailerResumeAnswering() {
        selectedOptionID = nil
        lastOutcome = nil
        repeatsRound = false
        if state == .resolving || state == .roundComplete {
            state = .answering
        }
    }

    /// Seeds the in-level streak so the next correct answer can cross the
    /// golden threshold on cue. Clamped to a valid pre-boost count.
    public func trailerSeedCorrectStreak(_ value: Int) {
        correctStreak = max(0, min(value, GameConfig.streakThreshold - 1))
    }

    /// Ends the board so the real success-curl path can run after the final
    /// teaser answer, without inventing a parallel finale.
    public func trailerForceLevelComplete() {
        guard state != .gameOver else { return }
        cards = max(cards, maximumRounds)
        finish(reason: .roundsCompleted)
    }
}
