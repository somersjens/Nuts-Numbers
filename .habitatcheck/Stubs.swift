import SwiftUI

struct AnimalCharacter: Equatable {
    let id: String
    var deepColor: Color { .blue }
}

struct ClawPalette: Equatable {
    let character: AnimalCharacter
}
