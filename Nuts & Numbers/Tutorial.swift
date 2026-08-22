//
//  Tutorial.swift
//  Nuts & Numbers
//
//  The guided first game. A new player is walked through the claw machine:
//  steering, grabbing the right nut, seeing the score change, then the timer.
//  Scoring still runs through `MemoryGame`, so the nuts collected here count.
//

import SwiftUI
import Combine

// MARK: - Steps

/// The nine in-game steps, in the order they are played. The tenth step of the
/// script is the score pointer on the home screen, which lives there rather than
/// in a session — see `HomeView`.
enum TutorialStep: Int, CaseIterable, Identifiable {
    /// Tap a point and the fish swims there. The marker sits below the fish.
    case tapToSwim = 1
    /// The same, held and dragged, with the marker at the top of the water.
    case dragToSwim
    /// Two bubbles, one of them right.
    case collectCorrect
    /// A 2x fish, which doubles the next answer.
    case bonusFish = 6
    /// Five right answers in a row, one bubble at a time, to reach the streak.
    case buildStreak
    /// The streak is running: two bubbles at the boosted tempo.
    case superBonusRunning
    /// Normal play resumes; the last message clears itself after a few seconds.
    case freePlay
    /// Claw-only: collect once more while the score display is pointed out.
    case clawRaiseScore
    /// Claw-only: explain the level clock before it starts counting down.
    case clawTimer

    var id: Int { rawValue }

    var clawMessageKey: String { "tutorial.claw.step.\(rawValue)" }

    /// Give the player enough time to read the clock rule before play becomes timed.
    static let clawTimerMessageDuration = 5.0
}

// MARK: - Controller

/// Runs the script: holds the current step, hands the claw machine its plan,
/// and moves on the moment the step's own condition is met.
@MainActor
final class TutorialController: ObservableObject {
    @Published private(set) var step: TutorialStep?

    /// The session being taught. Weak, so the controller can never keep a
    /// finished game alive.
    private weak var model: GameViewModel?
    /// Invalidates the pending close of the last message when the run is left,
    /// restarted or finished first.
    private var generation = 0

    var isActive: Bool { step != nil }

    /// The line currently on screen, in the player's own language.
    var message: String? {
        step.map { L(key: $0.clawMessageKey) }
    }

    /// What the claw machine should allow while a step is being taught.
    var clawPlan: ClawTutorialPlan {
        Self.clawPlan(for: step)
    }

    // MARK: Lifecycle

    /// Starts the walkthrough on a session that has just opened its first round.
    func begin(model: GameViewModel) {
        guard step == nil else { return }
        self.model = model
        model.setTutorialClockPaused(true)
        model.onAnswerResolved = { [weak self] isCorrect, _ in
            self?.answerResolved(isCorrect: isCorrect)
        }
        // Whatever happens to this session from here — finished, lost or left —
        // the home screen owes them the last step of the script.
        GameSettings.tutorialHomeHintPending = true
        enter(.tapToSwim)
    }

    /// Ends the walkthrough and hands the level back to timed play.
    func finish() {
        guard step != nil else { return }
        generation &+= 1
        release()
        withAnimation(.easeOut(duration: 0.32)) {
            step = nil
        }
    }

    /// Leaving the game screen: the same tidy-up, without the animation of a
    /// view that is on its way out.
    func cancel() {
        guard step != nil else { return }
        generation &+= 1
        release(resumeClock: false)
        step = nil
    }

    private func release(resumeClock: Bool = true) {
        model?.setTutorialClockPaused(false, resumeClock: resumeClock)
        model?.onAnswerResolved = nil
    }

    // MARK: Events

    func handleClaw(_ event: ClawTutorialEvent) {
        guard let step else { return }
        switch event {
        case .movedClaw:
            if step == .tapToSwim {
                // One steering gesture. Continue straight to choosing an
                // answer once the player has moved the handle.
                enter(.collectCorrect)
            } else if step == .dragToSwim {
                enter(.collectCorrect)
            }
        case .pressedGrab:
            // The last in-game line is a send-off. A dead red button while
            // that message is up reads as a broken control, so a grab here
            // simply ends the lesson and starts the timed game.
            if step == .clawTimer { finish() }
        }
    }

    /// Reported by the session for every answer it accepts.
    private func answerResolved(isCorrect: Bool) {
        guard let step else { return }
        switch step {
        case .collectCorrect:
            if isCorrect {
                // The first nut teaches the grab. The next one is collected
                // while the score display itself is called out.
                enter(.clawRaiseScore)
            }
        case .clawRaiseScore:
            if isCorrect { enter(.clawTimer) }
        default:
            break
        }
    }

    // MARK: Steps

    private func enter(_ step: TutorialStep) {
        generation &+= 1
        let token = generation

        // A tutorial transition can happen while the joystick's DragGesture is
        // still delivering samples. Animating the entire plan in that gesture
        // transaction moves hit regions and produces out-of-order animation
        // samples. The message/hints animate internally; their geometry stays
        // fixed here.
        self.step = step

        if step == .clawTimer {
            // The clock stays frozen for this send-off. Grabbing also ends the
            // lesson; this beat is only the fallback if they just read.
            DispatchQueue.main.asyncAfter(
                deadline: .now() + TutorialStep.clawTimerMessageDuration
            ) { [weak self] in
                guard let self, self.generation == token, self.step == step else { return }
                self.finish()
            }
        }
    }

    private static func clawPlan(for step: TutorialStep?) -> ClawTutorialPlan {
        guard let step else { return ClawTutorialPlan() }
        var plan = ClawTutorialPlan()
        plan.isActive = true
        switch step {
        case .tapToSwim:
            plan.wantsMove = true
            plan.suppressesGrab = true
            plan.highlightsJoystick = true
        case .dragToSwim:
            // Kept for the reef walkthrough; the claw path skips this step.
            plan.wantsMove = true
            plan.suppressesGrab = true
            plan.highlightsJoystick = true
        case .collectCorrect:
            plan.highlightsCorrectNut = true
            plan.highlightsJoystick = true
            plan.highlightsGrab = true
        case .bonusFish:
            plan.suppressesGrab = true
        case .clawRaiseScore:
            plan.highlightsCorrectNut = true
            plan.highlightsJoystick = true
            plan.highlightsGrab = true
            plan.highlightsScore = true
        case .clawTimer:
            plan.highlightsTimer = true
        default:
            break
        }
        return plan
    }
}

// MARK: - Message

/// The line the tutorial is currently teaching, shown under the HUD in the
/// game and at the top of the menu for the closing step. The character does the
/// talking, so it reads as the same voice as the level card.
struct TutorialMessageCard: View {
    let text: String
    let theme: AnimalCharacter
    var isPad: Bool = AppLayout.isPad

    private var portraitSize: CGFloat { isPad ? 56 : 42 }

    var body: some View {
        HStack(alignment: .center, spacing: isPad ? 14 : 10) {
            theme.artwork
                .resizable()
                .scaledToFit()
                .padding(isPad ? 4 : 3)
                .frame(width: portraitSize, height: portraitSize)
                .background(theme.skyColor,
                            in: RoundedRectangle(cornerRadius: isPad ? 15 : 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: isPad ? 15 : 12, style: .continuous)
                    .stroke(theme.deepColor.opacity(0.12), lineWidth: 1))

            Text(verbatim: text)
                .font(.system(size: isPad ? 19 : 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(theme.deepColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, isPad ? 16 : 12)
        .padding(.vertical, isPad ? 12 : 9)
        .background {
            RoundedRectangle(cornerRadius: isPad ? 24 : 20, style: .continuous)
                .fill(.white.opacity(0.95))
                .overlay {
                    RoundedRectangle(cornerRadius: isPad ? 24 : 20, style: .continuous)
                        .stroke(.white, lineWidth: 2)
                }
                .shadow(color: theme.deepColor.opacity(0.24), radius: 12, y: 6)
        }
        .frame(maxWidth: isPad ? 620 : 420)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - "Before the first point" notice

/// Shown when the tutorial is asked for after the first point was earned.
/// Same card, same button as everything else the level screen puts up.
struct TutorialNoticeCard: View {
    let theme: AnimalCharacter
    let onDismiss: () -> Void

    private var isPad: Bool { AppLayout.isPad }
    private var scale: CGFloat { isPad ? 1.2 : 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 14 * scale) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 30 * scale, weight: .bold))
                    .foregroundStyle(theme.deepColor)
                    .frame(width: 62 * scale, height: 62 * scale)
                    .background(theme.skyColor, in: Circle())

                Text("tutorial.notice.title")
                    .font(.system(size: 22 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.deepColor)
                    .multilineTextAlignment(.center)

                Text("tutorial.notice.message")
                    .font(.system(size: 15 * scale, weight: .regular))
                    .foregroundStyle(theme.deepColor.opacity(0.84))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onDismiss) {
                    Text("common.ok")
                        .font(.system(size: 17 * scale, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14 * scale)
                        .foregroundStyle(.white)
                        .background(theme.deepColor,
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tutorial-notice-ok")
            }
            .padding(26 * scale)
            .frame(maxWidth: 340 * scale)
            // Same light fill as the start/pause card: `.background` turns
            // black in Dark Mode against this card's deep-purple copy.
            .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.deepColor.opacity(0.14), lineWidth: 1))
            .shadow(color: theme.deepColor.opacity(0.3), radius: 20, y: 10)
            .padding(24)
        }
    }
}
