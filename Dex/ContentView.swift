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
    @Environment(\.managedObjectContext) private var viewContext
    
    // Live query to Core Data. When data changes and you save, the list updates.
    // Sorted by Pokémon id ascending so rows appear in Pokédex order.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pokemon.id, ascending: true)], // sort by id ascending
        animation: .default)
    private var pokedex: FetchedResults<Pokemon> // Acts like an array of Pokemon from Core Data
    // FetchedResults behaves like an array you can iterate in a List/ForEach.
    
    // Small helper that downloads Pokémon from the network API.
    let fetcher = FetchService()
    
    var body: some View {
        // NavigationStack manages a stack of screens (push/pop). Required for NavigationLink + navigationDestination.
        NavigationStack {
            // List = table of rows. Each row will be a Pokémon from Core Data.
            List { // Table-like list of rows
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
                        
                        VStack(alignment: .leading) {
                            // Name shown in Title Case for readability.
                            Text(pokemon.name!.capitalized)
                                .fontWeight(.bold)
                            
                            
                            // Types are shown as chips. We use the type string to look up a Color with the same name.
                            // Be sure you have Color assets named after types (e.g., "Fire", "Water").
                            HStack {
                                ForEach(pokemon.types!, id: \.self) { type in
                                    Text (type.capitalized)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.black)
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 13)
                                        .background(Color(type.capitalized)) // Uses a Color asset named like the type (e.g., "Fire").
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
            .navigationDestination(for: Pokemon.self, destination: { pokemon in
                Text(pokemon.name ?? "no name")
            })
            // Top-right bar buttons (edit and add).
            .toolbar { // Add buttons to the navigation bar
                ToolbarItem (placement: .navigationBarTrailing){
                    // About Button label styles:
                    // - Button("Add Item", systemImage: "plus") is concise for simple text+icon.
                    // - Button { ... } label: { Label("Add Item", systemImage: "plus") } is more flexible for custom layouts.
                    // For simple toolbars, the concise initializer is fine (used here).
                    Button("Add Item", systemImage: "plus") {
                        getPokemon()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // EditButton toggles list edit mode (swipe-to-delete/reorder when implemented).
                    EditButton() // Toggles list edit mode (useful when you add delete/reorder handlers)
                }
            }
        }
    }
    
    // MARK: - Data loading
    // Helper that fetches Pokemon from the network and saves them into Core Data.
    
    // Asynchronous fetch wrapped in a Task so it won't block the UI.
    private func getPokemon() {
        Task {
            // NOTE: This naive loop fetches 151 items in sequence and saves each one.
            // In a real app, consider batching, handling duplicates, progress, and error UI.
            for id in 1..<152 {
                do {
                    // 1) Download a Pokemon model from the API.
                    let fetchedPokemon = try await fetcher.fetchPokemon(id)
                    
                    // Map the network model into a new Core Data Pokemon object.
                    let pokemon = Pokemon(context: viewContext)
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
                    try viewContext.save()
                } catch {
                    // For now, just log the error. In production, handle it gracefully.
                    print(error)
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
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

