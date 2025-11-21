//
//  ContentView.swift
//  Dex
//
//  Created by Stoyan Hristov on 17.11.25.
//

// Junior guide:
// This screen shows a list of Pokémon stored in Core Data.
// It demonstrates: reading Core Data with @FetchRequest, showing a list, navigating with NavigationStack,
// and saving data fetched from the network.

import SwiftUI
import CoreData

/*
 SwiftUI Environment + FetchRequest (junior-friendly mental model):
 - Environment: a shared bucket of values flowing down the view tree. Inject at the top, read with @Environment.
 - managedObjectContext: Core Data context used to fetch/insert/delete, then call save() to persist.
 - @FetchRequest: live query. Keeps results updated automatically when the context changes.
 - Navigation: NavigationStack shows a stack of screens. NavigationLink pushes a value, and
   .navigationDestination(for:Type) tells SwiftUI how to build a screen for that value type.
 */

// Main screen that lists Pokémon and lets you fetch them.
struct ContentView: View {
    // Core Data context (injected from the app). Think of it like a scratchpad for reads/writes, then call save().
    @Environment(\.managedObjectContext) private var viewContext // Provided by the app at launch; we read it here instead of creating our own.
    
    @State private var searchText = ""
    // User's text from the search bar. Changing this will re-filter the list.
    @State private var filterByFavorites = false
    // When true, we show only favorite Pokémon.
    
    init() {
        // no-op init so we can configure the fetch request predicate later via .onChange
        // Tip: Keeping init() explicit makes it clear we aren't passing parameters into this View.
    }
    
    // Generic <Pokemon> tells Swift the entity type this fetch returns.
    // Live query to Core Data. When data changes and you save, the list updates.
    // Sorted by Pokémon id ascending so rows appear in Pokédex order.
    // we can also write just \.id
    // this can either be:     private var pokedex: FetchedResults<Pokemon> // Acts like an array of Pokemon from Core Data if we use     @FetchRequest( or i
    @FetchRequest<Pokemon>(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pokemon.id, ascending: true)],
        predicate: nil, // Start with no filter; we set one dynamically when search/favorite changes.
        animation: .default
    ) private var pokedex // Acts like an array of Pokemon from Core Data (auto-updates when the context saves).
    // Core Data returns faults: objects are materialized as needed. Without fetchBatchSize, it may fetch IDs for all matches, but properties load on access.
    // FetchedResults behaves like an array you can iterate in a List/ForEach.
    
    // Helper fetch with no sort: lets us quickly check if the DB is empty and count all items.
    // This avoids "missing rows" side effects from filters/sorts when deciding what empty state to show.
    // Note: We never show this list; it's only for empty state and count checks.
    @FetchRequest<Pokemon>(sortDescriptors: [],animation: .default) private var allPokedexInDB
    
    // Small helper that downloads Pokémon from the network API.
    let fetcher = FetchService() // Tiny helper that knows how to call the Pokémon API.
    
    // Builds an AND predicate based on current UI state (search text + favorites).
    private var dynamicPredicate: NSPredicate {
        // Build filters at runtime based on UI state (search text + favorites). Empty = show all.
        var predicates: [NSPredicate] = []
        
        // search predicate
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "name contains[c] %@",  searchText))
        }
        // filter by favorite predicate
        if filterByFavorites {
            predicates.append(NSPredicate(format: "favorite == %d", true))
        }
        
        
        // If predicates is empty, this AND compound matches everything (no filtering).
        // combine and return
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    var body: some View {
        
        if allPokedexInDB.isEmpty {
            // Empty state UI shown only when the database has zero Pokémon.
            // ContentUnavailableView: system-provided empty state (title, description, actions) for when there is no data.
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
            // NavigationStack manages a stack of screens (push/pop). Required for NavigationLink + navigationDestination.
            // Destinations are built lazily: SwiftUI only constructs the destination view when you navigate to it.
            NavigationStack { // Enables type-safe navigation with NavigationLink(value:).
                // NOTE: List is lazily rendered: rows are created on demand as they scroll into view; not all rows are built upfront.
                // List = table of rows. Each row will be a Pokémon from Core Data.
                List { // Efficiently renders rows and handles diffing/animations for us.
                    // Loop through the fetched Pokemon and build a row for each.
                    Section {
                        ForEach(pokedex) { pokemon in
                            // Value-based navigation: we pass the actual managed object; destination is declared below.
                            NavigationLink (value: pokemon) {
                                // Using the trailing-closure label style keeps the row layout close to the data it represents.
                                // AsyncImage starts loading once this row appears on screen (lazy per-row image fetch).
                                AsyncImage(url: pokemon.sprite) {image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    ProgressView()
                                }
                                // Keep thumbnails small for smooth scrolling.
                                .frame(width: 100, height: 100)
                                // Tip: Keep images small in lists to avoid jank; large images can hurt scrolling.
                                
                                VStack(alignment: .leading) {
                                    // Name shown in Title Case for readability.
                                    HStack {
                                        Text(pokemon.name!.capitalized) // Force unwrap for demo; in production prefer a safe default.
                                            .fontWeight(.bold)
                                        
                                        if pokemon.favorite {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                        }
                                    }
                                    
                                    // Type chips. Requires matching Color assets (e.g., "Fire").
                                    HStack {
                                        ForEach(pokemon.types!, id: \.self) { type in // Force unwrap for demo; consider optional handling.
                                            Text (type.capitalized)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.black)
                                                .padding(.vertical, 5)
                                                .padding(.horizontal, 13)
                                                .background(Color(type.capitalized)) // Uses a Color asset named like the type (e.g., "Fire"). If missing, provide a fallback color.
                                                .clipShape(.capsule)
                                        }
                                    }
                                }
                            }
                            // Quick toggle for favorites, then save to persist.
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
                            // Secondary empty-state hint: shows when fewer than 151 Pokémon are present.
                            ContentUnavailableView {
                                Label("Missing Pokemon", image: .nopokemon)
                            } description: {
                                Text("The fetch was imterrupted!\n Fetch the rest of the pokemon.")
                            } actions: {
                                Button("Fetch pokemon", systemImage: "antenna.radiowaves.left.and.right") {
                                    // Q: Will using pokedex.count + 1 correctly resume fetching?
                                    // A: Not reliably. It assumes no gaps. If some IDs were skipped, you'll miss them. Also, getPokemon(from:) currently ignores its 'from' parameter (it always starts at 1), so this button doesn't actually resume.
                                    getPokemon(from: pokedex.count + 1)
                                }
                                .buttonStyle(.borderedProminent)
                            }

                        }
                    }
                    //                This is the best way but, and if we want to put this app in PROD we should use this way to fetch all pokemons. this is commented out in order to see ContentUnavailableView
                    //                .task {
                    //                    getPokemon()
                    //                }
                }
                .navigationTitle("Pokedex") // Title for the top of the NavigationStack.
                // How does navigationDestination know which Pokémon to open?
                // - Each NavigationLink sent a `Pokemon` value (the tapped row's object).
                // - This modifier registers a builder for values of type Pokemon.
                // - SwiftUI matches the tapped value's type (Pokemon) and calls this closure with THAT instance.
                // Navigation destination views are created on-demand when a link is activated (not all at once).
                .navigationDestination(for: Pokemon.self, destination: { pokemon in // Defines the detail screen for a tapped Pokémon.
                    Text(pokemon.name ?? "no name") // Minimal detail for now; can expand into a full stats view.
                })
                // Top-right bar buttons (edit and add).
                .toolbar { // Add buttons to the navigation bar
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            filterByFavorites.toggle()
                        } label: {
                            Label("Filter By Favorites", systemImage: filterByFavorites ? "star.fill" : "star")
                        }
                        .tint(.yellow)
                    } // Toggles star filter on/off.
                }
                .searchable(text: $searchText, placement: SearchFieldPlacement.navigationBarDrawer, prompt: "Find a Pokemon") // Binds the search bar text to our state.
                // iOS 17+: onChange provides old and new values.
                .onChange(of: searchText) { _, _ in // New iOS signature (old + new values)
                    pokedex.nsPredicate = dynamicPredicate
                } // New iOS signature with old+new values.
                // Back-compat signature for earlier iOS versions.
                .onChange(of: searchText) { // Back-compat signature (single value)
                    pokedex.nsPredicate = dynamicPredicate
                } // Back-compat signature; both do the same refetch.
                // Re-apply predicate when the star filter changes.
                .onChange(of: filterByFavorites) {
                    pokedex.nsPredicate = dynamicPredicate
                } // Toggling the star refilters immediately.
            }
        }
    }
    
    // MARK: - Data loading
    // Helper that fetches Pokemon from the network and saves them into Core Data.
    
    // Asynchronous fetch wrapped in a Task so it won't block the UI.
    private func getPokemon(from id: Int) { // Runs async work without blocking the UI.
        // Heads-up: 'id' isn't used; the loop below always starts at 1, so this does not resume.
        Task { // Starts a new asynchronous context.
            // Naive sequential fetch of 1...151. Simple, but slow and can duplicate without constraints.
            for i in 1..<152 { // 1...151 inclusive.
                do {
                    // 1) Download a Pokemon model from the API.
                    let fetchedPokemon = try await fetcher.fetchPokemon(i) // Network call; can throw or suspend.
                    
                    // Insert a new managed object and copy fields from the network model.
                    let pokemon = Pokemon(context: viewContext) // Insert a new managed object into the main context.
                    // 3) Copy fields from the network model into Core Data.
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
                    
                    // Save commits the insert to the persistent store.
                    try viewContext.save() // Persist this insert to disk.
                } catch {
                    // For now, just log the error. In production, handle it gracefully.
                    print(error) // For learning: logging is fine; later show a user-facing error.
                    // TODO: Surface this error to the user in production.
                }
            }
        }
    }
}

// Preview uses an in-memory Core Data stack so you can see the UI without touching real data.
// It injects a temporary `managedObjectContext` into the environment for the view.
// Preview injects an in-memory Core Data context so this view can run without real disk data.
#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext) // Preview uses an in-memory store so nothing is written to disk.
}

/*
 Junior notes (deep dive, junior-friendly)

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
*/
