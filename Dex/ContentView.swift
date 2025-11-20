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
    // FetchedResults behaves like an array you can iterate in a List/ForEach.
    
    // Small helper that downloads Pokémon from the network API.
    let fetcher = FetchService() // Tiny helper that knows how to call the Pokémon API.
    
    // Builds an AND predicate based on current UI state (search text + favorites).
    private var dynamicPredicate: NSPredicate {
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
        // NavigationStack manages a stack of screens (push/pop). Required for NavigationLink + navigationDestination.
        NavigationStack { // Enables type-safe navigation with NavigationLink(value:).
            // List = table of rows. Each row will be a Pokémon from Core Data.
            List { // Efficiently renders rows and handles diffing/animations for us.
                // Loop through the fetched Pokemon and build a row for each.
                ForEach(pokedex) { pokemon in
                    // NavigationLink with a value:
                    // - We pass the actual Core Data object `pokemon` as the link's value.
                    // - Later, `.navigationDestination(for: Pokemon.self)` declares how to build a screen
                    //   for ANY value of type Pokemon. When you tap this row, SwiftUI pushes the
                    //   destination for that exact `pokemon` instance.
                    // Best practice: Use value-based navigation with NavigationStack + navigationDestination
                    // for type-safe, testable navigation. It scales better than inline destination closures.
                    NavigationLink (value: pokemon) {
                        // Using the trailing-closure label style keeps the row layout close to the data it represents.
                        // AsyncImage downloads and shows the sprite from the URL.
                        AsyncImage(url: pokemon.sprite) {image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
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
                            
                            
                            // Types are shown as chips. We use the type string to look up a Color with the same name.
                            // Be sure you have Color assets named after types (e.g., "Fire", "Water").
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
                }
            }
            .navigationTitle("Pokedex") // Title for the top of the NavigationStack.
            // How does navigationDestination know which Pokémon to open?
            // - Each NavigationLink sent a `Pokemon` value (the tapped row's object).
            // - This modifier registers a builder for values of type Pokemon.
            // - SwiftUI matches the tapped value's type (Pokemon) and calls this closure with THAT instance.
            .searchable(text: $searchText, placement: SearchFieldPlacement.navigationBarDrawer, prompt: "Find a Pokemon") // Binds the search bar text to our state.
            .onChange(of: searchText) { _, _ in
                pokedex.nsPredicate = dynamicPredicate
            } // New iOS signature with old+new values.
            .autocorrectionDisabled(true)
            .onChange(of: searchText) {
                pokedex.nsPredicate = dynamicPredicate
            } // Back-compat signature; both do the same refetch.
            .onChange(of: filterByFavorites) {
                pokedex.nsPredicate = dynamicPredicate
            } // Toggling the star refilters immediately.
            .navigationDestination(for: Pokemon.self, destination: { pokemon in // Defines the detail screen for a tapped Pokémon.
                Text(pokemon.name ?? "no name") // Minimal detail for now; can expand into a full stats view.
            })
            // Top-right bar buttons (edit and add).
            .toolbar { // Add buttons to the navigation bar
                ToolbarItem (placement: .navigationBarTrailing){
                    // About Button label styles:
                    // - Button("Add Item", systemImage: "plus") is concise for simple text+icon.
                    // - Button { ... } label: { Label("Add Item", systemImage: "plus") } is more flexible for custom layouts.
                    // For simple toolbars, the concise initializer is fine (used here).
                    Button("Add Item", systemImage: "plus") { // Downloads the first 151 Pokémon and saves them.
                        getPokemon()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        filterByFavorites.toggle()
                    } label: {
                        Label("Filter By Favorites", systemImage: filterByFavorites ? "star.fill" : "star")
                    }
                    .tint(.yellow)
                } // Toggles star filter on/off.
            }
        }
    }
    
    // MARK: - Data loading
    // Helper that fetches Pokemon from the network and saves them into Core Data.
    
    // Asynchronous fetch wrapped in a Task so it won't block the UI.
    private func getPokemon() { // Runs async work without blocking the UI.
        Task { // Starts a new asynchronous context.
            // NOTE: This naive loop fetches 151 items in sequence and saves each one.
            // In a real app, consider batching, handling duplicates, progress, and error UI.
            for id in 1..<152 { // 1...151 inclusive.
                do {
                    // 1) Download a Pokemon model from the API.
                    let fetchedPokemon = try await fetcher.fetchPokemon(id) // Network call; can throw or suspend.
                    
                    // Map the network model into a new Core Data Pokemon object.
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
*/
