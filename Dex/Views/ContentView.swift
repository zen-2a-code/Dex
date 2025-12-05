//
//  ContentView.swift
//  Dex
//
//  Created by Stoyan Hristov on 17.11.25.
//

// Junior-friendly: Main list screen (Pokédex). Reads from Core Data with @FetchRequest, lets you search, filter favorites, and navigate to details.

// This view lists Pokémon from Core Data, lets you search/filter, and can fetch from the network.

import SwiftUI
import CoreData
// Core Data provides persistent storage; we read/write Pokémon here.

/*
 SwiftUI Environment + FetchRequest (mental model):
 - Environment: shared values flowing down the view tree. Inject at the top, read with @Environment.
 - managedObjectContext: Core Data context for fetch/insert/delete; call save() to persist.
 - @FetchRequest: live query that updates when the context changes.
 - NavigationStack: pushes screens; navigationDestination builds destinations for a given type.
 */

// ContentView is the main screen that shows the Pokédex list and actions.
struct ContentView: View {
    // The Core Data context (like a workspace) for reading/writing Pokémon.
    @Environment(\.managedObjectContext) private var viewContext
    
    // UI state for search text and favorites filter.
    @State private var searchText = "" // Search bar text.
    @State private var filterByFavorites = false // When true, show only favorites.
    
    init() {
        // Explicit init kept for potential future setup (no params passed).
    }
    
    // Live query of Pokémon sorted by id; updates when context saves.
    @FetchRequest<Pokemon>(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pokemon.id, ascending: true)],
        predicate: nil,
        animation: .default
    ) private var pokedex
    
    // Helper fetch to check if the database is empty and count total items.
    @FetchRequest<Pokemon>(sortDescriptors: [],animation: .default) private var allPokedexInDB
    
    // Simple network service that fetches Pokémon by id.
    let fetcher = FetchService()
    
    // Builds a filter from search text and favorites toggle; empty means no filter.
    private var dynamicPredicate: NSPredicate {
        // Combine optional filters with AND (name contains, favorite == true).
        var predicates: [NSPredicate] = []
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "name contains[c] %@",  searchText))
        }
        if filterByFavorites {
            predicates.append(NSPredicate(format: "favorite == %d", true))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    var body: some View {
        // Show an empty state when no Pokémon exist; otherwise show the list with navigation.
        
        if allPokedexInDB.isEmpty {
            // System empty-state view with title, description, and a fetch button.
            ContentUnavailableView {
                Label("No Pokemon", image: .nopokemon)
            } description: {
                Text("There aren't any Pokemon yet.\nFetch some Pokemon to get started! ")
            } actions: {
                // Triggers fetching the first 151 Pokémon.
                Button("Fetch pokemon", systemImage: "antenna.radiowaves.left.and.right") {
                    getPokemon(from: 1)
                }
                .buttonStyle(.borderedProminent)
            }

        } else {
            // Container that manages navigation between list and detail views.
            NavigationStack {
                // Lazy list of Pokémon rows.
                List {
                    Section {
                        // `pokedex` is a FetchedResults<Pokemon> from @FetchRequest (live Core Data query that auto-updates on save()).
                        ForEach(pokedex) { pokemon in
                            // Tap to navigate to the detail screen for this Pokémon.
                            NavigationLink (value: pokemon) {
                                // Loads the sprite image asynchronously with a placeholder.
                                
                                if pokemon.sprite == nil {
                                    AsyncImage(url: pokemon.spriteURL) {image in
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 100, height: 100)
                                } else {
                                    pokemon.spriteImage
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                }
                                
                                // Name and favorite star indicator.
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(pokemon.name!.capitalized)
                                            .fontWeight(.bold)
                                        
                                        if pokemon.favorite {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                        }
                                    }
                                    
                                    // Type chips (colored capsules) based on type names.
                                    HStack {
                                        ForEach(pokemon.types!, id: \.self) { type in
                                            Text (type.capitalized)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.black)
                                                .padding(.vertical, 5)
                                                .padding(.horizontal, 13)
                                                .background(Color(type.capitalized))
                                                .clipShape(.capsule)
                                        }
                                    }
                                }
                            }
                            // Swipe to add/remove favorite and save the change.
                            .swipeActions (edge: .leading){
                                Button(pokemon.favorite ? "Remove from Favorites" : "Add to Favorites", systemImage: "star") {
                                    pokemon.favorite.toggle()
                                    
                                    do {
                                        try viewContext.save()
                                    } catch {
                                        print(error)
                                    }
                                }
                                .tint(pokemon.favorite ? .gray : .yellow)
                            }
                        }
                    } footer: {
                        if allPokedexInDB.count < 151 {
                            // Hint to resume fetching if the initial load didn’t complete.
                            ContentUnavailableView {
                                Label("Missing Pokemon", image: .nopokemon)
                            } description: {
                                Text("The fetch was imterrupted!\n Fetch the rest of the pokemon.")
                            } actions: {
                                // Attempts to continue fetching from the next id (simple resume).
                                Button("Fetch pokemon", systemImage: "antenna.radiowaves.left.and.right") {
                                    // Note: Using pokedex.count + 1 to resume is fragile; getPokemon(from:) ignores the parameter.
                                    getPokemon(from: pokedex.count + 1)
                                }
                                .buttonStyle(.borderedProminent)
                            }

                        }
                    }
                    // .task { getPokemon() } // Best for PROD; commented to demo empty state.
                }
                // Declares how to build the destination view for a selected Pokémon.
                .navigationTitle("Pokedex")
                .navigationDestination(for: Pokemon.self, destination: { pokemon in
                    PokemonDetail()
                        .environmentObject(pokemon)
                })
                .toolbar {
                    // Toggle to filter by favorites only.
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            filterByFavorites.toggle()
                        } label: {
                            Label("Filter By Favorites", systemImage: filterByFavorites ? "star.fill" : "star")
                        }
                        .tint(.yellow)
                    }
                }
                // Search and filters: we rebuild the NSFetchRequest predicate as you type/toggle, causing Core Data to refetch efficiently.
                // Search bar that filters by name (case-insensitive).
                .searchable(text: $searchText, placement: SearchFieldPlacement.navigationBarDrawer, prompt: "Find a Pokemon")
                // Update the fetch request’s predicate whenever filters change.
                .onChange(of: searchText) { _, _ in
                    pokedex.nsPredicate = dynamicPredicate
                }
                .onChange(of: searchText) {
                    pokedex.nsPredicate = dynamicPredicate
                }
                .onChange(of: filterByFavorites) {
                    pokedex.nsPredicate = dynamicPredicate
                }
            }
        }
    }
    
    // Fetch 1..151 Pokémon from the API and save them to Core Data (sequential demo).
    private func getPokemon(from id: Int) {
        // Heads-up: 'id' currently unused; loop always starts at 1.
        Task {
            // Simple sequential loop; in production you might batch or parallelize requests.
            for i in 1..<152 {
                do {
                    // Fetch a single Pokémon’s data from the network.
                    let fetchedPokemon = try await fetcher.fetchPokemon(i)
                    // Map the fetched fields into a new Core Data `Pokemon` object.
                    let pokemon = Pokemon(context: viewContext)
                    pokemon.id = fetchedPokemon.id
                    pokemon.name = fetchedPokemon.name
                    pokemon.types = fetchedPokemon.types
                    pokemon.hp = fetchedPokemon.hp
                    pokemon.attack = fetchedPokemon.attack
                    pokemon.defense = fetchedPokemon.defense
                    pokemon.specialAttack = fetchedPokemon.specialAttack
                    pokemon.specialDefense = fetchedPokemon.specialDefense
                    pokemon.speed = fetchedPokemon.speed
                    pokemon.spriteURL = fetchedPokemon.spriteURL
                    pokemon.shinyURL = fetchedPokemon.shinyURL
                    
                    // Persist the new/updated object to disk.
                    try viewContext.save()
                } catch {
                    print(error)
                }
                storeSprites()
            }
        }
    }
    
    private func storeSprites() {
        Task {
            do {
                for pokemon in allPokedexInDB {
                    pokemon.sprite = try await URLSession.shared.data(from: pokemon.spriteURL!).0 // .data(from:) returns (Data, URLResponse); .0 picks the downloaded Data
                    pokemon.shiny = try await URLSession.shared.data(from: pokemon.shinyURL!).0 // Same tuple: .0 is the Data bytes; .1 would be the URLResponse
                    
                    try viewContext.save()
                    
                    print("Sprites Stored \(pokemon.id): \(pokemon.name!.capitalized)")
                }
            } catch {
                print(error)
            }
        }
    }
}

// Preview injects an in-memory Core Data context for safe UI testing.
#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

/*
 Junior notes (deep dive, full content moved from inline comments):
 
 1) SwiftUI environment + Core Data context
 - The view reads a managedObjectContext from the environment.
 - Think of it as a scratchpad for reads/writes; call save() to persist changes to disk.
 - The default viewContext uses the main queue; use it on the main actor.
 - Long operations should keep the UI responsive; consider batching saves.
 
 2) @FetchRequest mental model
 - It's a live query. When the context changes and you save, the list updates automatically.
 - You can change its filter at runtime by setting pokedex.nsPredicate.
 - sortDescriptors keep a stable order (here by id ascending = Pokédex order).
 - animation: .default lets SwiftUI animate insertions/removals.
 - FetchedResults behaves like an array of managed objects.
 
 3) Predicates and search
 - dynamicPredicate builds an AND of filters. Empty search => no filters (show all).
 - NSPredicate(format: "name contains[c] %@", searchText) is case-insensitive.
 - Updating nsPredicate triggers Core Data to refetch efficiently.
 - For large datasets, consider debouncing the search input to avoid refetching on every keystroke.
 
 4) Navigation (value-based)
 - NavigationLink(value:) pushes a value onto NavigationStack.
 - navigationDestination(for: Pokemon.self) tells how to build the detail for that value type.
 - This is type-safe and testable. The tapped object flows into the destination closure.
 
 5) Images and type chips
 - AsyncImage downloads and draws the sprite; ProgressView shows while loading.
 - .scaledToFit inside a fixed frame keeps aspect ratio.
 - Type chips use Color assets named after the type (e.g., "Fire"). Ensure these assets exist.
 
 6) Toolbar actions
 - Add: downloads Pokémon and saves them to Core Data.
 - EditButton toggles list edit mode.
 
 7) Networking + saving (current approach)
 - Simple loop fetches ids 1...151 sequentially.
 - After mapping fields into a new Pokemon object, save() persists it.
 - Easy to read, but slow and can duplicate data.
   Tips for production:
   - Add a unique constraint on id to avoid duplicates (Core Data model setting).
   - Batch work: insert many objects, then call save() once.
   - Consider a background context for heavy inserts to avoid blocking the main thread.
   - Show progress and handle errors in the UI.
 
 8) Safety notes
 - name and types are force-unwrapped in the UI. Safer: guard or provide defaults.
 - Color(type) assumes an asset exists. Provide a fallback if missing.
 
 9) Performance tips for Core Data
 - Add indexes for 'id' and 'name' if you filter/sort by them.
 - Use fetchBatchSize for large lists.
 - Keep row views light; avoid heavy work in List rows.
 
 10) Concurrency gotcha
 - viewContext is main-queue. Saving from a Task should run on the main actor.
 - If you move saving off the main thread, use a background context instead.
 
 11) Previews
 - The preview injects an in-memory Core Data stack, so the UI runs without touching disk data.
 
 - Duplicate protection: Add a unique constraint on 'id' in the Core Data model to avoid duplicates.
 
 Additional  notes:
 - NavigationStack manages a stack of screens and builds destinations lazily when navigating.
 - List rows are created on demand as they appear on screen; keep thumbnails small for smooth scrolling.
 - The footer "resume" button is illustrative; getPokemon(from:) currently ignores its parameter, so true resume would require changes.
 - Images in lists: keep frames small to avoid jank; large images can hurt scrolling performance.
 - Force unwraps are kept for demo simplicity; consider safe handling in production.
 - ContentUnavailableView is used as the system empty state pattern (title, description, actions).
 - Using pokedex.count + 1 for resume assumes no gaps; fragile without constraints.
 - AsyncImage starts loading when the row appears (lazy per-row fetch).
 - Destinations are created on-demand when a link is activated, not all at once.
 - FetchedResults returns faults; properties load on access.
 
 Junior notes (extras):
 - What are the stats?
   - hp: how much damage a Pokémon can take before fainting.
   - attack/defense: physical damage dealt/taken.
   - specialAttack/specialDefense: special (non-physical) damage dealt/taken.
   - speed: who acts first in battle turns.
   - Note: There's no max() used here. If you see Swift's max(a, b) elsewhere, it just returns the larger value.
 - Best practices (quick and practical):
   - Avoid force unwraps (`!`) for optionals in production UI; provide safe defaults or guard.
   - Batch inserts and save less often to improve performance.
   - Do heavy writes on a background context; keep the main viewContext responsive.
   - Add a unique constraint on `Pokemon.id` in the model to prevent duplicates.
   - Debounce search to reduce frequent refetches while typing.
   - Consider caching images to avoid re-downloading.
   - If using the main context, do saves on the main actor; mark long operations with `@MainActor` or hop to the main actor before saving.
   - Use Core Data fetchBatchSize/indexes for large lists.
 
 - Stats recap (junior):
   • hp (durability), attack/defense (physical), specialAttack/specialDefense (special), speed (turn order).
   • `max(by:)` (used in PokemonExt.highestStat) returns the Stat with the greatest `value` to size charts/limits.
 - Best practices (short):
   • Avoid force unwraps in UI; use defaults or guards.
   • Add a unique constraint on Pokemon.id to prevent duplicates.
   • Batch inserts and save less often; consider a background context for heavy writes.
   • Debounce search to avoid frequent refetches while typing.
 */
