//
//  PokemonExt.swift
//  Dex
//
//  Created by Stoyan Hristov on 23.11.25.
//

// Adds convenience, UI-facing computed properties to the Core Data model (Pokemon).

import SwiftUI

// Extend the generated Core Data class with read-only helpers for the UI.

extension Pokemon {
    
    // sprite is a Core Data attribute of type Data? that stores the raw bytes of the normal sprite image.
    // In the if-let below, `let data = sprite` creates a local constant named `data` from that attribute.
    var spriteImage: Image {
        if let data = sprite, let image = UIImage(data: data) {
            Image(uiImage: image)
        } else {
            Image(.bulbasaur)
        }
    }
    
    var shinyImage: Image {
        if let data = shiny, let image = UIImage(data: data) {
            Image(uiImage: image)
        } else {
            Image(.shinybulbasaur)
        }
    }
    
    // Provides an ImageResource based on the Pokémon's primary type.
    // The `types` property is optional and force-unwrapped here for brevity.
    // ImageResource is derived from typed asset names corresponding to grouped types.
    var background: ImageResource {
        switch types![0] {
        case "rock", "ground", "steel", "fighting", "ghost", "dark", "psychic":
                .rockgroundsteelfightingghostdarkpsychic
        case "fire", "dragon":
                .firedragon
        case "flying", "bug":
                .flyingbug
        case "ice":
                .ice
        case "water":
                .water
        default:
                .normalgrasselectricpoisonfairy
        }
    }
    
    // Builds a Color from an asset named after the capitalized first type string.
    // This depends on a matching color asset existing in the asset catalog.
    var typeColor: Color {
        Color(types![0].capitalized)
    }
    
    // The Core Data model stores raw numeric stat values but not their display names or order.
    // This computed property builds a UI-ready array pairing each stat's name with its value, in a fixed order.
    var stats: [Stat] {
        [
        Stat(id: 1, name: "HP", value: hp),
        Stat(id: 2, name: "Attack", value: attack),
        Stat(id: 3, name: "Defense", value: defense),
        Stat(id: 4, name: "Special Attack", value: specialAttack),
        Stat(id: 5, name: "Special Defense", value: specialDefense),
        Stat(id: 6, name: "Speed", value: speed)
        ]
    }
    
    // Finds the highest stat by using max(by:) with a closure comparing values.
    // Force-unwrapping is safe here because the array always contains all six stats,
    // but in general, max(by:) returns an optional in case of an empty array.
    var highestStat: Stat {
//        stats.max { stat1, stat2 in
        // in fucntinos like this swift creates a property names for us $0, %1
        stats.max {$0.value < $1.value }!
    }
}

// A lightweight UI model conforming to Identifiable to support SwiftUI lists.
struct Stat: Identifiable {
    let id: Int16
    let name: String
    let value: Int16
}


//////////////////////////////////////////////////////////////////
// Explanation: max(by:) and $0/$1
//
// The max(by:) function returns the element with the highest value
// based on the comparison closure you provide. The closure takes two
// elements, commonly referenced as $0 and $1, and returns true if
// the first element should be ordered before the second.
// It returns an optional because the array might be empty.
//
// Notes on Core Data & computed properties:
//
// The properties here are computed-only: they are not stored or
// persisted in Core Data. They are recalculated each time they are
// accessed, which is fine for inexpensive logic like this.
//
// Best practices:
//
// - Avoid force-unwrapping optionals like types!; prefer safe access or defaults.
// - Consider using an enum or descriptors to avoid stringly-typed switches
//   and repeated stat definitions.
// - Keep display strings localizable rather than hardcoded.
// - Validate that asset names (color, images) exist to avoid runtime errors.
// - If the stats array could be empty, return an optional for highestStat.
//
//////////////////////////////////////////////////////////////////

// Junior quick notes (concise)
// - Where does `data` come from in `if let data = sprite`?
//   • `sprite` is a Data? attribute on Pokemon saved in Core Data (bytes of the image). `data` is just a local constant bound to it.
// - What do stats mean?
//   • hp (durability), attack/defense (physical), specialAttack/specialDefense (special), speed (turn order).
// - What does max(by:) do here?
//   • Picks the Stat with the largest `value` so charts/layouts can size to the biggest number.
// - Best practices
//   • Prefer safe optionals (avoid force unwraps), validate assets, and consider enums for types.
//   • If stats could be empty, make `highestStat` optional or provide a default.
