//
//  ClawPuzzle.swift
//  Nuts & Numbers
//
//  Builds one claw-machine level: the full sum list, the extra decoy nuts,
//  the gold nuts, and a physical pile that is guaranteed to stay solvable.
//
//  Each sum is laid as one nut. Duplicate printed values are avoided, and
//  when they cannot be (a tiny answer space), copies are spread so the
//  reachable shells never show the same number twice. Grabbing any shell
//  whose value matches the standing sum is correct.
//

import Foundation

// MARK: - Points

/// Unit-space point inside the pile rectangle. (0, 0) is the top-left of the
/// nut bed, (1, 1) the bottom-right. Kept free of SwiftUI so generation can
/// run on a worker.
nonisolated public struct ClawPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - Nut

nonisolated public struct ClawNut: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// The value printed on the shell. Any nut whose value matches the
    /// standing sum is a correct grab, even if it was laid for a later question.
    public let text: String
    /// 0-based index of the sum this nut was laid for, or nil when it is a
    /// decoy. Used for stacking order and pause/resume, not as the only
    /// accepted grab.
    public let sequenceIndex: Int?
    public let isGold: Bool
    public var position: ClawPoint
    public var radius: Double
    /// Nuts whose shells rest on this one. A nut is reachable when every id
    /// still in the machine has left this list.
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

nonisolated public struct ClawPuzzle: Equatable, Sendable {
    /// The sums in the order they will be asked. Same length as the board.
    public let questions: [MathQuestion]
    public let nuts: [ClawNut]
    public let seed: UInt64

    /// The one nut assigned to question `index` (0-based). Decoys never appear.
    nonisolated public func assignedNut(forQuestionIndex index: Int) -> ClawNut? {
        nuts.first { $0.isAssigned(toQuestionIndex: index) }
    }

    /// Nuts that still belong in the machine after `collected` correct answers.
    /// Earlier assigned nuts leave; decoys stay until the level ends.
    nonisolated public func remainingNuts(afterCollected collected: Int) -> [ClawNut] {
        nuts.filter { nut in
            guard let index = nut.sequenceIndex else { return true }
            return index >= collected
        }
    }

    /// Whether `nut` can be grabbed given the nuts still sitting in the pile.
    nonisolated public static func isReachable(_ nut: ClawNut, among remaining: [ClawNut]) -> Bool {
        let present = Set(remaining.map(\.id))
        return nut.coveredBy.allSatisfy { !present.contains($0) }
    }

    /// Builds a full level from an already-generated sum list. The returned
    /// `questions` may be reordered so similar sums sit near each other.
    nonisolated public static func build(questions: [MathQuestion], seed: UInt64) -> ClawPuzzle {
        ClawPuzzleBuilder.build(questions: questions, seed: seed)
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

    nonisolated static func build(questions: [MathQuestion], seed: UInt64) -> ClawPuzzle {
        let random = RandomSource(seed: seed &+ 0xC1A0_9A75)
        let ordered = spreadQuestions(questions, random: random)
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
        separateSimilarValues(&nuts)
        refreshCovering(&nuts)
        diversifyReachableValues(&nuts)
        refreshCovering(&nuts)
        if !isSolvable(nuts, answerCount: ordered.count) {
            nuts = place(answers: ordered,
                         gold: gold,
                         distractors: distractors,
                         strategy: .strictPyramid,
                         random: random)
            separateSimilarValues(&nuts)
            refreshCovering(&nuts)
            repairSolvability(&nuts, answerCount: ordered.count)
            diversifyReachableValues(&nuts)
            refreshCovering(&nuts)
        }
        return ClawPuzzle(questions: ordered, nuts: nuts, seed: seed)
    }

    // MARK: Ordering

    /// Mixes the sums so identical answers never sit next to each other in
    /// the sequence that is then dropped peak-first into the mound.
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
        let wanted = max(1, Int((Double(questions.count) * GameConfig.clawDistractorRatio).rounded()))
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

    // MARK: Hex pyramid

    /// One resting place in the mound, ordered from the peak down so the first
    /// sum can sit on top and later answers stay buried until they are needed.
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
        var slots = hexSlots(count: total, strategy: strategy, random: random)
        // Peak first: row 0 is the top of the mound.
        slots.sort { lhs, rhs in
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.position.x < rhs.position.x
        }
        for row in Set(slots.map(\.row)) {
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
                                position: jitter(slot.position, radius: slot.radius, random: random),
                                radius: slot.radius))
        }
        let remainingSlots = slots.dropFirst(answers.count)
        for (slot, text) in zip(remainingSlots, distractors) {
            nuts.append(ClawNut(text: text,
                                sequenceIndex: nil,
                                isGold: false,
                                position: jitter(slot.position, radius: slot.radius, random: random),
                                radius: slot.radius))
        }
        return nuts
    }

    static func jitter(_ point: ClawPoint, radius: Double, random: RandomSource) -> ClawPoint {
        ClawPoint(x: clamp01(point.x + random.double(in: -0.001..<0.001)),
                  y: min(0.985 - radius, point.y))
    }

    /// Builds a dense hex mound that fills the pile, matching the claw-machine
    /// reference: five to seven stacked rows rather than a thin bowling pin.
    static func hexSlots(count: Int,
                         strategy: LayoutStrategy,
                         random: RandomSource) -> [Slot] {
        if strategy == .twinPiles, count >= 18 {
            let left = count / 2 + count % 2
            let right = count - left
            return mound(count: left, bias: 0.28, width: 0.50, strategy: .centerMountain, random: random)
                + mound(count: right, bias: 0.74, width: 0.50, strategy: .centerMountain, random: random)
        }
        let bias: Double
        switch strategy {
        case .leftSlope: bias = 0.46
        case .rightSlope: bias = 0.54
        case .cascade: bias = 0.50 + random.double(in: -0.03..<0.03)
        default: bias = 0.50
        }
        let width = strategy == .wideMound ? 0.99 : 0.97
        return mound(count: count, bias: bias, width: width, strategy: strategy, random: random)
    }

    static func mound(count: Int,
                      bias: Double,
                      width: Double,
                      strategy: LayoutStrategy,
                      random: RandomSource) -> [Slot] {
        let rows = rowCounts(total: count, wide: strategy == .wideMound || strategy == .centerMountain)
        _ = random
        let bottom = rows.max() ?? max(3, count)
        let spacingX = width / Double(max(bottom, 1))
        let radius = spacingX * 0.50
        let floor = 0.985 - radius
        // √3 keeps hex valleys; screen mapping is isotropic so this is also
        // the pixel gap. Nuts rest in the pockets without shell overlap.
        let spacingY = radius * 1.732
        var slots: [Slot] = []

        for (row, length) in rows.enumerated() {
            let rowWidth = Double(max(length - 1, 0)) * spacingX
            let startX = bias - rowWidth / 2
            let y = floor - Double(max(rows.count - 1 - row, 0)) * spacingY
            let stagger = (row % 2 == 1) ? spacingX * 0.50 : 0
            for column in 0..<length {
                let x = startX + Double(column) * spacingX + stagger
                slots.append(Slot(position: ClawPoint(x: min(max(x, radius + 0.01), 1 - radius - 0.01),
                                                      y: y),
                                  radius: radius,
                                  row: row))
            }
        }
        return slots
    }

    /// Wide stacked mound: full-width rows at the bottom, a slightly narrower
    /// peak, enough slots for every nut even on a 50-sum board.
    static func rowCounts(total: Int, wide: Bool) -> [Int] {
        guard total > 0 else { return [] }
        let maxBottom = wide ? 6 : 5
        let targetRows: Int
        switch total {
        case ..<10: targetRows = 3
        case ..<18: targetRows = 4
        case ..<28: targetRows = 5
        case ..<42: targetRows = 6
        default: targetRows = 7
        }
        var bottom = min(maxBottom, max(3, Int(ceil(Double(total) / Double(targetRows)))))
        while bottom * targetRows < total, bottom < maxBottom {
            bottom += 1
        }
        var remaining = total
        var fromBottom: [Int] = []
        while remaining > 0 {
            let width = min(bottom, remaining)
            fromBottom.append(width)
            remaining -= width
        }
        var rows = Array(fromBottom.reversed())
        if rows.count >= 3, let first = rows.first, first == bottom, rows.last == bottom, bottom > 3 {
            let shave = min(2, first - 2)
            rows[0] -= shave
            rows[rows.count - 1] += shave
        }
        return rows.filter { $0 > 0 }
    }

    static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
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
    /// other in the pile.
    static func separateSimilarValues(_ nuts: inout [ClawNut]) {
        for _ in 0..<28 {
            var moved = false
            for i in nuts.indices {
                for j in nuts.indices where j > i {
                    guard value(of: nuts[i]) == value(of: nuts[j]),
                          closeTogether(nuts[i], nuts[j]) else { continue }
                    let match = value(of: nuts[i])
                    let candidates = nuts.indices.filter { k in
                        k != i && k != j
                            && value(of: nuts[k]) != match
                            && !closeTogether(nuts[i], nuts[k])
                    }
                    guard let k = candidates.max(by: {
                        distance(nuts[i], nuts[$0]) < distance(nuts[i], nuts[$1])
                    }) else { continue }
                    swapPositions(&nuts, j, k)
                    moved = true
                }
            }
            if !moved { break }
        }
    }

    /// The grabable layer should read as a set of different answers. Keep the
    /// soonest assigned copy of a value on top and bury extras.
    static func diversifyReachableValues(_ nuts: inout [ClawNut]) {
        for _ in 0..<16 {
            refreshCovering(&nuts)
            let reachable = nuts.indices.filter { ClawPuzzle.isReachable(nuts[$0], among: nuts) }
            var firstIndexForValue: [AnswerValue: Int] = [:]
            var extra: Int?
            for index in reachable {
                let printed = value(of: nuts[index])
                if let kept = firstIndexForValue[printed] {
                    extra = nuts[index].sequenceIndex == 0 ? kept : index
                    if extra == kept, nuts[kept].sequenceIndex == 0 {
                        extra = index
                    }
                    break
                }
                firstIndexForValue[printed] = index
            }
            guard let extra else { return }
            let reachableValues = Set(reachable.map { value(of: nuts[$0]) })
            let buried = nuts.indices.filter { !ClawPuzzle.isReachable(nuts[$0], among: nuts) }
            guard let partner = buried.first(where: { !reachableValues.contains(value(of: nuts[$0])) })
            else { return }
            swapPositions(&nuts, extra, partner)
        }
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

    static func covers(upper: ClawNut, lower: ClawNut) -> Bool {
        let dy = lower.position.y - upper.position.y
        guard dy > min(upper.radius, lower.radius) * 0.22 else { return false }
        let dx = abs(upper.position.x - lower.position.x)
        let reach = (upper.radius + lower.radius) * 0.78
        return dx < reach
    }

    static func isSolvable(_ nuts: [ClawNut], answerCount: Int) -> Bool {
        var remaining = nuts
        for index in 0..<answerCount {
            guard let target = remaining.first(where: { $0.isAssigned(toQuestionIndex: index) }) else {
                return false
            }
            if !ClawPuzzle.isReachable(target, among: remaining) { return false }
            remaining.removeAll { $0.id == target.id }
        }
        return true
    }

    static func repairSolvability(_ nuts: inout [ClawNut], answerCount: Int) {
        for index in 0..<answerCount {
            for _ in 0..<24 {
                refreshCovering(&nuts)
                var remaining = nuts
                remaining.removeAll { nut in
                    (nut.sequenceIndex ?? Int.max) < index
                }
                guard let target = remaining.first(where: { $0.isAssigned(toQuestionIndex: index) }),
                      !ClawPuzzle.isReachable(target, among: remaining)
                else { break }

                let present = Set(remaining.map(\.id))
                let blockers = remaining.filter { target.coveredBy.contains($0.id) && present.contains($0.id) }
                for blocker in blockers {
                    guard let slot = nuts.firstIndex(where: { $0.id == blocker.id }) else { continue }
                    let push = blocker.position.x >= target.position.x ? 0.08 : -0.08
                    nuts[slot].position.x = clamp01(nuts[slot].position.x + push)
                    if (blocker.sequenceIndex ?? -1) > index || blocker.isDistractor {
                        nuts[slot].position.y = min(0.96 - nuts[slot].radius,
                                                    nuts[slot].position.y + 0.025)
                    }
                }
            }
        }
    }
}
