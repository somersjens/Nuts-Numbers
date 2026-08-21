//
//  GameView.swift
//  Math Memory
//
//  The playing surface. A round runs on the reef: the sum stands on a piece of
//  coral on the sea floor, the coral lets answer bubbles up through the water,
//  and the player steers a fish into the bubble carrying the right answer.
//
//  All rules live in `MemoryGame` and the whole of the reef lives in
//  `ReefGame.swift`; this file only puts the HUD, the reef and the helper
//  together and hands every touched answer straight to the engine, which is the
//  single place that decides whether it counts.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Everything a session needs to start: which level to draw questions from and
/// how many answer cards each round lays out.
struct GameSessionRequest: Identifiable {
    let level: MathLevel
    /// Only meaningful for Supermix levels; every other topic has one operation.
    var mixedVariant: MixedVariant = .all
    /// Which of the three order buttons was chosen. Supermix ignores it.
    var mode: PracticeMode = .mixed
    /// True when the level was opened to be taught: the start card offers the
    /// walkthrough straight away. Deliberately outside `id`, which identifies
    /// the *board* being played.
    var startsTutorialArmed = false
    var id: String { "\(level.id).\(mixedVariant.rawValue).\(mode.rawValue)" }

    /// The scoreboard this session plays on.
    var board: LevelBoard {
        LevelBoard(level: level, mixedVariant: mixedVariant, mode: mode)
    }

    /// Choice one, two and three on the final welcome screen start the player
    /// at a suitable point in their chosen topic.
    static func onboardingStartLevel(topic: MathTopic, mode: PracticeMode) -> MathLevel? {
        let index: Int
        switch mode {
        case .order:  index = 2
        case .random: index = 5
        case .mixed:  index = 10
        }
        return LevelCatalog.levels(for: topic).first { $0.index == index }
    }

    /// The first session the welcome flow opens: the walkthrough, on the
    /// exercise the player just chose.
    static func tutorialHandoff(topic: MathTopic,
                                mode: PracticeMode,
                                mixedVariant: MixedVariant) -> GameSessionRequest? {
        guard let level = onboardingStartLevel(topic: topic, mode: mode) else { return nil }
        return GameSessionRequest(level: level,
                                  mixedVariant: mixedVariant,
                                  mode: mode,
                                  startsTutorialArmed: true)
    }
}

struct GameView: View {
    let request: GameSessionRequest
    /// Used when this view is shown in-hierarchy (the welcome-flow handoff)
    /// rather than inside a `fullScreenCover`, which supplies `dismiss`.
    private let onExit: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var premium = PremiumStore.shared
    @ObservedObject private var language = LanguageManager.shared
    @StateObject private var model: GameViewModel
    /// The walkthrough. Inert until a run is actually started with it armed.
    @StateObject private var tutorial = TutorialController()

    /// The window's safe area, sampled once the view is on screen — never from
    /// inside `body`; see `ScreenSafeArea`.
    @State private var screenInsets = ScreenSafeArea()

    /// The level's start card, shown before the first round and dismissed by
    /// the player. The session only begins once it is gone.
    @State private var showsIntro = true
    /// The same card doubles as the in-level pause screen. Keeping this state
    /// separate from `showsIntro` lets a brand-new run still say Start while a
    /// pause made before the first answer already says Continue.
    @State private var showsPauseCard = false
    /// After the card, the fish gets the stage to itself for one short looping
    /// entrance. The first round only opens when that animation is finished.
    @State private var playsFishEntrance = false
    /// Measured from the real HUD layout so the flying currency glyph can land
    /// pixel-for-pixel over its stationary twin on every device and score width.
    @State private var scoreIconCenter: CGPoint?
    /// A completed board gets one last moment in the reef before its result
    /// card appears. Other endings (no lives, or leaving) remain immediate.
    @State private var playsLevelCompletion = false
    @State private var playsTimeOutFinale = false
    @State private var showsResult = false
    /// Whether pressing Start will run the walkthrough. Armed from the menu for
    /// a brand-new player, and toggled by the cap button on the start card.
    @State private var isTutorialArmed: Bool
    /// The "only at the start of a game" note, raised by the cap button on a
    /// run that is already under way.
    @State private var showsTutorialNotice = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(request: GameSessionRequest, onExit: (() -> Void)? = nil) {
        self.request = request
        self.onExit = onExit
        _model = StateObject(wrappedValue: GameViewModel(request: request))
        // A level with a run waiting on it is continued, never taught: the
        // walkthrough needs a session it can shape from its very first round.
        _isTutorialArmed = State(
            initialValue: request.startsTutorialArmed
                && PausedSessionStore.shared.session(request.board) == nil
        )
    }

    private var character: AnimalCharacter { CharacterCatalog.current(isPremium: premium.isPremium) }
    private var clawPalette: ClawPalette { ClawPalette(character: character) }
    private var isPad: Bool { AppLayout.isPad }

    var body: some View {
        ZStack {
            character.tintColor
                .ignoresSafeArea()

            // Keep the level visible underneath every card. The result is an
            // overlay over the reef that was just played, exactly like the
            // start and pause cards, rather than a replacement for the game.
            playfield
                .transition(.opacity)

            if showsResult {
                ResultView(result: model.result,
                           board: request.board,
                           character: character,
                           onPlayAgain: {
                               showsResult = false
                               playsLevelCompletion = false
                               playsTimeOutFinale = false
                               Task { await model.restart() }
                           },
                           onExit: leave)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }

            if showsIntro {
                LevelIntroCard(board: request.board,
                               theme: character,
                               isPauseCard: showsPauseCard,
                               isTutorialArmed: isTutorialArmed,
                               onToggleTutorial: toggleTutorial,
                               onStart: startSession,
                               onExit: leave)
                    .transition(.opacity)
                    .zIndex(2)
            }

            if showsTutorialNotice {
                TutorialNoticeCard(theme: character) {
                    withAnimation(.easeOut(duration: 0.2)) { showsTutorialNotice = false }
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: model.isGameOver)
        .animation(.easeInOut(duration: 0.35), value: showsIntro)
        .onAppear {
            screenInsets = ScreenSafeArea.current
            model.prepare()
        }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(
            for: UIDevice.orientationDidChangeNotification
        )) { _ in
            // Safe-area sides change when an iPad rotates. Re-sample after
            // UIKit has committed the new window geometry so the HUD remains
            // clear of rounded corners in either landscape direction.
            DispatchQueue.main.async {
                screenInsets = ScreenSafeArea.current
            }
        }
#endif
        .onChange(of: model.isGameOver) { _, isOver in
            // There is nothing left to teach on a finished board.
            if isOver { tutorial.finish() }
            guard isOver else {
                showsResult = false
                playsLevelCompletion = false
                playsTimeOutFinale = false
                return
            }
            if model.result.reason == .roundsCompleted {
                playsLevelCompletion = true
            } else if model.result.reason == .outOfTime {
                playsTimeOutFinale = true
            } else {
                showsResult = true
            }
        }
        .onDisappear {
            tutorial.cancel()
            model.end()
        }
    }

    private func leave() {
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }

    private func startSession() {
        showsIntro = false
        if showsPauseCard, model.state != .intro {
            showsPauseCard = false
            model.resume()
        } else {
            showsPauseCard = false
            playsFishEntrance = true
        }
    }

    private func finishFishEntrance() {
        guard playsFishEntrance else { return }
        playsFishEntrance = false
        Task {
            await model.begin()
            // The walkthrough opens on the first round, once the fish has swum
            // in and there is a reef to talk about. Disarming it here is what
            // makes the pause card offer Continue rather than Start tutorial.
            if isTutorialArmed, model.state != .intro {
                isTutorialArmed = false
                tutorial.begin(model: model)
            }
        }
    }

    /// The cap on the start card. A run that is already under way cannot be
    /// rewound into a lesson, so there the button explains itself instead.
    private func toggleTutorial() {
        AppAudio.shared.playMenuTap()
        guard model.state == .intro,
              PausedSessionStore.shared.session(request.board) == nil,
              !showsPauseCard else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                showsTutorialNotice = true
            }
            return
        }
        withAnimation(.snappy(duration: 0.2)) { isTutorialArmed.toggle() }
    }

    // MARK: - Playfield

    private var playfield: some View {
        // The reef is the whole screen — water from the very top edge down to
        // the sea floor at the very bottom — with the HUD laid over it. Reading
        // the insets here is what keeps the fish clear of the HUD and the sum
        // clear of the home indicator.
        // The HUD keeps a floor under it, so it still clears the status bar on
        // the very first frame, before the insets have been sampled.
        let topInset = max(screenInsets.top, isPad ? 24 : 54)

        return ZStack(alignment: .top) {
            ClawPlayfield(round: model.round,
                          puzzle: model.clawPuzzle,
                          collectedAnswers: max(0, model.roundNumber - 1),
                          maximumRounds: model.maximumRounds,
                          character: character,
                          isPad: isPad,
                          isLive: model.acceptsInput,
                          isRunning: isReefRunning,
                          playsEntrance: playsFishEntrance,
                          isStreakBoostActive: model.isStreakBoostActive,
                          playsLevelCompletion: playsLevelCompletion,
                          playsTimeOutFinale: playsTimeOutFinale,
                          reduceMotion: reduceMotion,
                          tutorialPlan: tutorial.clawPlan,
                          score: model.cards,
                          topReserve: topInset + (isPad ? 8 : 6),
                          bottomReserve: screenInsets.bottom,
                          scoreTarget: scoreIconCenter,
                          onGrab: { nut, _ in
                              model.resolveGrab(nut: nut)
                          },
                          onScoreBubbleArrived: model.scoreBubbleArrived,
                          onEntranceComplete: finishFishEntrance,
                          onLevelCompletionFinished: finishLevelCompletion,
                          onTimeOutFinished: finishTimeOutFinale,
                          onTutorialEvent: tutorial.handleClaw)

            hud
                .padding(.leading, max(isPad ? 8 : 4, screenInsets.leading + 2))
                .padding(.trailing, max(isPad ? 8 : 4, screenInsets.trailing + 2))
                // Centre the mounted pause and timer controls on the prompt
                // plaque's horizontal axis, regardless of their outer sizes.
                .padding(.top, topInset - (isPad ? 13 : 10))
                .opacity(playsLevelCompletion || playsTimeOutFinale ? 0 : 1)
                .animation(.easeOut(duration: 0.22), value: playsLevelCompletion || playsTimeOutFinale)
                .allowsHitTesting(!playsLevelCompletion && !playsTimeOutFinale)

            // The walkthrough speaks from just under the HUD, clear of both the
            // sum on the coral and the water the first steps ask the player to
            // cross. It never takes a touch: the reef stays fully steerable
            // while a step is being read.
            if let message = tutorial.message, !playsLevelCompletion, !playsTimeOutFinale {
                TutorialMessageCard(text: message, theme: character, isPad: isPad)
                    .padding(.horizontal, max(isPad ? 28 : 14, screenInsets.leading + 12))
                    .padding(.top, topInset + (isPad ? 88 : 72))
                    // Scales up in place rather than sliding down: a card that
                    // travelled would cross the HUD on its way in.
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                    .allowsHitTesting(false)
                    .id(tutorial.step)
            }
        }
        .ignoresSafeArea()
        .onPreferenceChange(ScoreIconCenterPreferenceKey.self) { center in
            scoreIconCenter = center
        }
    }

    private func finishLevelCompletion() {
        guard playsLevelCompletion else { return }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
            showsResult = true
        }
        // Keep the final bubble bloom under the card during its entrance so
        // there is never a flash of the bare playfield between both scenes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            playsLevelCompletion = false
        }
    }

    private func finishTimeOutFinale() {
        guard playsTimeOutFinale else { return }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
            showsResult = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            playsTimeOutFinale = false
        }
    }

    // MARK: - HUD

    private var hud: some View {
        HStack(alignment: .top, spacing: isPad ? 12 : 8) {
            pauseButton
                .padding(.top, isPad ? 10 : 6)
            Spacer(minLength: 0)
            ClawTimerBadge(clock: model.clock,
                           isPad: isPad,
                           size: hudTimerSize,
                           palette: clawPalette)
        }
    }

    private var pauseButton: some View {
        let palette = clawPalette
        return Button {
            AppAudio.shared.playMenuTap()
            model.pause()
            showsPauseCard = true
            showsIntro = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: isPad ? 7 : 5, style: .continuous)
                    .fill(palette.woodDeep)
                    .frame(width: hudPauseMountSize * 0.32,
                           height: hudPauseMountSize * 0.38)
                    .offset(y: hudPauseMountSize * 0.43)

                RoundedRectangle(cornerRadius: isPad ? 18 : 14, style: .continuous)
                    .fill(
                        LinearGradient(colors: [palette.woodLight,
                                                palette.wood,
                                                palette.woodDeep],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: hudPauseMountSize, height: hudPauseMountSize)
                    .overlay {
                        RoundedRectangle(cornerRadius: isPad ? 18 : 14, style: .continuous)
                            .strokeBorder(palette.woodDeep,
                                          lineWidth: isPad ? 3 : 2)
                    }
                    .overlay {
                        CabinetMountFasteners(size: isPad ? 5 : 4,
                                              inset: isPad ? 8 : 6,
                                              palette: palette)
                    }
                    .overlay {
                        CabinetHUDWoodGrain(color: palette.woodDeep)
                            .clipShape(RoundedRectangle(cornerRadius: isPad ? 18 : 14,
                                                       style: .continuous))
                    }

                RoundedRectangle(cornerRadius: isPad ? 14 : 11, style: .continuous)
                    .fill(
                        LinearGradient(colors: [palette.character.deepColor,
                                                Color.black.opacity(0.86)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: hudPauseSize, height: hudPauseSize)
                    .overlay {
                        Image(systemName: "pause.fill")
                            .font(.system(size: pauseGlyphSize, weight: .bold))
                            .foregroundStyle(palette.character.skyColor)
                            .shadow(color: palette.character.color.opacity(0.55), radius: 3)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: isPad ? 14 : 11, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [palette.woodLight,
                                                        palette.woodDeep],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 2
                            )
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: isPad ? 10 : 7, weight: .bold))
                            .foregroundStyle(palette.character.color.opacity(0.72))
                            .padding(isPad ? 5 : 4)
                    }
            }
            .frame(width: hudPauseMountSize, height: hudPauseMountSize)
            .shadow(color: palette.character.color.opacity(0.30), radius: isPad ? 12 : 9)
            .shadow(color: .black.opacity(0.42), radius: 4, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pause")
        .accessibilityLabel(Text("game.pause"))
    }

    private var hudTimerSize: CGFloat { isPad ? 76 : 58 }
    private var hudPauseSize: CGFloat { isPad ? 56 : 46 }
    private var hudPauseMountSize: CGFloat { isPad ? 72 : 58 }
    private var pauseGlyphSize: CGFloat { isPad ? 22 : 18 }

    /// The reef only ticks while the level is actually being played: never
    /// behind the start card or the result card, and never while the app is in
    /// the background.
    private var isReefRunning: Bool {
        !showsIntro && (!model.isGameOver || playsLevelCompletion || playsTimeOutFinale)
            && scenePhase == .active
    }
}

private struct ClawTimerBadge: View {
    @ObservedObject var clock: GameClock
    let isPad: Bool
    let size: CGFloat
    let palette: ClawPalette

    private var remaining: Double { clock.remaining }
    private var total: Double { clock.total }

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, remaining / total))
    }

    private var seconds: Int { max(0, Int(remaining.rounded(.up))) }

    var body: some View {
        let mountSize = size + (isPad ? 16 : 12)
        return ZStack {
            RoundedRectangle(cornerRadius: isPad ? 7 : 5, style: .continuous)
                .fill(palette.woodDeep)
                .frame(width: mountSize * 0.28, height: mountSize * 0.34)
                .offset(y: mountSize * 0.43)

            Circle()
                .fill(
                    LinearGradient(colors: [palette.woodLight,
                                            palette.wood,
                                            palette.woodDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: mountSize, height: mountSize)
                .overlay {
                    Circle()
                        .strokeBorder(palette.woodDeep,
                                      lineWidth: isPad ? 3 : 2)
                }
                .overlay {
                    CabinetMountFasteners(size: isPad ? 5 : 4,
                                          inset: isPad ? 7 : 6,
                                          palette: palette)
                        .clipShape(Circle())
                }
                .overlay {
                    CabinetHUDWoodGrain(color: palette.woodDeep)
                        .clipShape(Circle())
                }

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [palette.character.deepColor,
                                                Color.black.opacity(0.88)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Circle()
                    .stroke(
                        LinearGradient(colors: [palette.woodLight,
                                                palette.woodDeep],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: isPad ? 5 : 4
                    )
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(palette.character.color,
                            style: StrokeStyle(lineWidth: isPad ? 6 : 5, lineCap: .round))
                    .shadow(color: palette.character.skyColor.opacity(0.75), radius: 3)
                    .rotationEffect(.degrees(-90))
                    .padding(isPad ? 6 : 5)
                Text(verbatim: LN(seconds))
                    .font(.system(size: isPad ? 24 : 18, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.character.skyColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
            .frame(width: size, height: size)
        }
        .frame(width: mountSize, height: mountSize)
        .shadow(color: .black.opacity(0.42), radius: 4, y: 3)
        .accessibilityIdentifier("timer")
        .accessibilityLabel(Text(L("game.claw.timeRemaining \(seconds)")))
    }
}

private struct CabinetMountFasteners: View {
    let size: CGFloat
    let inset: CGFloat
    let palette: ClawPalette

    var body: some View {
        VStack {
            row
            Spacer(minLength: 0)
            row
        }
        .padding(inset)
        .allowsHitTesting(false)
    }

    private var row: some View {
        HStack {
            fastener
            Spacer(minLength: 0)
            fastener
        }
    }

    private var fastener: some View {
        Circle()
            .fill(palette.woodDeep)
            .frame(width: size, height: size)
            .overlay {
                Capsule()
                    .fill(palette.woodLight.opacity(0.72))
                    .frame(width: size * 0.66, height: 1)
                    .rotationEffect(.degrees(-18))
            }
    }
}

private struct CabinetHUDWoodGrain: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for index in 0..<4 {
                    let y = size.height * (0.22 + CGFloat(index) * 0.18)
                    var path = Path()
                    path.move(to: CGPoint(x: size.width * 0.12, y: y))
                    path.addCurve(to: CGPoint(x: size.width * 0.88, y: y + CGFloat(index % 2) * 2),
                                  control1: CGPoint(x: size.width * 0.34, y: y - 2),
                                  control2: CGPoint(x: size.width * 0.64, y: y + 3))
                    context.stroke(path,
                                   with: .color(color.opacity(0.18)),
                                   style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Level wallpaper

/// The level's own quiet wallpaper: a staggered grid of the level's number and
/// sign ("3×", "−4", "25%") or a stacked fraction, in a faint wash of the
/// theme colour. Carried over from the original game.
struct LevelWallpaper: View {
    let level: MathLevel
    let tint: Color

    /// The glyph that fills the wallpaper, built from the level's own card
    /// number so it reads like the level itself. Fractions draw a stacked
    /// fraction instead and return nil here.
    private var glyph: String? {
        let n = level.cardNumber
        switch level.topic {
        case .addition:    return "\(n)+"
        case .subtraction: return "−\(n)"
        case .tables:      return "\(n)×"
        case .percentages: return "\(n)%"
        case .mixed:       return "\(n)★"
        case .fractions:   return nil
        }
    }

    private var isPad: Bool { AppLayout.isPad }
    private var fontSize: CGFloat { isPad ? 30 : 22 }
    private var spacingX: CGFloat { isPad ? 118 : 86 }
    private var spacingY: CGFloat { isPad ? 104 : 76 }

    var body: some View {
        GeometryReader { proxy in
            let columns = Int(ceil(proxy.size.width / spacingX)) + 1
            let rows = Int(ceil(proxy.size.height / spacingY)) + 1

            // A staggered grid of 150–300 Text views was rebuilt whenever the
            // HUD scored. One Canvas draw keeps the same wallpaper and costs a
            // single pass.
            Canvas { context, _ in
                for row in 0..<rows {
                    for column in 0..<columns {
                        let point = CGPoint(
                            x: CGFloat(column) * spacingX
                                + (row.isMultiple(of: 2) ? 0 : spacingX / 2),
                            y: CGFloat(row) * spacingY
                        )
                        drawTile(in: &context, at: point)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawTile(in context: inout GraphicsContext, at point: CGPoint) {
        let color = tint.opacity(0.10)
        if let glyph {
            context.draw(
                Text(verbatim: glyph)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .foregroundColor(color),
                at: point,
                anchor: .center
            )
            return
        }

        // The fraction levels have one denominator each, so the wallpaper
        // mirrors it: 1/3 on the thirds level, and so on.
        let stackedSize = fontSize * 0.62
        let stackedFont = Font.system(size: stackedSize, weight: .heavy, design: .rounded)
        context.draw(
            Text(verbatim: "1").font(stackedFont).foregroundColor(color),
            at: CGPoint(x: point.x, y: point.y - stackedSize * 0.55),
            anchor: .center
        )
        let ruleWidth = stackedSize * 0.9
        let rule = CGRect(x: point.x - ruleWidth / 2,
                          y: point.y - 1,
                          width: ruleWidth,
                          height: 2)
        context.fill(Path(rule), with: .color(color))
        context.draw(
            Text(verbatim: "\(level.cardNumber)").font(stackedFont).foregroundColor(color),
            at: CGPoint(x: point.x, y: point.y + stackedSize * 0.55),
            anchor: .center
        )
    }
}

// MARK: - Lives

struct LivesView: View {
    let lives: Double
    let character: AnimalCharacter
    let isPad: Bool
    /// Matches the bubble in the centre of the HUD.
    var glyphSize: CGFloat = 16
    /// Keeps every HUD group centred on the pause button's horizontal axis.
    var rowHeight: CGFloat = 34

    private var wholeHearts: Int { Int(lives.rounded(.down)) }
    private var hasHalf: Bool { lives - Double(wholeHearts) >= 0.5 }
    private var capacity: Int { Int(GameConfig.startingLives.rounded(.up)) }

    /// Hearts wear the character's own deep colour — the same one the counter
    /// and the close button use — rather than a generic red.
    private var heartColor: Color { character.deepColor }

    var body: some View {
        HStack(spacing: isPad ? 5 : 3) {
            ForEach(0..<capacity, id: \.self) { index in
                heart(at: index)
            }
        }
        .frame(height: rowHeight, alignment: .center)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lives)
        .accessibilityElement()
        .accessibilityIdentifier("lives")
        .accessibilityLabel(Text(L("game.livesRemaining \(livesText)")))
        .accessibilityValue(Text(verbatim: livesText))
    }

    private var livesText: String {
        // Halves read as "2.5" — or "2,5" in Dutch; whole lives never show a
        // decimal tail.
        lives == lives.rounded()
            ? "\(Int(lives))"
            : String(format: "%.1f", locale: LanguageManager.shared.locale, lives)
    }

    /// A full, half or empty heart. The half heart is the full glyph masked to
    /// its leading half over the empty one, so the two always align exactly.
    private func heart(at index: Int) -> some View {
        let size = glyphSize
        return ZStack {
            Image(systemName: "heart.fill")
                .foregroundStyle(heartColor.opacity(0.22))
            if index < wholeHearts {
                Image(systemName: "heart.fill")
                    .foregroundStyle(heartColor)
            } else if index == wholeHearts && hasHalf {
                Image(systemName: "heart.fill")
                    .foregroundStyle(heartColor)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: size / 2)
                    }
            }
        }
        .font(.system(size: size, weight: .bold))
        .frame(width: size, height: size)
    }
}
