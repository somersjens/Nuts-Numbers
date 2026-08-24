//
//  AnimalHabitats.swift
//  Nuts & Numbers
//
//  Routes each character to its own habitat scene. Every environment lives in
//  Habitats/ and is drawn entirely from paths, curves and gradients on a
//  SwiftUI Canvas, at the same level of finish as the elephant sanctuary in
//  ClawGame.swift. The moving layer is supplied separately by
//  AnimalHabitatLivingDetails so the static artwork can stay Equatable and
//  redraw only when the character or the cabinet size changes.
//

import SwiftUI

struct AnimalHabitatArtwork: View, Equatable {
    let palette: ClawPalette
    let character: AnimalCharacter
    let isPad: Bool

    var body: some View {
        Group {
            switch AnimalHabitatKind(characterID: character.id) {
            case .octopus:
                OctopusReefHabitatArtwork(palette: palette, character: character, isPad: isPad)
            case .crab:
                CrabShoreHabitatArtwork(palette: palette, character: character, isPad: isPad)
            case .bear:
                BearForestHabitatArtwork(palette: palette, character: character, isPad: isPad)
            case .fox:
                FoxForestHabitatArtwork(palette: palette, character: character, isPad: isPad)
            case .frog:
                FrogPondHabitatArtwork(palette: palette, character: character, isPad: isPad)
            case .penguin:
                PenguinIceHabitatArtwork(palette: palette, character: character, isPad: isPad)
            case .bunny:
                BunnyMeadowHabitatArtwork(palette: palette, character: character, isPad: isPad)
            case .dog:
                DogAgilityHabitatArtwork(palette: palette, character: character, isPad: isPad)
            case .lion:
                LionSavannaHabitatArtwork(palette: palette, character: character, isPad: isPad)
            }
        }
        .accessibilityHidden(true)
    }
}
