//
//  FetchedPokemon.swift
//  Dex
//
//  Created by Stoyan Hristov on 18.11.25.
//

// we use this model as (struct) because CoreData is not decodable and we need decodable when we fetch our pokemons from API
// core data is still there because we need to relunch our app with memory

/*
 Junior-friendly overview:
 - This struct is a temporary, Decodable model used only to parse the API JSON.
 - We decode from a nested JSON structure into our flat properties.
 - `CodingKeys` describe keys at each JSON level; nested enums describe keys inside nested objects/arrays.
*/

import Foundation

struct FetchedPokemon: Decodable {
    // Properties we want to end up with after decoding (names are our choice, not necessarily the API's).
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
    // Mapped from sprites.frontDefault
    let sprite: URL
    // Mapped from sprites.frontShiny
    let shiny: URL
    
    // Why nested enums?
    // - Each `CodingKey` enum represents the keys for ONE level of the JSON.
    // - The top-level `CodingKeys` is used to read keys that live directly on the root JSON object (e.g. "id", "name", "types", "stats", "sprites").
    // - The nested enums (like `TypeDiction` and `TypeKeys`) are NOT magic; they don't fetch anything by themselves.
    //   They are just namespaced lists of keys we can use when we explicitly descend into nested containers.
    // - We descend by creating child containers:
    //     * `nestedContainer(keyedBy:forKey:)` for a nested dictionary/object
    //     * `nestedUnkeyedContainer(forKey:)` for a nested array
    // - Example for the PokeAPI `types` field (based on the screenshot):
    //     root["types"] -> array -> element["type"] -> object -> object["name"] -> string
    //   To decode that, you would:
    //     1) make an unkeyed container for `types` (the array)
    //     2) for each item, make a keyed container using `TypeDictionaryKeys` (to access the `type` key)
    //     3) inside that, make another keyed container using `TypeKeys` (to access `name`)
    // - So: nested enums are just the key lists you use at each step when you go deeper.
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
            // e.g. element["type"] -> { name: "grass" }
            case type
            
            // Keys inside the nested `type` dictionary
            enum TypeKeys: CodingKey {
                // e.g. element["type"]["name"] -> "grass"
                case name
            }
        }
        
        enum StatDictionaryKeys: CodingKey {
            // We only need the number at key `base_stat` (converted from snake_case)
            case baseStat
        }
        
        // String rawValue lets us map our case names to different JSON key names (e.g., we want `sprite` and `shiny` in code, but the API uses `frontDefault` and `frontShiny`).
        enum SpriteKeys: String,CodingKey {
            // Our case names (sprite/shiny) are nicer; raw values point to the actual API keys
            case sprite = "frontDefault"
            case shiny = "frontShiny"
        }
    }
    
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
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `container` is the root JSON dictionary.
        // Example path for types in the PokeAPI:
        //   container[.types] -> (array)
        //   array element -> keyed container (TypeDictionaryKeys) -> key `.type`
        //   inside `.type` -> keyed container (TypeKeys) -> key `.name` (e.g., "grass")
        // Note: To actually walk that path you would use nested containers, e.g.:
        //   var typesArray = try container.nestedUnkeyedContainer(forKey: .types)
        //   while !typesArray.isAtEnd {
        //       let typeDict = try typesArray.nestedContainer(keyedBy: CodingKeys.TypeDictionaryKeys.self)
        //       let inner = try typeDict.nestedContainer(keyedBy: CodingKeys.TypeDictionaryKeys.TypeKeys.self, forKey: .type)
        //       let name = try inner.decode(String.self, forKey: .name)
        //       // collect `name`
        //   }
        // (We're not changing functionality—just showing the idea.)
        
        // Read simple top-level values
        self.id = try container.decode(Int16.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        
        // NOTE: Placeholder decode; actual data lives deeper (types -> [element] -> type -> name)
        self.types = try container.decode([String].self, forKey: .types)
        
        // NOTE: Placeholder decodes; real values come from stats array (base_stat per entry)
        self.hp = try container.decode(Int16.self, forKey: .hp)
        self.attack = try container.decode(Int16.self, forKey: .attack)
        self.defense = try container.decode(Int16.self, forKey: .defense)
        self.specialAttack = try container.decode(Int16.self, forKey: .specialAttack)
        self.specialDefense = try container.decode(Int16.self, forKey: .specialDefense)
        
        // NOTE: Placeholder decodes; real values come from sprites object (frontDefault/frontShiny)
        self.sprite = try container.decode(URL.self, forKey: .sprite)
        self.shiny = try container.decode(URL.self, forKey: .shiny)
    }
}

