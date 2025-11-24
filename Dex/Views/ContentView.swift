//
//  ContentView.swift
//  Dex
//
//  Created by Stoyan Hristov on 17.11.25.
//

// Junior guide (overview):
// Lists Pokémon from Core Data, supports search/favorites, navigates to detail, and fetches from network.

import SwiftUI
import CoreData

/*
 SwiftUI Environment + FetchRequest (mental model):
 - Environment: shared values flowing down the view tree. Inject at the top, read with @Environment.
 - managedObjectContext: Core Data context for fetch/insert/delete; call save() to persist.
 - @FetchRequest: live query that updates when the context changes.
 - NavigationStack: pushes screens; navigationDestination builds destinations for a given type.
 */

// Main screen showing the list and fetch actions.
struct ContentView: View {
    // Core Data context from the environment (main queue). Use to read/write, then call save().
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var searchText = "" // Search bar text.
    @State private var filterByFavorites = false // When true, show only favorites.
    
    init() {
        // Explicit init kept for potential future setup (no params passed).
    }
    
    // Live Core Data results; auto-updates on saves. Sorted by id ascending.
    @FetchRequest<Pokemon>(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pokemon.id, ascending: true)],
        predicate: nil,
        animation: .default
    ) private var pokedex
    
    // Helper fetch (no sort) for empty-state checks and total count.
    @FetchRequest<Pokemon>(sortDescriptors: [],animation: .default) private var allPokedexInDB
    
    // Simple networking helper for the Pokémon API.
    let fetcher = FetchService()
    
    // Builds a predicate from search text + favorites toggle. Empty => no filters.
    private var dynamicPredicate: NSPredicate {
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
        
        if allPokedexInDB.isEmpty {
            // Empty state when DB has zero Pokémon.
            ContentUnavailableView {
                Label("No Pokemon", image: .nopokemon)
            } description: {
                Text("There aren't any Pokemon yet.\nFetch some Pokemon to get started! ")
            } actions: {
                Button("Fetch pokemon", systemImage: "antenna.radiowaves.left.and.right") {
                    getPokemon(from: 1)
                }
                .buttonStyle(.borderedProminent)
            }

        } else {
            // Navigation container for list + detail.
            NavigationStack {
                // Lazily rendered list of Pokémon.
                List {
                    Section {
                        ForEach(pokedex) { pokemon in
                            // Value-based navigation to detail.
                            NavigationLink (value: pokemon) {
                                // Async image per row with placeholder.
                                AsyncImage(url: pokemon.sprite) {image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 100, height: 100)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(pokemon.name!.capitalized)
                                            .fontWeight(.bold)
                                        
                                        if pokemon.favorite {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                        }
                                    }
                                    
                                    // Type chips using Color assets (e.g., "Fire").
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
                            // Swipe to toggle favorite, then save.
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
                            // Secondary hint when fewer than 151 Pokémon exist.
                            ContentUnavailableView {
                                Label("Missing Pokemon", image: .nopokemon)
                            } description: {
                                Text("The fetch was imterrupted!\n Fetch the rest of the pokemon.")
                            } actions: {
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
                .navigationTitle("Pokedex")
                .navigationDestination(for: Pokemon.self, destination: { pokemon in
                    PokemonDetail()
                        .environmentObject(pokemon)
                })
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            filterByFavorites.toggle()
                        } label: {
                            Label("Filter By Favorites", systemImage: filterByFavorites ? "star.fill" : "star")
                        }
                        .tint(.yellow)
                    }
                }
                .searchable(text: $searchText, placement: SearchFieldPlacement.navigationBarDrawer, prompt: "Find a Pokemon")
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
    
    // MARK: - Data loading
    // Fetches Pokémon 1...151 and saves them to Core Data (simple sequential demo).
    private func getPokemon(from id: Int) {
        // Heads-up: 'id' currently unused; loop always starts at 1.
        Task {
            for i in 1..<152 {
                do {
                    let fetchedPokemon = try await fetcher.fetchPokemon(i)
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
                    pokemon.sprite = fetchedPokemon.sprite
                    pokemon.shiny = fetchedPokemon.shiny
                    try viewContext.save()
                } catch {
                    print(error)
                }
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
 */
