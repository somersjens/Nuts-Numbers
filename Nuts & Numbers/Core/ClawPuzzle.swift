//
//  ClawPuzzle.swift
//  Nuts & Numbers
//
//  Builds one claw-machine level: the full sum list, the gold nuts, and a
//  physical pile that is guaranteed to stay solvable and finish empty.
//
//  The brick mound is built first. Each sum is then parked on a nut that is
//  already grabable at that point in the session — sometimes the peak, often
//  a half-free nut one or two rows down — so later shells can sit on top for
//  many rounds. Repeated answer values are spread apart where possible.
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
    /// The value printed on the shell. Any nut whose value matches the
    /// standing sum is a correct grab, even if it was laid for a later question.
    public let text: String
    /// 0-based index of the sum this nut was laid for. The optional shape is
    /// retained for save compatibility, although new piles contain no decoys.
    public let sequenceIndex: Int?
    public let isGold: Bool
    public var position: ClawPoint
    public var radius: Double
    /// Nuts whose shells rest on this one. Live grabability counts every
    /// overlapping shell above (`occluderCount`), not only this snapshot.
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
    /// The sums in the order they will be asked. Same length as the board.
    public let questions: [MathQuestion]
    public let nuts: [ClawNut]
    public let seed: UInt64

    /// The one nut assigned to question `index` (0-based). Decoys never appear.
    nonisolated public func assignedNut(forQuestionIndex index: Int) -> ClawNut? {
        nuts.first { $0.isAssigned(toQuestionIndex: index) }
    }

    /// Verifies the immutable question-to-nut plan by playing its complete
    /// removal order in memory. This is used before a saved plan is restored;
    /// the live playfield never needs to rewrite or relocate a printed answer.
    nonisolated public func isPlayablePlan(expectedCount: Int) -> Bool {
        guard questions.count == expectedCount,
              nuts.count >= expectedCount,
              Set(nuts.map(\.id)).count == nuts.count
        else { return false }

        var pile = nuts
        for (index, question) in questions.enumerated() {
            guard question.isValid(requiredDistractors: GameConfig.distractorCount),
                  let target = pile.first(where: { $0.isAssigned(toQuestionIndex: index) }),
                  AnswerValue(target.text) == AnswerValue(question.correctAnswer),
                  ClawPuzzle.isGrabable(target, among: pile)
            else { return false }
            ClawPuzzleBuilder.applyFall(&pile, removing: target)
        }
        return true
    }

    /// Nuts that still belong in the machine after `collected` correct answers.
    /// Earlier assigned nuts leave. Positions follow the same cascade as a live
    /// session, so a rebuilt playfield does not put later answers back under a
    /// stack that should already have slid. At the full count this returns an
    /// empty pile.
    nonisolated public func remainingNuts(afterCollected collected: Int) -> [ClawNut] {
        var pile = nuts
        for index in 0..<collected {
            guard let target = pile.first(where: { $0.isAssigned(toQuestionIndex: index) }) else {
                break
            }
            ClawPuzzleBuilder.applyFall(&pile, removing: target)
        }
        return pile
    }

    /// Whether `nut` can be grabbed given the nuts still sitting in the pile.
    ///
    /// Count every remaining shell that overlaps from above — the whole
    /// column, not only the row on top. Zero blockers is free; one blocker
    /// leaves it half-exposed (grab 18 while 15 still sits on it). Two or more
    /// — 24 under 19, 15 and 18 — is buried. Taking 19 drops that count for
    /// 15 and 18, and those can then be the standing answer.
    nonisolated public static func isGrabable(_ nut: ClawNut, among remaining: [ClawNut]) -> Bool {
        ClawPuzzleBuilder.occluderCount(on: nut, among: remaining) <= 1
    }

    /// Fully uncovered: nothing in the column above overlaps the shell.
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
            : spreadQuestions(questions, random: random)
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
        if !isSolvableWithCascade(nuts, answerCount: ordered.count) {
            nuts = placePeakFirst(answers: ordered,
                                  gold: gold,
                                  distractors: distractors,
                                  strategy: .strictPyramid,
                                  random: random)
            separateSimilarValues(&nuts)
            uniquifyPrintedValues(&nuts)
            refreshCovering(&nuts)
            repairGrabability(&nuts, answerCount: ordered.count)
            refreshCovering(&nuts)
        }
        let puzzle = ClawPuzzle(questions: ordered, nuts: nuts, seed: seed)
        assert(puzzle.isPlayablePlan(expectedCount: ordered.count),
               "Claw puzzle must be completely planned before play starts")
        return puzzle
    }

    // MARK: Ordering

    /// Mixes the sums so identical answers never sit next to each other in
    /// the order they are assigned onto grabable shells.
    nonisolated static func spreadQuestions(_ questions: [MathQuestion],
                                            random: RandomSource) -> [MathQuestion] {
        var remaining = random.shuffled(questions)
        guard remaining.count > 1 else { return remaining }
        var ordered: [MathQuestion] = []
        while !remaining.isEmpty {
            let last = ordered.last.map { AnswerValue($0.correctAnswer) }
            if let index = remaining.firstIndex(where: { AnswerValue($0.correctAnswer) != last }) {
                ordered.append(remaining.remove(at: index))
            } else {
                ordered.append(remaining.removeFirst())
            }
        }
        return ordered
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
        var sim = nuts
        // A small exercise can have fewer distinct results than the board has
        // shells (for example a table has twelve). Repeats are then inevitable,
        // but a later copy should preferably stay buried while an earlier copy
        // is the standing answer. Remember every shell that was already exposed
        // during that value's question and avoid assigning the next copy there.
        var exposedSlotsByAnswer: [AnswerValue: Set<UUID>] = [:]
        for (index, question) in answers.enumerated() {
            let grabable = sim.filter { ClawPuzzle.isGrabable($0, among: sim) }
            let printed = AnswerValue(question.correctAnswer)
            let previouslyExposed = exposedSlotsByAnswer[printed] ?? []
            let newlyExposed = grabable.filter { !previouslyExposed.contains($0.id) }
            let candidates = newlyExposed.isEmpty ? grabable : newlyExposed
            let already = nuts.filter { $0.sequenceIndex != nil && value(of: $0) == printed }
            let far = candidates.filter { candidate in
                !already.contains { closeTogether($0, candidate) }
            }
            let pool = far.isEmpty ? candidates : far
            let chosen = pickAnswerSlot(pool, pile: sim, random: random) ?? random.element(pool)
            guard let chosen, ClawPuzzle.isGrabable(chosen, among: sim) else { break }
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
    /// Assigned shells keep their printed answer even when several sums share
    /// it; decoys that would collide are rewritten.
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

    /// Nuts anywhere above `nut` whose shells overlap it in x — the column
    /// the claw would have to reach through, not just the immediate sitters
    /// used for the cascade.
    static func occludes(upper: ClawNut, lower: ClawNut) -> Bool {
        let radius = min(upper.radius, lower.radius)
        let dy = lower.position.y - upper.position.y
        guard dy > radius * 0.7 else { return false }
        // Packed ovals overlap a full diameter away (adjacent columns). The
        // old 0.62 cutoff only saw valley neighbours at 0.5 diameter, so a 32
        // under both 16 and 12 counted as half-free.
        return abs(upper.position.x - lower.position.x) < (upper.radius + lower.radius) * 1.08
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

    /// Walks the whole session: each assigned nut must be at least half-free
    /// when it is asked, then the cascade is applied before the next sum.
    static func isSolvableWithCascade(_ nuts: [ClawNut], answerCount: Int) -> Bool {
        var pile = nuts
        for index in 0..<answerCount {
            guard let target = pile.first(where: { $0.isAssigned(toQuestionIndex: index) }) else {
                return false
            }
            if !ClawPuzzle.isGrabable(target, among: pile) { return false }
            applyFall(&pile, removing: target)
        }
        return true
    }

    static func repairGrabability(_ nuts: inout [ClawNut], answerCount: Int) {
        for _ in 0..<24 {
            guard !isSolvableWithCascade(nuts, answerCount: answerCount) else { return }
            guard let (index, target, pile) = firstUngrabable(in: nuts, answerCount: answerCount)
            else { return }
            let partners = pile.filter { nut in
                guard nut.id != target.id else { return false }
                guard ClawPuzzle.isGrabable(nut, among: pile) else { return false }
                if nut.isDistractor { return true }
                return (nut.sequenceIndex ?? -1) > index
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

    /// Simulated pile at the first question whose assigned nut is not at least
    /// half-free, after earlier answers have been taken and the cascade applied.
    static func firstUngrabable(in nuts: [ClawNut],
                                answerCount: Int) -> (index: Int, target: ClawNut, pile: [ClawNut])? {
        var pile = nuts
        for index in 0..<answerCount {
            guard let target = pile.first(where: { $0.isAssigned(toQuestionIndex: index) }) else {
                return nil
            }
            if !ClawPuzzle.isGrabable(target, among: pile) {
                return (index, target, pile)
            }
            applyFall(&pile, removing: target)
        }
        return nil
    }

    static func covers(upper: ClawNut, lower: ClawNut) -> Bool {
        sitsOn(upper: upper, hole: lower.position, holeRadius: lower.radius)
    }
}
