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
    let sprite: URL
    // ...and map them to API keys using CodingKeys raw values (see SpriteKeys)
    let shiny: URL
    
    // Why nested enums?
    // - Each `CodingKey` enum represents the keys for ONE level of the JSON.
    // - The top-level `CodingKeys` is used to read keys that live directly on the root JSON object (e.g. "id", "name", "types", "stats", "sprites").
    // - The nested enums (like `TypeDiction` and `TypeKeys`) are NOT magic; they don't fetch anything by themselves.
    //   They are just namespaced lists of keys we can use when we explicitly descend into nested containers.
    // - We descend by creating child containers:
    //     * `nestedContainer(keyedBy:forKey:)` for a nested dictionary/object
    //     * `nestedUnkeyedContainer(forKey:)` for a nested array
    // - Example for the PokeAPI `types` field
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
        
        // Choosing property names different from the API:
        // - Our Swift property can be named however we like (e.g., `sprite`).
        // - We then map that property to the API key by using a CodingKey with a rawValue
        //   (or by writing custom decode logic).
        // - Example below: `sprite` (our nice name) maps to API key `frontDefault`.
        enum SpriteKeys: String, CodingKey {
            // Our case names (sprite/shiny) are nicer; raw values point to the actual API keys
            case sprite = "frontDefault"
            case shiny = "frontShiny"
            // These raw values must match the keys inside the 'sprites' JSON object.
        }
    }
    
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
        
        // Collect type names from the nested 'types' array.
        var decodedTypes: [String] = []
        // Step into the 'types' array (unkeyed container).
        var typesContainer = try container.nestedUnkeyedContainer(forKey: .types)
        
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
        self.types = decodedTypes
        
        // Collect base_stat numbers in order.
        var decodedStats: [Int16] = []
        // Step into the 'stats' array.
        var statsContainer = try container.nestedUnkeyedContainer(forKey: .stats)
        
        // Read each stat item.
        while !statsContainer.isAtEnd {
            let statsDictionaryContainer = try statsContainer.nestedContainer(keyedBy: CodingKeys.StatDictionaryKeys.self)
            
            // We only need the base_stat number.
            let stat = try statsDictionaryContainer.decode(Int16.self, forKey: .baseStat)
            // Keep them in the same order as the API.
            decodedStats.append(stat)
        }
        // API guarantees the order: hp, attack, defense, special-attack, special-defense, speed.
        self.hp = decodedStats[0]
        self.attack = decodedStats[1]
        self.defense = decodedStats[2]
        self.specialAttack = decodedStats[3]
        self.specialDefense = decodedStats[4]
        self.speed = decodedStats[5]
        
        // Step into the 'sprites' object.
        let spriteContainer = try container.nestedContainer(keyedBy: CodingKeys.SpriteKeys.self, forKey: .sprites)
        
        // Use SpriteKeys to pick the right image URLs.
        self.sprite = try spriteContainer.decode(URL.self, forKey: .sprite)
        self.shiny = try spriteContainer.decode(URL.self, forKey: .shiny)
    }
}

