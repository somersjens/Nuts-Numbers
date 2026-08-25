//
//  PromoTrailerHostView.swift
//  Nuts & Numbers
//
//  Hosts the real ClawPlayfield at production layout scale, with HUD, captions,
//  and the final app-icon beat. Capture scales up to App Store export pixels.
//

import SwiftUI
import Combine
import QuartzCore
#if canImport(UIKit)
import UIKit
#endif

struct PromoTrailerHostView: View {
    let layoutSize: CGSize
    let exportSize: CGSize
    let usesPadMetrics: Bool
    let captureProvider: () -> UIView?
    let onFinished: (URL?) -> Void

    @StateObject private var director = PromoTrailerDirector()
    @StateObject private var model: GameViewModel
    @State private var engine: ClawEngine?
    @State private var encode = PromoEncodeState()
    @State private var displayLink: CADisplayLink?
    @State private var linkTarget: PromoDisplayLinkProxy?

    init(layoutSize: CGSize,
         exportSize: CGSize,
         usesPadMetrics: Bool,
         captureProvider: @escaping () -> UIView? = { nil },
         onFinished: @escaping (URL?) -> Void) {
        self.layoutSize = layoutSize
        self.exportSize = exportSize
        self.usesPadMetrics = usesPadMetrics
        self.captureProvider = captureProvider
        self.onFinished = onFinished
        let level = MathLevel(topic: .addition, index: 1)
        let request = GameSessionRequest(level: level, mode: .mixed)
        _model = StateObject(wrappedValue: GameViewModel(request: request))
    }

    private var character: AnimalCharacter {
        CharacterCatalog.character(id: director.characterID)
    }

    private var clawPalette: ClawPalette { ClawPalette(character: character) }
    private var topInset: CGFloat { usesPadMetrics ? 24 : 54 }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                playfield

                character.tintColor
                    .opacity(director.themeFlash * 0.28)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                hud
                    .padding(.leading, usesPadMetrics ? 8 : 4)
                    .padding(.trailing, usesPadMetrics ? 8 : 4)
                    .padding(.top, topInset - (usesPadMetrics ? 13 : 10))
                    .allowsHitTesting(false)
            }
            .blur(radius: director.backgroundBlur)
            .transaction { $0.animation = nil }

            headlineOverlay
            appIconOverlay
        }
        .frame(width: layoutSize.width, height: layoutSize.height)
        .clipped()
        .background(character.tintColor)
        .preferredColorScheme(.light)
        .ignoresSafeArea()
        .onAppear {
            UserDefaults.standard.set(true, forKey: GameSettings.onboardingCompleteKey)
            UserDefaults.standard.set(false, forKey: GameSettings.onboardingReplayRequestedKey)
            GameSettings.characterID = "elephant"
            LanguageManager.shared.override = AppLanguage.named("en")
            if !GameSettings.musicEnabled { AppAudio.shared.toggleMusic() }
            if !GameSettings.gameSoundsEnabled { AppAudio.shared.toggleGameSounds() }
            if GameSettings.spokenSumsEnabled { AppAudio.shared.toggleSpokenSums() }
            model.prepare()
            Task { await boot() }
        }
        .onDisappear {
            tearDown()
        }
    }

    private var playfield: some View {
        ClawPlayfield(
            round: model.round,
            puzzle: model.clawPuzzle,
            collectedAnswers: max(0, model.roundNumber - 1),
            collectedNutIDs: model.collectedNutIDs,
            maximumRounds: PromoTrailerScript.playfieldNutCount,
            character: character,
            isPad: usesPadMetrics,
            isLive: true,
            isRunning: true,
            playsEntrance: false,
            isStreakBoostActive: false,
            playsLevelCompletion: director.playsLevelCompletion,
            playsTimeOutFinale: false,
            reduceMotion: false,
            isFinalRound: model.roundNumber >= model.maximumRounds,
            tutorialPlan: ClawTutorialPlan(),
            score: model.cards,
            topReserve: topInset + (usesPadMetrics ? 8 : 6),
            bottomReserve: 0,
            scoreTarget: nil,
            onGrab: { nut in
                switch model.resolveGrab(nut: nut) {
                case .correct: return true
                default: return false
                }
            },
            onScoreBubbleArrived: model.scoreBubbleArrived,
            onEntranceComplete: {},
            onLevelCompletionFinished: {
                director.handleLevelCompletionFinished()
            },
            onTimeOutFinished: {},
            onTutorialEvent: { _ in },
            onEngineReady: { engine in
                let changed = self.engine !== engine
                self.engine = engine
                director.attach(engine: engine, model: model)
                if changed {
                    director.enableExternalClock()
                    if encode.recordingStarted {
                        director.resyncForRecordingStart()
                    } else {
                        director.bootstrap()
                    }
                }
            }
        )
        .id("promo-trailer-claw")
    }

    private var hud: some View {
        HStack(alignment: .top, spacing: usesPadMetrics ? 12 : 8) {
            PromoTrailerPauseBadge(isPad: usesPadMetrics, palette: clawPalette)
                .padding(.top, usesPadMetrics ? 10 : 6)
            Spacer(minLength: 0)
            ClawTimerBadge(clock: model.clock,
                           isPad: usesPadMetrics,
                           size: usesPadMetrics ? 86 : 58,
                           palette: clawPalette,
                           highlightsTutorial: false)
        }
    }

    private var headlineOverlay: some View {
        VStack {
            PromoTrailerHeadline(text: director.headlineText,
                                 theme: character,
                                 isPad: usesPadMetrics)
                .opacity(director.headlineOpacity)
                .padding(.horizontal, usesPadMetrics ? 28 : 16)
                .padding(.top, max(director.headerMaxY + (usesPadMetrics ? 10 : 6),
                                   topInset + (usesPadMetrics ? 92 : 70)))
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var appIconOverlay: some View {
        VStack {
            Spacer()
            trailerAppIcon
                .resizable()
                .interpolation(.high)
                .aspectRatio(1, contentMode: .fit)
                .frame(width: usesPadMetrics ? 280 : 210,
                       height: usesPadMetrics ? 280 : 210)
                .clipShape(RoundedRectangle(cornerRadius: usesPadMetrics ? 64 : 48,
                                            style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
                .rotationEffect(.degrees(director.iconRotation))
                .scaleEffect(director.iconScale)
                .opacity(director.iconOpacity)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    /// Marketing icon for the teaser finale. Kept next to these sources and
    /// excluded from the App Store catalog — a Display P3 1024px imageset was
    /// compiling to ~1.7 MB of unused renditions for every player.
    private var trailerAppIcon: Image {
        if let image = Self.loadTrailerAppIcon() {
            return Image(uiImage: image)
        }
        return Image("1_main")
    }

    private static func loadTrailerAppIcon() -> UIImage? {
        let besideSources = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("app_icon_clean.png")
        if let image = UIImage(contentsOfFile: besideSources.path) {
            return image
        }
        if let url = Bundle.main.url(forResource: "app_icon_clean", withExtension: "png",
                                     subdirectory: "Promo") {
            return UIImage(contentsOfFile: url.path)
        }
        return UIImage(named: "app_icon_clean")
    }

    private func boot() async {
        print("PROMO_TRAILER_BOOT")
        await model.begin()
        print("PROMO_TRAILER_BEGAN")
        for _ in 0..<20 {
            if let engine, engine.trailerPlayfieldSize.width > 0 { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        director.bootstrap()
        print("PROMO_TRAILER_BOOTSTRAPPED")
        director.enableExternalClock()
        startClock()
        try? await Task.sleep(nanoseconds: 150_000_000)
        startRecording()
    }

    private func startRecording() {
        guard !encode.recordingStarted else { return }
        encode.recordingStarted = true
        encode.isFinishing = false
        let recorder = PromoTrailerRecorder(size: exportSize,
                                            fps: PromoTrailerRuntime.framesPerSecond)
        encode.recorder = recorder
        do {
            try recorder.start()
            director.enableExternalClock()
            director.resyncForRecordingStart()
            encode.lastCaptureIndex = -1
            encode.warmupFramesRemaining = 8
            encode.pendingCaptureElapsed = nil
            encode.pendingFinish = false
            encode.recordStartDate = Date()
            print("PROMO_TRAILER_RECORDING")
        } catch {
            print("PROMO_TRAILER_ERROR \(error)")
            onFinished(nil)
        }
    }

    private func startClock() {
#if canImport(UIKit)
        guard displayLink == nil else { return }
        let encode = self.encode
        let director = self.director
        let layoutSize = self.layoutSize
        let exportSize = self.exportSize
        let captureProvider = self.captureProvider
        let onFinished = self.onFinished
        let proxy = PromoDisplayLinkProxy {
            Self.advanceEncode(encode: encode,
                               director: director,
                               layoutSize: layoutSize,
                               exportSize: exportSize,
                               captureProvider: captureProvider,
                               onFinished: onFinished,
                               stopClock: { [self] in
                                   self.displayLink?.invalidate()
                                   self.displayLink = nil
                               })
        }
        linkTarget = proxy
        let link = CADisplayLink(target: proxy, selector: #selector(PromoDisplayLinkProxy.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
#endif
    }

    private static func advanceEncode(encode: PromoEncodeState,
                                      director: PromoTrailerDirector,
                                      layoutSize: CGSize,
                                      exportSize: CGSize,
                                      captureProvider: () -> UIView?,
                                      onFinished: @escaping (URL?) -> Void,
                                      stopClock: @escaping () -> Void) {
        guard encode.recordingStarted, !encode.isFinishing else { return }

        let fps = Double(PromoTrailerRuntime.framesPerSecond)

        if encode.warmupFramesRemaining > 0 {
            encode.warmupFramesRemaining -= 1
            director.resyncForRecordingStart()
            return
        }

        let next = encode.lastCaptureIndex + 1
        let elapsed = Double(next) / fps
        if next == 0 {
            director.resyncForRecordingStart()
            director.tick(elapsed: 0)
        } else {
            director.stepSimulation(dt: 1.0 / fps)
            director.tick(elapsed: elapsed)
        }
        encode.lastCaptureIndex = next
        CATransaction.flush()
        if let image = snapshot(layoutSize: layoutSize, exportSize: exportSize,
                                captureProvider: captureProvider,
                                forceFresh: true) {
            encode.recorder?.capture(image: image, at: elapsed)
        }
        if encode.lastCaptureIndex % 30 == 0 {
            print("PROMO_TRAILER_FRAME \(encode.lastCaptureIndex)")
        }
        if director.isFinished || elapsed >= PromoTrailerRuntime.maximumDuration {
            encode.isFinishing = true
            encode.recorder?.audioCues = director.trailerAudioCues
            finishEncode(encode: encode, onFinished: onFinished, stopClock: stopClock)
        }
    }

    private static func snapshot(layoutSize: CGSize,
                                 exportSize: CGSize,
                                 captureProvider: () -> UIView?,
                                 forceFresh: Bool) -> UIImage? {
        guard let view = captureProvider() else { return nil }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let layoutImage = UIGraphicsImageRenderer(size: layoutSize, format: format).image { _ in
            view.drawHierarchy(in: CGRect(origin: .zero, size: layoutSize),
                               afterScreenUpdates: forceFresh)
        }
        if layoutSize == exportSize { return layoutImage }
        return UIGraphicsImageRenderer(size: exportSize, format: format).image { _ in
            layoutImage.draw(in: CGRect(origin: .zero, size: exportSize))
        }
    }

    private static func finishEncode(encode: PromoEncodeState,
                                     onFinished: @escaping (URL?) -> Void,
                                     stopClock: @escaping () -> Void) {
        guard encode.recordingStarted else { return }
        encode.recordingStarted = false
        stopClock()
        Task {
            let url = await encode.recorder?.finish()
            print("PROMO_TRAILER_DONE \(url?.path ?? "nil")")
            onFinished(url)
        }
    }

    private func tearDown() {
        displayLink?.invalidate()
        displayLink = nil
        encode.recordingStarted = false
        AppAudio.shared.setGameplayActive(false, questionText: nil)
        model.end()
    }
}

struct PromoTrailerPauseBadge: View {
    let isPad: Bool
    let palette: ClawPalette

    private var mount: CGFloat { isPad ? 82 : 58 }
    private var button: CGFloat { isPad ? 64 : 46 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isPad ? 7 : 5, style: .continuous)
                .fill(palette.woodDeep)
                .frame(width: mount * 0.32, height: mount * 0.38)
                .offset(y: mount * 0.43)

            RoundedRectangle(cornerRadius: isPad ? 18 : 14, style: .continuous)
                .fill(
                    LinearGradient(colors: [palette.woodLight, palette.wood, palette.woodDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: mount, height: mount)
                .overlay {
                    RoundedRectangle(cornerRadius: isPad ? 18 : 14, style: .continuous)
                        .strokeBorder(palette.woodDeep, lineWidth: isPad ? 3 : 2)
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
                .frame(width: button, height: button)
                .overlay {
                    Image(systemName: "pause.fill")
                        .font(.system(size: isPad ? 25 : 18, weight: .bold))
                        .foregroundStyle(palette.character.skyColor)
                }
        }
        .frame(width: mount, height: mount)
        .shadow(color: .black.opacity(0.42), radius: 4, y: 3)
    }
}

struct PromoTrailerInstructionBubble: View {
    let text: String
    let theme: AnimalCharacter
    var isPad: Bool

    var body: some View {
        HStack(alignment: .center, spacing: isPad ? 10 : 8) {
            theme.artwork
                .resizable()
                .scaledToFit()
                .padding(isPad ? 3 : 2)
                .frame(width: isPad ? 44 : 32, height: isPad ? 44 : 32)
                .background(theme.skyColor,
                            in: RoundedRectangle(cornerRadius: isPad ? 12 : 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: isPad ? 12 : 9, style: .continuous)
                    .stroke(theme.deepColor.opacity(0.12), lineWidth: 1))

            Text(verbatim: text)
                .font(.system(size: isPad ? 18 : 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(theme.deepColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, isPad ? 16 : 12)
        .padding(.vertical, isPad ? 10 : 8)
        .background {
            RoundedRectangle(cornerRadius: isPad ? 22 : 18, style: .continuous)
                .fill(.white.opacity(0.95))
                .overlay {
                    RoundedRectangle(cornerRadius: isPad ? 22 : 18, style: .continuous)
                        .stroke(.white, lineWidth: 2)
                }
                .shadow(color: theme.deepColor.opacity(0.22), radius: 10, y: 5)
        }
        .frame(maxWidth: isPad ? 560 : 360)
    }
}

struct PromoTrailerHeadline: View {
    let text: String
    let theme: AnimalCharacter
    var isPad: Bool

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: isPad ? 26 : 18, weight: .heavy, design: .rounded))
            .foregroundStyle(theme.deepColor)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, isPad ? 18 : 14)
            .padding(.vertical, isPad ? 10 : 7)
            .background {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.94))
                    .shadow(color: theme.deepColor.opacity(0.18), radius: 8, y: 4)
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(theme.skyColor.opacity(0.85), lineWidth: 1.5)
            }
            .opacity(text.isEmpty ? 0 : 1)
    }
}

final class PromoEncodeState {
    var recordingStarted = false
    var isFinishing = false
    var recorder: PromoTrailerRecorder?
    var recordStartDate: Date?
    var lastCaptureIndex: Int64 = -1
    var warmupFramesRemaining = 0
    var pendingCaptureElapsed: TimeInterval?
    var pendingFinish = false
    var openPoseHold = false
}

#if canImport(UIKit)
final class PromoDisplayLinkProxy: NSObject {
    private let handler: () -> Void
    init(handler: @escaping () -> Void) { self.handler = handler }
    @objc func tick() { handler() }
}
#endif
