//
//  FetchedPokemon.swift
//  Dex
//
//  Created by Stoyan Hristov on 18.11.25.
//

// Temporary Decodable model used only for parsing API JSON; we later map into Core Data.

import Foundation

// Decodes nested PokeAPI JSON into flat Swift properties (ids, names, types, stats, sprites).
struct FetchedPokemon: Decodable {
    // Final properties we want after decoding (names can differ from API keys).
    // Properties we want to end up with after decoding (names are our choice, not necessarily the API's).
    // Int16 is enough for IDs/stats and pairs well with Core Data integer attributes.
    let id: Int16
    let name: String
    // We will extract just the names from the nested types array (e.g., ["grass", "poison"])
    let types: [String]
    // Stats come from the `stats` array in the API; values are read in a fixed order (hp, attack, defense, special-attack, special-defense, speed).
    let hp: Int16
    let attack: Int16
    let defense: Int16
    let specialAttack: Int16
    let specialDefense: Int16
    let speed: Int16
    // We choose friendly property names in Swift
    let spriteURL: URL // URL for the front-facing sprite image (thumbnail)
    // ...and map them to API keys using CodingKeys raw values (see SpriteKeys)
    let shinyURL: URL
    
    // Key lists for each JSON level: top-level keys, nested type/stat/sprite keys.
    enum CodingKeys: CodingKey {
        // Direct top-level keys
        case id
        case name
        
        // Top-level containers that hold nested data
        case types
        case stats
        case sprites
        
        // Keys for each element in the `types` array (each element is a dictionary with a `type` field)
        enum TypeDictionaryKeys: CodingKey {
            // In the `types` array, each element has a `type` object.
            case type
            
            // Keys inside the nested `type` dictionary
            enum TypeKeys: CodingKey {
                // Inside the `type` object, we read the `name` string (e.g., "grass").
                case name
            }
        }
        
        enum StatDictionaryKeys: CodingKey {
            // Each stat item exposes `base_stat` (mapped to `baseStat`).
            case baseStat
        }
        
        // Choosing property names different from the API:
        // - Our Swift property can be named however we like (e.g., `sprite`).
        // - We then map that property to the API key by using a CodingKey with a rawValue
        //   (or by writing custom decode logic).
        // - Example below: `sprite` (our nice name) maps to API key `frontDefault`.
        enum SpriteKeys: String, CodingKey {
            // Map our friendly property names to API sprite keys.
            case spriteURL = "frontDefault" // maps to the sprites.frontDefault key
            case shinyURL = "frontShiny"
            // These raw values must match the keys inside the 'sprites' JSON object.
        }
    }
    
    // Custom decode walking through nested containers (arrays/objects) to collect values.
    // Custom init to walk through nested JSON containers.
    // Decoding flow (junior-friendly):
    // 1) `decoder.container(keyedBy: CodingKeys.self)` gives you the TOP-LEVEL JSON dictionary.
    //    Think of it like: let root = jsonObject
    // 2) From that top-level container, you can decode simple values directly with `decode(_:forKey:)`.
    // 3) When a value is nested (like arrays or dictionaries inside the root),
    //    you must create child containers:
    //       - `nestedUnkeyedContainer(forKey:)` to step into an array
    //       - `nestedContainer(keyedBy:forKey:)` to step into a nested object
    //    and then use the NESTED enums (e.g., `TypeDictionaryKeys`, `TypeKeys`) for those inner levels.
    // 4) Important: The nested enums do nothing until you actually create a nested container that is keyed by them.
    //    They just provide the list of valid keys for that level.
    // 5) About your errors: You're decoding keys like `.hp`, `.attack`, `.sprite`, etc. from the top-level keys,
    //    but `CodingKeys` doesn't currently define those cases. That's why the compiler says
    //    `Type 'FetchedPokemon.CodingKeys' has no member 'hp'`, etc. (We're not fixing it here—just explaining.)
    init(from decoder: any Decoder) throws {
        // Top-level JSON object (a dictionary) we read everything from.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int16.self, forKey: .id)
        // Read a simple top-level number.
        
        self.name = try container.decode(String.self, forKey: .name)
        // Read a simple top-level string.
        
        // Gather simple type names from the nested `types` array.
        // Collect type names from the nested 'types' array.
        var decodedTypes: [String] = []
        // Step into the 'types' array (unkeyed container).
        var typesContainer = try container.nestedUnkeyedContainer(forKey: .types)
        
        // For each array element: go element["type"]["name"].
        // Loop until we've read all type entries.
        while !typesContainer.isAtEnd {
            // Each item in 'types' is a dictionary -> use a keyed container (TypeDictionaryKeys) to access its keys (like 'type').
            let typesDictionaryContainer = try typesContainer.nestedContainer(keyedBy: CodingKeys.TypeDictionaryKeys.self)
            
            // Inside that dict, the value for key 'type' is another dict -> step in again (TypeKeys) so we can read 'name'.
            let exactTypeContainer = try typesDictionaryContainer.nestedContainer(keyedBy: CodingKeys.TypeDictionaryKeys.TypeKeys.self, forKey: .type)
            
            // Inside each item: go to ['type']['name'] to get the string.
            let type = try exactTypeContainer.decode(String.self, forKey: .name)
            // Add it to our temporary list.
            decodedTypes.append(type)
        }
        // Done collecting: set the property.
        
        // If a dual-type starts with "normal", move it to the end so the other type shows first.
        if decodedTypes.count == 2 && decodedTypes[0] == "normal" {
    // apple has a build in to swap 2 values in an array
            decodedTypes.swapAt(0, 1)
//            let tempType = decodedTypes[0]
//            decodedTypes[0] = decodedTypes[1]
//            decodedTypes[1] = tempType
        }
        self.types = decodedTypes
        
        // Collect base stats in API order (hp, attack, defense, sp. atk, sp. def, speed).
        // Collect base_stat numbers in order.
        var decodedStats: [Int16] = []
        // Step into the 'stats' array.
        var statsContainer = try container.nestedUnkeyedContainer(forKey: .stats)
        
        // Each stats element: read only `base_stat`.
        // Read each stat item.
        while !statsContainer.isAtEnd {
            let statsDictionaryContainer = try statsContainer.nestedContainer(keyedBy: CodingKeys.StatDictionaryKeys.self)
            
            // We only need the base_stat number.
            let stat = try statsDictionaryContainer.decode(Int16.self, forKey: .baseStat)
            // Keep them in the same order as the API.
            decodedStats.append(stat)
        }
        // Assign stats by their known order in the API array.
        // API guarantees the order: hp, attack, defense, special-attack, special-defense, speed.
        self.hp = decodedStats[0]
        self.attack = decodedStats[1]
        self.defense = decodedStats[2]
        self.specialAttack = decodedStats[3]
        self.specialDefense = decodedStats[4]
        self.speed = decodedStats[5]
        
        // Step into `sprites` and read frontDefault/frontShiny URLs.
        // Step into the 'sprites' object.
        let spriteContainer = try container.nestedContainer(keyedBy: CodingKeys.SpriteKeys.self, forKey: .sprites)
        
        // Use SpriteKeys to pick the right image URLs.
        self.spriteURL = try spriteContainer.decode(URL.self, forKey: .spriteURL) // Decodes the 'frontDefault' image URL
        self.shinyURL = try spriteContainer.decode(URL.self, forKey: .shinyURL)
    }
}

/*
Junior notes (extras):

- What are the stats?
  - hp: how much damage a Pokémon can take before fainting.
  - attack/defense: physical damage dealt/taken.
  - specialAttack/specialDefense: special (non-physical) damage dealt/taken.
  - speed: who acts first in turn order.

- Where do these stats come from?
  - The API returns a `stats` array. We extract `base_stat` values in order and assign them to hp/attack/etc.

- Why nested containers?
  - JSON has arrays and objects inside objects. We create nested containers to step into them and use the right keys for each level.

- What is `max` often used for in stats views?
  - Swift's max(a, b) returns the larger value.
  - In UI, `max(current, lowerBound)` ensures a minimum bar size (e.g., at least 1pt so tiny values are still visible).
  - `min(current, upperBound)` or combining with `max` caps bar length to avoid overflowing the layout.
  - These helpers don’t change the actual stat numbers—only how they are drawn.

- Best practices (quick):
  - Keep this struct Decodable-only; map to Core Data entities after decoding.
  - Validate array counts before indexing (e.g., stats count >= 6) to avoid crashes.
  - Prefer `swapAt` for swapping elements (as shown) and avoid manual temp variables.
  - Be explicit about key paths with nested containers; comment the JSON path you expect.
  - If localization/casing changes, compare case-insensitively when matching strings.
*/

