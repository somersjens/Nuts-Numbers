//
//  HabitatGalleryQAView.swift
//  Nuts & Numbers
//
//  Debug harness for comparing every cabinet against the elephant sanctuary,
//  which is the quality bar the other habitats are held to. Launch the app
//  with -HabitatGalleryQA to open it.
//

#if DEBUG
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HabitatGalleryQAView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showMotion = true
    @State private var columns = Int(ProcessInfo.processInfo.environment["HABITAT_QA_COLUMNS"] ?? "") ?? 2

    private let order = ["elephant", "octopus", "crab", "bear", "fox",
                         "frog", "penguin", "bunny", "dog", "lion"]

    var body: some View {
        GeometryReader { geo in
            let isPad = geo.size.width > 700
            let across = max(1, columns)
            let spacing: CGFloat = 12
            let cellWidth = (geo.size.width - spacing * CGFloat(across + 1)) / CGFloat(across)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellWidth), spacing: spacing),
                                         count: across),
                          spacing: spacing) {
                    ForEach(order, id: \.self) { id in
                        cabinet(characterID: id, width: cellWidth, isPad: isPad)
                    }
                }
                .padding(spacing)
            }
            .background(Color.black)
            .safeAreaInset(edge: .bottom) { controls }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear { exportSnapshotsIfRequested() }
    }

    private func exportSnapshotsIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-HabitatGalleryExport") else { return }
#if canImport(UIKit)
        let dest = URL(fileURLWithPath: "/Users/jenssomers/Desktop/Nuts & Numbers/.habitatcheck")
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let width: CGFloat = 390
        for id in order {
            let view = cabinet(characterID: id, width: width, isPad: false)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            if let image = renderer.uiImage, let data = image.pngData() {
                try? data.write(to: dest.appendingPathComponent("qa_\(id).png"))
            }
        }
#endif
    }

    private func cabinet(characterID: String, width: CGFloat, isPad: Bool) -> some View {
        let character = CharacterCatalog.character(id: characterID)
        let palette = ClawPalette(character: character)
        // Matches the play area's proportions closely enough that composition
        // problems show up here rather than only in the game.
        let height = width * 1.36

        return VStack(spacing: 4) {
            ZStack {
                if characterID == "elephant" {
                    SavannaHabitatArtwork(palette: palette, character: character, isPad: isPad)
                } else {
                    AnimalHabitatArtwork(palette: palette, character: character, isPad: isPad)
                }
                if showMotion {
                    AnimalHabitatLivingDetails(characterID: characterID,
                                               isPad: isPad,
                                               reduceMotion: reduceMotion)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(characterID)
                .font(.caption2.monospaced())
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Toggle("Motion", isOn: $showMotion)
                .toggleStyle(.button)
            Stepper("Columns \(columns)", value: $columns, in: 1...4)
        }
        .font(.footnote)
        .padding(10)
        .background(.ultraThinMaterial)
        .foregroundStyle(.white)
    }
}
#endif
