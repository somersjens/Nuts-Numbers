//
//  PromoTrailerScript.swift
//  Nuts & Numbers
//
//  Fixed math beats and nut placement for the App Store teaser.
//

import Foundation
import CoreGraphics

enum PromoTrailerScript {
    static let instruction = "Find the right answer"
    static let unlockHeadline = "Unlock new characters"
    static let speedHeadline = "Grab all the nuts in time to win"

    static let clockTotal: Double = 22
    static let clockStart: Double = 22
    static let speedClockRemaining: Double = 4.2

    /// Three remaining nuts, full grab loops — brisk, but readable.
    static let speedScale: Double = 1.78
    static let lastSpeedScale: Double = 1.35
    /// Keep a hint of the rush into the salto so the release does not slam to 1x.
    static let finaleSpeedScale: Double = 1.32

    static let openingHold: TimeInterval = 0.28
    static let iconHold: TimeInterval = 2.05
    static let iconSpinDuration: TimeInterval = 0.82
    static let playfieldNutCount = 20

    struct Session {
        let puzzle: ClawPuzzle
        let rounds: [GameRound]
        let nutIDs: [UUID]
    }

    static func session() -> Session {
        let slots = moundSlots(count: playfieldNutCount)
        let assigned: [(prompt: String, answer: String, wrongs: [String], kind: QuestionKind)] = [
            ("6 + 7 = ?", "13", ["11", "12", "14", "15"], .addition),
            ("9 − 4 = ?", "5",  ["3", "4", "6", "7"],     .subtraction),
            ("3 + 5 = ?", "8",  ["6", "7", "9", "10"],    .addition),
            ("10 − 4 = ?", "6", ["4", "5", "7", "9"],     .subtraction),
            ("3 × 4 = ?", "12", ["8", "9", "14", "16"],   .multiplication)
        ]
        let distractors = ["9", "11", "14", "4", "3", "7", "10", "15", "16", "2", "1", "18", "20", "21", "17"]

        var labels: [(text: String, sequence: Int?)] = assigned.enumerated().map {
            ($0.element.answer, $0.offset)
        }
        labels += distractors.prefix(max(0, slots.count - labels.count)).map { ($0, nil) }

        var nuts: [ClawNut] = []
        for (index, slot) in slots.enumerated() {
            let label = labels[index]
            nuts.append(ClawNut(id: nutIDs[index],
                                text: label.text,
                                sequenceIndex: label.sequence,
                                position: slot.position,
                                radius: slot.radius))
        }
        placeGrabTargets(&nuts)
        let reachable = nuts.filter { ClawPuzzle.isReachable($0, among: nuts) }.map(\.text)
        print("PROMO_TRAILER_PILE count=\(nuts.count) reachable=\(reachable.joined(separator: ","))")

        var questions: [MathQuestion] = []
        var rounds: [GameRound] = []
        for (index, spec) in assigned.enumerated() {
            let question = MathQuestion(prompt: spec.prompt,
                                        correctAnswer: spec.answer,
                                        distractors: spec.wrongs,
                                        sourceLevel: 1,
                                        kind: spec.kind)
            questions.append(question)
            guard let nut = nuts.first(where: { $0.sequenceIndex == index }) else { continue }
            var options = [AnswerOption(id: nut.id, text: spec.answer, isCorrect: true)]
            options += spec.wrongs.map { AnswerOption(text: $0, isCorrect: false) }
            rounds.append(GameRound(number: index + 1,
                                    question: question,
                                    options: options,
                                    targetNutID: nut.id))
        }

        let puzzle = ClawPuzzle(questions: questions, nuts: nuts, seed: 0xC1A0_7EA5)
        return Session(puzzle: puzzle, rounds: rounds, nutIDs: nuts.map(\.id))
    }

    static let nutIDs: [UUID] = (1...playfieldNutCount).map { uuid($0) }

    static var openingNutID: UUID { nutIDs[0] }
    static var showcaseNutID: UUID { nutIDs[1] }
    static var wrongNutID: UUID { nutIDs[5] }
    static var speedNutIDs: [UUID] { [nutIDs[2], nutIDs[3], nutIDs[4]] }

    /// Top, then left, then right — a small pyramid on the floor, centre of the pile.
    static let speedPyramid: [ClawPoint] = [
        ClawPoint(x: 0.50, y: 0.80),
        ClawPoint(x: 0.39, y: 0.93),
        ClawPoint(x: 0.61, y: 0.93)
    ]

    /// Put 13, 5 and 9 on the three fully uncovered nuts along the top of the mound.
    private static func placeGrabTargets(_ nuts: inout [ClawNut]) {
        func swapText(_ text: String, to index: Int) {
            guard let from = nuts.firstIndex(where: { $0.text == text }), from != index else { return }
            let position = nuts[from].position
            let radius = nuts[from].radius
            nuts[from].position = nuts[index].position
            nuts[from].radius = nuts[index].radius
            nuts[index].position = position
            nuts[index].radius = radius
        }

        let reachable = nuts.indices.filter { ClawPuzzle.isReachable(nuts[$0], among: nuts) }
        let top = reachable.sorted {
            let dy = nuts[$0].position.y - nuts[$1].position.y
            if abs(dy) > 0.02 { return dy < 0 }
            return nuts[$0].position.x < nuts[$1].position.x
        }
        let row = Array(top.prefix(3)).sorted { nuts[$0].position.x < nuts[$1].position.x }
        guard row.count == 3 else { return }
        swapText("5", to: row[0])
        swapText("13", to: row[1])
        swapText("9", to: row[2])
    }

    /// Standard 5-4-5-4-2 brick mound the live puzzle builder uses.
    private static func moundSlots(count: Int) -> [(position: ClawPoint, radius: Double)] {
        let columns = 5
        let radius = 0.5 / Double(columns)
        let spacingX = radius * 2
        var remaining = count
        var even = true
        var rows: [(length: Int, staggered: Bool, capacity: Int)] = []
        while remaining > 0 {
            let capacity = even ? columns : columns - 1
            let length = min(capacity, remaining)
            rows.append((length, !even, capacity))
            remaining -= length
            even.toggle()
        }
        var spacingY = spacingX * 0.54
        let floor = 1 - radius
        if rows.count > 1 {
            let maxRise = max(0.12, floor - radius - 0.04)
            spacingY = min(spacingY, max(spacingX * 0.50, maxRise / Double(rows.count - 1)))
        }
        var slots: [(position: ClawPoint, radius: Double)] = []
        for (rowFromBottom, row) in rows.enumerated() {
            let y = floor - Double(rowFromBottom) * spacingY
            let start = (row.capacity - row.length) / 2
            for column in 0..<row.length {
                let gridColumn = start + column
                let x = radius
                    + (row.staggered ? spacingX * 0.5 : 0)
                    + Double(gridColumn) * spacingX
                slots.append((ClawPoint(x: x, y: y), radius))
            }
        }
        return slots
    }

    private static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "C1A07EA5-0000-4000-8000-%012d", n))!
    }
}
