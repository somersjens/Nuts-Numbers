//
//  ClawPuzzle.swift
//  Nuts & Numbers
//
//  Builds one claw-machine level: the full sum list, the gold nuts, and a
//  physical pile that is guaranteed to stay solvable and finish empty.
//
//  The brick mound is built first and every sum is printed onto a nut before
//  play starts. Those printed numbers never move. The next sum is chosen from
//  the remaining questions whose answer is already grabable on the pile, so a
//  buried 49 simply waits until 7×7 is asked — 7×6 is asked instead while 42
//  sits on top. With no decoys the peak is always a remaining answer, so a
//  playable sum is always available.
//

import Foundation

// MARK: - Points

/// Unit-space point inside the pile rectangle. (0, 0) is the top-left of the
/// nut bed, (1, 1) the bottom-right. Kept free of SwiftUI so generation can
/// run on a worker.
nonisolated public struct ClawPoint: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - Nut

nonisolated public struct ClawNut: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    /// The value printed on the shell. Fixed at generation: play picks a sum
    /// that this number can already answer, rather than rewriting the shell.
    public let text: String
    /// 0-based index of the sum this nut was laid for. The optional shape is
    /// retained for save compatibility, although new piles contain no decoys.
    public let sequenceIndex: Int?
    public let isGold: Bool
    public var position: ClawPoint
    public var radius: Double
    /// Nuts whose shells rest on this one. Live grabability recalculates those
    /// direct sitters after every cascade instead of trusting this snapshot.
    public var coveredBy: [UUID]

    public var isDistractor: Bool { sequenceIndex == nil }

    /// Whether this is the unique shell the player must collect for `index`.
    public func isAssigned(toQuestionIndex index: Int) -> Bool {
        sequenceIndex == index
    }

    public init(id: UUID = UUID(),
                text: String,
                sequenceIndex: Int?,
                isGold: Bool,
                position: ClawPoint,
                radius: Double,
                coveredBy: [UUID] = []) {
        self.id = id
        self.text = text
        self.sequenceIndex = sequenceIndex
        self.isGold = isGold
        self.position = position
        self.radius = radius
        self.coveredBy = coveredBy
    }
}

// MARK: - Puzzle

nonisolated public struct ClawPuzzle: Equatable, Codable, Sendable {
    /// The predetermined sums for this board. Play asks whichever remaining
    /// question already has a grabable matching shell, so this list is the
    /// set of sums rather than the live ask sequence.
    public let questions: [MathQuestion]
    public let nuts: [ClawNut]
    public let seed: UInt64

    /// The one nut assigned to question `index` (0-based). Decoys never appear.
    nonisolated public func assignedNut(forQuestionIndex index: Int) -> ClawNut? {
        nuts.first { $0.isAssigned(toQuestionIndex: index) }
    }

    /// Verifies that from the opening mound a remaining answer is always
    /// grabable, so play can keep choosing a sum from the free shells until
    /// the pile is empty. Printed labels are never rewritten.
    nonisolated public func isPlayablePlan(expectedCount: Int) -> Bool {
        guard questions.count == expectedCount,
              nuts.count >= expectedCount,
              Set(nuts.map(\.id)).count == nuts.count
        else { return false }

        for question in questions {
            guard question.isValid(requiredDistractors: GameConfig.distractorCount) else {
                return false
            }
        }

        var remaining = Set(questions.indices)
        var pile = nuts
        while !remaining.isEmpty {
            guard let index = ClawPuzzle.chooseAvailableQuestion(
                remainingIndices: remaining.sorted(),
                questions: questions,
                pile: pile,
                prefersEarliest: true,
                random: nil
            ),
                  let target = ClawPuzzle.grabableTarget(
                    matching: AnswerValue(questions[index].correctAnswer),
                    in: pile
                  )
            else { return false }
            remaining.remove(index)
            ClawPuzzleBuilder.applyFall(&pile, removing: target)
        }
        return true
    }

    /// Nuts that still belong in the machine after `collected` correct answers.
    /// Legacy resume path: peels assigned nuts in generation order. New play
    /// uses `remainingNuts(afterGrabbing:)` so the live grab order is kept.
    nonisolated public func remainingNuts(afterCollected collected: Int) -> [ClawNut] {
        var pile = nuts
        let count = min(max(0, collected), questions.count)
        for index in 0..<count {
            guard let target = pile.first(where: { $0.isAssigned(toQuestionIndex: index) }) else {
                break
            }
            ClawPuzzleBuilder.applyFall(&pile, removing: target)
        }
        return pile
    }

    /// Replays the grabs the player actually made. Printed numbers stay on the
    /// shells they were generated with; only positions cascade.
    nonisolated public func remainingNuts(afterGrabbing ids: [UUID]) -> [ClawNut] {
        var pile = nuts
        for id in ids {
            guard let target = pile.first(where: { $0.id == id }) else { break }
            ClawPuzzleBuilder.applyFall(&pile, removing: target)
        }
        return pile
    }

    /// Remaining questions whose correct answer currently sits on a grabable
    /// shell. Reeks prefers the earliest of those; Random and Mixed pick one.
    nonisolated public static func chooseAvailableQuestion(remainingIndices: [Int],
                                                           questions: [MathQuestion],
                                                           pile: [ClawNut],
                                                           prefersEarliest: Bool,
                                                           random: RandomSource?) -> Int? {
        let grabable = pile.filter { isGrabable($0, among: pile) }
        let available = remainingIndices.filter { index in
            guard questions.indices.contains(index) else { return false }
            let answer = AnswerValue(questions[index].correctAnswer)
            return grabable.contains { AnswerValue($0.text) == answer }
        }
        if prefersEarliest {
            return available.min()
        }
        return random?.element(available) ?? available.first
    }

    /// A grabable shell that currently prints `answer`, preferring the highest
    /// free nut so the claw has a clear target.
    nonisolated public static func grabableTarget(matching answer: AnswerValue,
                                                  in pile: [ClawNut]) -> ClawNut? {
        pile.filter { isGrabable($0, among: pile) && AnswerValue($0.text) == answer }
            .min { lhs, rhs in
                if lhs.position.y != rhs.position.y { return lhs.position.y < rhs.position.y }
                return lhs.position.x < rhs.position.x
            }
    }

    /// Whether `nut` can be grabbed given the nuts still sitting in the pile.
    ///
    /// Count only shells that actually rest on this nut. Zero blockers is
    /// fully free; one sitter leaves half of the shell exposed and therefore
    /// grabable. The row number is deliberately irrelevant: an edge nut can
    /// stay half exposed even when it sits many rows below the peak.
    nonisolated public static func isGrabable(_ nut: ClawNut, among remaining: [ClawNut]) -> Bool {
        ClawPuzzleBuilder.occluderCount(on: nut, among: remaining) <= 1
    }

    /// Fully uncovered: no remaining shell rests directly on this one.
    nonisolated public static func isReachable(_ nut: ClawNut, among remaining: [ClawNut]) -> Bool {
        ClawPuzzleBuilder.occluderCount(on: nut, among: remaining) == 0
    }

    /// One nut sliding into a vacated pocket after a grab.
    nonisolated public struct Fall: Equatable, Sendable {
        public let id: UUID
        public let from: ClawPoint
        public let to: ClawPoint
    }

    /// Nuts that rest on `removed` drop into its pocket, then the hole
    /// bubbles up. Used so a buried grab still leaves a packed mound.
    nonisolated public static func fallChain(removing removed: ClawNut,
                                             among remaining: [ClawNut]) -> [Fall] {
        ClawPuzzleBuilder.fallChain(removing: removed, among: remaining)
    }

    /// Builds a full level from an already-generated sum list. Random and Mixed
    /// sessions may spread their questions for a better pile; Reeks keeps the
    /// generator's exact teaching sequence.
    nonisolated public static func build(questions: [MathQuestion],
                                         seed: UInt64,
                                         preservesQuestionOrder: Bool = false) -> ClawPuzzle {
        ClawPuzzleBuilder.build(questions: questions,
                                seed: seed,
                                preservesQuestionOrder: preservesQuestionOrder)
    }
}

// MARK: - Builder
//
// The target uses default MainActor isolation. This builder is explicitly
// nonisolated so `MemoryGame` can generate a pile on a worker without actor
// hops — every helper lives here so none of them inherit MainActor.

nonisolated private enum ClawPuzzleBuilder {
    enum LayoutStrategy: CaseIterable {
        case centerMountain
        case leftSlope
        case rightSlope
        case twinPiles
        case wideMound
        case cascade
        case strictPyramid
    }

    nonisolated static func build(questions: [MathQuestion],
                                  seed: UInt64,
                                  preservesQuestionOrder: Bool) -> ClawPuzzle {
        let random = RandomSource(seed: seed &+ 0xC1A0_9A75)
        let ordered = preservesQuestionOrder
            ? questions
            : peelSchedule(questions, random: random)
        let gold = goldIndices(count: ordered.count, random: random)
        let distractors = makeDistractors(for: ordered, random: random)
        let strategy = LayoutStrategy.allCases[
            random.int(in: 0...(LayoutStrategy.allCases.count - 1))
        ]

        var nuts = place(answers: ordered,
                         gold: gold,
                         distractors: distractors,
                         strategy: strategy,
                         random: random)
        uniquifyPrintedValues(&nuts)
        refreshCovering(&nuts)
        repairGrabability(&nuts, answerCount: ordered.count)
        refreshCovering(&nuts)
        buryGrabableDuplicates(&nuts)
        refreshCovering(&nuts)
        repairGrabability(&nuts, answerCount: ordered.count)
        refreshCovering(&nuts)
        if !isSolvableWithCascade(nuts, answerCount: ordered.count) {
            nuts = placePeakFirst(answers: ordered,
                                  gold: gold,
                                  distractors: distractors,
                                  strategy: .strictPyramid,
                                  random: random)
            uniquifyPrintedValues(&nuts)
            refreshCovering(&nuts)
            repairGrabability(&nuts, answerCount: ordered.count)
            refreshCovering(&nuts)
        }
        var puzzle = ClawPuzzle(questions: ordered, nuts: nuts, seed: seed)
        if !puzzle.isPlayablePlan(expectedCount: ordered.count) {
            nuts = placePeakFirst(answers: ordered,
                                  gold: gold,
                                  distractors: distractors,
                                  strategy: .strictPyramid,
                                  random: random)
            uniquifyPrintedValues(&nuts)
            refreshCovering(&nuts)
            repairGrabability(&nuts, answerCount: ordered.count)
            refreshCovering(&nuts)
            puzzle = ClawPuzzle(questions: ordered, nuts: nuts, seed: seed)
        }
        assert(puzzle.isPlayablePlan(expectedCount: ordered.count),
               "Claw puzzle must be completely planned before play starts")
        return puzzle
    }

    // MARK: Ordering

    /// Unique printed answers first, then repeats. The first lap (5, 10, …, 60)
    /// is laid on the shells that are already free; a second 40 only appears
    /// after those peels, so the surface never shows two identical numbers at
    /// once and the next sum can be predicted from the peel order.
    nonisolated static func peelSchedule(_ questions: [MathQuestion],
                                         random: RandomSource) -> [MathQuestion] {
        var seen: Set<AnswerValue> = []
        var unique: [MathQuestion] = []
        var repeats: [MathQuestion] = []
        for question in questions {
            let printed = AnswerValue(question.correctAnswer)
            if seen.contains(printed) {
                repeats.append(question)
            } else {
                seen.insert(printed)
                unique.append(question)
            }
        }
        return random.shuffled(unique) + random.shuffled(repeats)
    }

    // MARK: Gold & distractors

    static func goldIndices(count: Int, random: RandomSource) -> Set<Int> {
        guard count > 0 else { return [] }
        let wanted = max(1, Int((Double(count) * GameConfig.clawGoldRatio).rounded()))
        let pool = count == 1 ? [0] : Array(1..<count)
        return Set(random.shuffled(pool).prefix(wanted))
    }

    static func makeDistractors(for questions: [MathQuestion],
                                random: RandomSource) -> [String] {
        let wanted = max(0, Int((Double(questions.count) * GameConfig.clawDistractorRatio).rounded()))
        guard wanted > 0 else { return [] }
        let forbidden = Set(questions.map { AnswerValue($0.correctAnswer) })
        var pool: [String] = []
        var seen = Set<AnswerValue>()

        for question in questions {
            for text in question.distractors {
                let value = AnswerValue(text)
                guard !forbidden.contains(value), !seen.contains(value) else { continue }
                seen.insert(value)
                pool.append(text)
            }
        }

        var extras: [String] = []
        if pool.count < wanted {
            let magnitudes = questions.compactMap { Int($0.correctAnswer) }
            let center = magnitudes.sorted().dropFirst(magnitudes.count / 3).first ?? 12
            var offset = 1
            while extras.count + pool.count < wanted, offset < 80 {
                for sign in [1, -1] {
                    let candidate = String(center + sign * offset)
                    let value = AnswerValue(candidate)
                    if !forbidden.contains(value), !seen.contains(value) {
                        seen.insert(value)
                        extras.append(candidate)
                    }
                    if extras.count + pool.count >= wanted { break }
                }
                offset += 1
            }
        }

        return Array(random.shuffled(pool + extras).prefix(wanted))
    }

    // MARK: Brick mound

    /// One resting place in the brick mound.
    struct Slot {
        var position: ClawPoint
        var radius: Double
        var row: Int
    }

    static func place(answers: [MathQuestion],
                      gold: Set<Int>,
                      distractors: [String],
                      strategy: LayoutStrategy,
                      random: RandomSource) -> [ClawNut] {
        let total = answers.count + distractors.count
        let slots = hexSlots(count: total, strategy: strategy, random: random)
        var nuts = slots.map { slot in
            ClawNut(text: "",
                    sequenceIndex: nil,
                    isGold: false,
                    position: slot.position,
                    radius: slot.radius)
        }
        assignAnswers(&nuts,
                      answers: answers,
                      gold: gold,
                      distractors: distractors,
                      random: random)
        return nuts
    }

    /// Emergency layout: early sums on the peak, later sums underneath.
    /// Only used if grabable-slot assignment somehow cannot finish a session.
    static func placePeakFirst(answers: [MathQuestion],
                               gold: Set<Int>,
                               distractors: [String],
                               strategy: LayoutStrategy,
                               random: RandomSource) -> [ClawNut] {
        let total = answers.count + distractors.count
        var slots = hexSlots(count: total, strategy: strategy, random: random)
        slots.sort { lhs, rhs in
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.position.x < rhs.position.x
        }
        for row in Set(slots.map(\.row)).sorted() {
            let indices = slots.indices.filter { slots[$0].row == row }
            var rowSlots = indices.map { slots[$0] }
            rowSlots = random.shuffled(rowSlots)
            for (offset, index) in indices.enumerated() {
                slots[index] = rowSlots[offset]
            }
        }

        var nuts: [ClawNut] = []
        for (index, answer) in answers.enumerated() {
            guard index < slots.count else { break }
            let slot = slots[index]
            nuts.append(ClawNut(text: answer.correctAnswer,
                                sequenceIndex: index,
                                isGold: gold.contains(index),
                                position: slot.position,
                                radius: slot.radius))
        }
        let remainingSlots = slots.dropFirst(answers.count)
        for (slot, text) in zip(remainingSlots, distractors) {
            nuts.append(ClawNut(text: text,
                                sequenceIndex: nil,
                                isGold: false,
                                position: slot.position,
                                radius: slot.radius))
        }
        return nuts
    }

    static func relabel(_ nut: ClawNut,
                        text: String,
                        sequenceIndex: Int?,
                        isGold: Bool) -> ClawNut {
        ClawNut(id: nut.id,
                text: text,
                sequenceIndex: sequenceIndex,
                isGold: isGold,
                position: nut.position,
                radius: nut.radius,
                coveredBy: nut.coveredBy)
    }

    static func assignAnswers(_ nuts: inout [ClawNut],
                              answers: [MathQuestion],
                              gold: Set<Int>,
                              distractors: [String],
                              random: RandomSource) {
        let startGrabableIDs = Set(nuts.filter { ClawPuzzle.isGrabable($0, among: nuts) }.map(\.id))
        var sim = nuts
        // A small exercise can have fewer distinct results than the board has
        // shells (for example a table has twelve). Repeats are then inevitable,
        // but a later copy must stay buried while an earlier copy is still the
        // standing answer — otherwise grabbing the "other 25" peels a different
        // column and the assigned shell is no longer free when it is needed.
        var exposedSlotsByAnswer: [AnswerValue: Set<UUID>] = [:]
        for (index, question) in answers.enumerated() {
            let grabable = sim.filter { ClawPuzzle.isGrabable($0, among: sim) }
            let printed = AnswerValue(question.correctAnswer)
            let isRepeat = answers.prefix(index).contains {
                AnswerValue($0.correctAnswer) == printed
            }
            let previouslyExposed = exposedSlotsByAnswer[printed] ?? []
            let newlyExposed = grabable.filter { !previouslyExposed.contains($0.id) }
            let buriedAtStart = grabable.filter { !startGrabableIDs.contains($0.id) }
            let surface = grabable.filter { startGrabableIDs.contains($0.id) }
            let candidates: [ClawNut]
            if isRepeat {
                // A second 40 may only sit where it was still buried at the
                // start, so taking the first 40 is the only peel that can
                // happen while 5×8 is standing.
                if !buriedAtStart.isEmpty {
                    candidates = buriedAtStart
                } else if !newlyExposed.isEmpty {
                    candidates = newlyExposed
                } else {
                    candidates = grabable
                }
            } else if !surface.isEmpty {
                candidates = surface
            } else {
                candidates = newlyExposed.isEmpty ? grabable : newlyExposed
            }
            let already = nuts.filter { $0.sequenceIndex != nil && value(of: $0) == printed }
            let far = candidates.filter { candidate in
                !already.contains { closeTogether($0, candidate) }
            }
            let pool = far.isEmpty ? candidates : far
            let chosen = pickAnswerSlot(pool, pile: sim, random: random)
                ?? random.element(pool)
                ?? random.element(grabable)
                ?? sim.first
            guard let chosen else { break }
            exposedSlotsByAnswer[printed, default: []]
                .formUnion(grabable.map(\.id))
            if let i = nuts.firstIndex(where: { $0.id == chosen.id }) {
                nuts[i] = relabel(nuts[i],
                                  text: question.correctAnswer,
                                  sequenceIndex: index,
                                  isGold: gold.contains(index))
            }
            if let live = sim.first(where: { $0.id == chosen.id }) {
                applyFall(&sim, removing: live)
            }
        }
        for (index, question) in answers.enumerated()
        where !nuts.contains(where: { $0.isAssigned(toQuestionIndex: index) }) {
            guard let i = nuts.firstIndex(where: { $0.sequenceIndex == nil }) else { break }
            nuts[i] = relabel(nuts[i],
                              text: question.correctAnswer,
                              sequenceIndex: index,
                              isGold: gold.contains(index))
        }
        var decoys = distractors
        for i in nuts.indices where nuts[i].sequenceIndex == nil {
            let text = decoys.isEmpty ? "0" : decoys.removeFirst()
            nuts[i] = relabel(nuts[i], text: text, sequenceIndex: nil, isGold: false)
        }
    }

    static func pickAnswerSlot(_ grabable: [ClawNut],
                               pile: [ClawNut],
                               random: RandomSource) -> ClawNut? {
        guard !grabable.isEmpty else { return nil }
        let free = grabable.filter { occluderCount(on: $0, among: pile) == 0 }
        let half = grabable.filter { occluderCount(on: $0, among: pile) == 1 }
        let roll = random.double(in: 0..<1)

        if !half.isEmpty, roll < 0.60 {
            let sorted = half.sorted { $0.position.y < $1.position.y }
            return random.weightedHardPick(sorted) ?? sorted.last
        }

        let peak = free.isEmpty ? grabable : free
        if peak.count > 1, roll < 0.84 {
            let ranked = peak
                .map { item -> (ClawNut, Double) in
                    (item, unlockScore(item, pile: pile))
                }
                .sorted { $0.1 < $1.1 }
                .map(\.0)
            return random.weightedHardPick(ranked) ?? ranked.last
        }
        return random.element(peak)
    }

    static func unlockScore(_ nut: ClawNut, pile: [ClawNut]) -> Double {
        let before = Set(pile.filter { ClawPuzzle.isGrabable($0, among: pile) }.map(\.id))
        var next = pile
        applyFall(&next, removing: nut)
        let unlocked = next.filter { candidate in
            !before.contains(candidate.id) && ClawPuzzle.isGrabable(candidate, among: next)
        }
        return unlocked.reduce(0) { score, opened in
            score + 1 + max(0, opened.position.y - nut.position.y) * 10
        }
    }

    /// Bottom row always spans the pile with this many walnuts. Odd rows nest
    /// in the valleys (5-4-5-4), so each nut sits exactly between the two below.
    static let floorColumns = 5
    /// Vertical gap between row centres, as a fraction of nut diameter. Tight
    /// enough that the oval shells rest in the valleys with contact.
    static let nestYFactor = 0.54

    static func hexSlots(count: Int,
                         strategy: LayoutStrategy,
                         random: RandomSource) -> [Slot] {
        _ = strategy
        _ = random
        return mound(count: count)
    }

    struct RowPlan {
        var length: Int
        var staggered: Bool
        var capacity: Int
    }

    /// Floor is 5, the row above is 4 in the valleys, then 5, then 4, …
    static func rowPlan(total: Int) -> [RowPlan] {
        var remaining = total
        var even = true
        var rows: [RowPlan] = []
        while remaining > 0 {
            let capacity = even ? floorColumns : floorColumns - 1
            let length = min(capacity, remaining)
            rows.append(RowPlan(length: length, staggered: !even, capacity: capacity))
            remaining -= length
            even.toggle()
        }
        return rows
    }

    static func mound(count: Int) -> [Slot] {
        guard count > 0 else { return [] }
        let radius = 0.5 / Double(floorColumns)
        let spacingX = radius * 2
        let rowsFromBottom = rowPlan(total: count)
        var spacingY = spacingX * nestYFactor
        let floor = 1 - radius
        if rowsFromBottom.count > 1 {
            let maxRise = max(0.12, floor - radius - 0.04)
            let fitted = maxRise / Double(rowsFromBottom.count - 1)
            spacingY = min(spacingY, max(spacingX * 0.50, fitted))
        }
        let originX = radius
        let topRow = max(rowsFromBottom.count - 1, 0)

        var slots: [Slot] = []
        for (rowFromBottom, row) in rowsFromBottom.enumerated() {
            let y = floor - Double(rowFromBottom) * spacingY
            let start = (row.capacity - row.length) / 2
            for column in 0..<row.length {
                let gridColumn = start + column
                let x = originX
                    + (row.staggered ? spacingX * 0.5 : 0)
                    + Double(gridColumn) * spacingX
                slots.append(Slot(position: ClawPoint(x: x, y: y),
                                  radius: radius,
                                  row: topRow - rowFromBottom))
            }
        }
        return slots
    }

    // MARK: Unique exposed values

    static func value(of nut: ClawNut) -> AnswerValue {
        AnswerValue(nut.text)
    }

    static func distance(_ a: ClawNut, _ b: ClawNut) -> Double {
        hypot(a.position.x - b.position.x, a.position.y - b.position.y)
    }

    /// Neighbours in the mound: same pocket, covering each other, or sitting
    /// in the hex cells beside one another.
    static func closeTogether(_ a: ClawNut, _ b: ClawNut) -> Bool {
        guard a.id != b.id else { return false }
        if covers(upper: a, lower: b) || covers(upper: b, lower: a) { return true }
        let reach = (a.radius + b.radius) * 1.12
        return abs(a.position.x - b.position.x) < reach
            && abs(a.position.y - b.position.y) < reach * 1.65
    }

    static func sameRow(_ a: ClawNut, _ b: ClawNut) -> Bool {
        abs(a.position.y - b.position.y) < min(a.radius, b.radius) * 0.45
    }

    static func swapPositions(_ nuts: inout [ClawNut], _ i: Int, _ j: Int) {
        guard i != j else { return }
        let position = nuts[i].position
        let radius = nuts[i].radius
        nuts[i].position = nuts[j].position
        nuts[i].radius = nuts[j].radius
        nuts[j].position = position
        nuts[j].radius = radius
    }

    /// Pulls identical printed values apart so they never sit on top of each
    /// other in the pile. Swaps stay in the same row so the brick stack — and
    /// the peel order — stay intact.
    static func separateSimilarValues(_ nuts: inout [ClawNut]) {
        for _ in 0..<28 {
            var moved = false
            for i in nuts.indices {
                for j in nuts.indices where j > i {
                    guard value(of: nuts[i]) == value(of: nuts[j]),
                          closeTogether(nuts[i], nuts[j]) else { continue }
                    let match = value(of: nuts[i])
                    let movable = (nuts[i].sequenceIndex ?? Int.max)
                        > (nuts[j].sequenceIndex ?? Int.max) ? i : j
                    let other = movable == i ? j : i
                    let candidates = nuts.indices.filter { k in
                        k != i && k != j
                            && sameRow(nuts[k], nuts[movable])
                            && value(of: nuts[k]) != match
                            && !closeTogether(nuts[other], nuts[k])
                    }
                    guard let k = candidates.max(by: {
                        distance(nuts[other], nuts[$0]) < distance(nuts[other], nuts[$1])
                    }) else { continue }
                    swapPositions(&nuts, movable, k)
                    moved = true
                }
            }
            if !moved { break }
        }
    }

    /// Distractors never reprint a value that an assigned nut already shows.
    /// Assigned shells keep their printed answer even when a later sum shares
    /// it; that later copy is buried instead of rewritten.
    static func uniquifyPrintedValues(_ nuts: inout [ClawNut]) {
        var seen: Set<AnswerValue> = []
        var next = 1
        func uniqueExtra() -> String {
            while true {
                let candidate = String(next)
                next += 1
                let value = AnswerValue(candidate)
                if !seen.contains(value) {
                    seen.insert(value)
                    return candidate
                }
            }
        }
        for nut in nuts where !nut.isDistractor {
            seen.insert(value(of: nut))
        }
        for i in nuts.indices where nuts[i].isDistractor {
            let printed = value(of: nuts[i])
            if seen.contains(printed) {
                nuts[i] = ClawNut(id: nuts[i].id,
                                  text: uniqueExtra(),
                                  sequenceIndex: nuts[i].sequenceIndex,
                                  isGold: nuts[i].isGold,
                                  position: nuts[i].position,
                                  radius: nuts[i].radius,
                                  coveredBy: nuts[i].coveredBy)
            } else {
                seen.insert(printed)
            }
        }
    }

    /// True when `upper` rests in a valley of `hole` — the row immediately
    /// above, not two rows up. In the 5-4 brick, an interior nut has two
    /// sitters (buried) and an edge nut has one (half free, still grabable).
    static func sitsOn(upper: ClawNut, hole: ClawPoint, holeRadius: Double) -> Bool {
        let radius = min(upper.radius, holeRadius)
        let dy = hole.y - upper.position.y
        guard dy > radius * 0.35, dy < radius * 1.7 else { return false }
        return abs(upper.position.x - hole.x) < (upper.radius + holeRadius) * 0.62
    }

    static func fallChain(removing removed: ClawNut, among remaining: [ClawNut]) -> [ClawPuzzle.Fall] {
        var positions: [UUID: ClawPoint] = [:]
        var byID: [UUID: ClawNut] = [:]
        for nut in remaining where nut.id != removed.id {
            positions[nut.id] = nut.position
            byID[nut.id] = nut
        }
        var hole = removed.position
        let holeRadius = removed.radius
        var chain: [ClawPuzzle.Fall] = []
        var moved: Set<UUID> = []

        while true {
            let sitters = byID.values.filter { nut in
                guard !moved.contains(nut.id), let at = positions[nut.id] else { return false }
                var probe = nut
                probe.position = at
                return sitsOn(upper: probe, hole: hole, holeRadius: holeRadius)
            }
            guard let next = sitters.min(by: { a, b in
                let pa = positions[a.id] ?? a.position
                let pb = positions[b.id] ?? b.position
                let dya = hole.y - pa.y
                let dyb = hole.y - pb.y
                if abs(dya - dyb) > 0.012 { return dya < dyb }
                let dxa = abs(pa.x - hole.x)
                let dxb = abs(pb.x - hole.x)
                if abs(dxa - dxb) > 0.012 { return dxa < dxb }
                return pa.x < pb.x
            }) else { break }

            let from = positions[next.id] ?? next.position
            chain.append(ClawPuzzle.Fall(id: next.id, from: from, to: hole))
            moved.insert(next.id)
            positions[next.id] = hole
            hole = from
        }
        return chain
    }

    // MARK: Covering

    static func refreshCovering(_ nuts: inout [ClawNut]) {
        for i in nuts.indices {
            var blockers: [UUID] = []
            let lower = nuts[i]
            for other in nuts where other.id != lower.id {
                if covers(upper: other, lower: lower) {
                    blockers.append(other.id)
                }
            }
            nuts[i].coveredBy = blockers
        }
    }

    /// A shell blocks a lower nut only while the two shells physically overlap.
    /// Counting every shell farther up the same x-column made half-visible edge
    /// nuts become ungrabable merely because the mound happened to be tall.
    static func occludes(upper: ClawNut, lower: ClawNut) -> Bool {
        sitsOn(upper: upper, hole: lower.position, holeRadius: lower.radius)
    }

    static func occluderCount(on nut: ClawNut, among remaining: [ClawNut]) -> Int {
        remaining.reduce(0) { count, other in
            guard other.id != nut.id else { return count }
            return occludes(upper: other, lower: nut) ? count + 1 : count
        }
    }

    static func applyFall(_ nuts: inout [ClawNut], removing removed: ClawNut) {
        let chain = fallChain(removing: removed, among: nuts)
        nuts.removeAll { $0.id == removed.id }
        for fall in chain {
            guard let i = nuts.firstIndex(where: { $0.id == fall.id }) else { continue }
            nuts[i].position = fall.to
        }
    }

    /// Later copies of a printed answer are buried when the mound still has
    /// an interior. This is best-effort: a last-row repeat may stay in the
    /// open rather than making the level unplayable.
    static func buryGrabableDuplicates(_ nuts: inout [ClawNut]) {
        for _ in 0..<40 {
            let grabable = nuts.filter { ClawPuzzle.isGrabable($0, among: nuts) }
            var firstID: [AnswerValue: UUID] = [:]
            var extra: ClawNut?
            for nut in grabable {
                let printed = value(of: nut)
                if let kept = firstID[printed],
                   let keptNut = nuts.first(where: { $0.id == kept }) {
                    let keepLater = (nut.sequenceIndex ?? Int.max)
                        < (keptNut.sequenceIndex ?? Int.max)
                    extra = keepLater ? keptNut : nut
                    if keepLater { firstID[printed] = nut.id }
                    break
                } else {
                    firstID[printed] = nut.id
                }
            }
            guard let extra else { break }
            let printed = value(of: extra)
            let partners = nuts.filter { candidate in
                candidate.id != extra.id
                    && !ClawPuzzle.isGrabable(candidate, among: nuts)
                    && value(of: candidate) != printed
            }
            guard let partner = partners.min(by: { a, b in
                if a.isDistractor != b.isDistractor { return a.isDistractor }
                return (a.sequenceIndex ?? Int.max) > (b.sequenceIndex ?? Int.max)
            }),
                  let extraSlot = nuts.firstIndex(where: { $0.id == extra.id }),
                  let partnerSlot = nuts.firstIndex(where: { $0.id == partner.id })
            else { break }
            swapPositions(&nuts, extraSlot, partnerSlot)
        }
    }

    /// True when every remaining answer nut can be taken by always grabbing a
    /// currently free remaining answer. Play order follows those free shells,
    /// so assigned index order does not have to be peelable.
    static func isSolvableWithCascade(_ nuts: [ClawNut], answerCount: Int) -> Bool {
        var pile = nuts
        for _ in 0..<answerCount {
            guard let target = pile.first(where: {
                !$0.isDistractor && ClawPuzzle.isGrabable($0, among: pile)
            }) else { return false }
            applyFall(&pile, removing: target)
        }
        return true
    }

    static func repairGrabability(_ nuts: inout [ClawNut], answerCount: Int) {
        for _ in 0..<48 {
            guard !isSolvableWithCascade(nuts, answerCount: answerCount) else { return }
            guard let (target, pile) = firstUngrabable(in: nuts, answerCount: answerCount)
            else { return }
            let partners = pile.filter { nut in
                nut.id != target.id && ClawPuzzle.isGrabable(nut, among: pile)
            }
            guard let partner = partners.min(by: { a, b in
                if a.isDistractor != b.isDistractor { return a.isDistractor }
                let freeA = ClawPuzzle.isReachable(a, among: pile)
                let freeB = ClawPuzzle.isReachable(b, among: pile)
                if freeA != freeB { return freeA }
                return a.position.y < b.position.y
            }),
                  let targetSlot = nuts.firstIndex(where: { $0.id == target.id }),
                  let partnerSlot = nuts.firstIndex(where: { $0.id == partner.id })
            else { return }
            swapPositions(&nuts, targetSlot, partnerSlot)
        }
    }

    /// Simulated pile at the first moment no remaining answer nut is grabable.
    static func firstUngrabable(in nuts: [ClawNut],
                                answerCount: Int) -> (target: ClawNut, pile: [ClawNut])? {
        var pile = nuts
        for _ in 0..<answerCount {
            if let target = pile.first(where: {
                !$0.isDistractor && ClawPuzzle.isGrabable($0, among: pile)
            }) {
                applyFall(&pile, removing: target)
                continue
            }
            guard let buried = pile.first(where: { !$0.isDistractor }) else { return nil }
            return (buried, pile)
        }
        return nil
    }

    static func covers(upper: ClawNut, lower: ClawNut) -> Bool {
        sitsOn(upper: upper, hole: lower.position, holeRadius: lower.radius)
    }
}
