//
//  ContentView.swift
//  Dex
//
//  Created by Stoyan Hristov on 17.11.25.
//

import SwiftUI
import CoreData

/*
 SwiftUI Environment + FetchRequest (junior-friendly mental model):
 - Environment: a shared bucket of values (like settings or services) that flows down the view tree.
   You "inject" a value at the top (e.g., the Core Data context) and "read" it in child views with @Environment.
 - managedObjectContext: the Core Data context we use to fetch/insert/delete and save.
   It's usually injected from the App entry point or from previews.
 - @FetchRequest: asks Core Data for objects and keeps the list updated automatically when data changes.
   It uses the context from the environment under the hood.
*/

// Below is a simple SwiftUI screen that lists Pokemon from Core Data and lets you fetch them.

// Main screen of the app.
struct ContentView: View {
    // The Core Data context ("database session") for reading/writing objects.
    // It's injected higher in the app with `.environment(\.managedObjectContext, ...)`.
    // Think of it like a scratchpad: you make changes here and then call `save()` to persist.
    @Environment(\.managedObjectContext) private var viewContext

    // Live query to Core Data. This automatically keeps `pokedex` in sync with the database.
    // When you insert, update, or delete Pokemon and then save the context, the list updates.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pokemon.id, ascending: true)], // sort by id ascending
        animation: .default)
    // `pokedex` behaves like an array of `Pokemon` you can loop over.
    private var pokedex: FetchedResults<Pokemon> // Acts like an array of Pokemon from Core Data
    
    // Small helper that downloads Pokemon from the network.
    let fetcher = FetchService()

    var body: some View {
        // A container that gives us a navigation bar and push-style navigation.
        NavigationView {
            // A scrolling list of rows.
            List { // Table-like list of rows
                // Loop through the fetched Pokemon and build a row for each.
                ForEach(pokedex) { pokemon in
                    // Tapping a row navigates to a detail view (here: just shows the name).
                    NavigationLink {
                        // Destination view: for now, just show the Pokemon name.
                        Text(pokemon.name ?? "no name") // name might be optional in the model, so we coalesce to a fallback
                    } label: {
                        // Row label shown in the list.
                        Text(pokemon.name ?? "no name")
                    }
                }
            }
            // Top-right bar buttons (edit and add).
            .toolbar { // Add buttons to the navigation bar
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Built-in edit mode (enables swipe-to-delete/reorder when handlers exist).
                    EditButton() // Toggles list edit mode (useful when you add delete/reorder handlers)
                }
                ToolbarItem {
                    /*
                    Tap to fetch and save the first 151 Pokemon into Core Data.
                    In a real app, you might avoid duplicates and show progress/errors.
                    */
                    Button("Add Item", systemImage: "plus") {
                        getPokemon()
                    }
                }
            }
        }
    }
    
    // MARK: - Data loading
    // Helper that fetches Pokemon from the network and saves them into Core Data.
    
    // Asynchronous fetch wrapped in a Task so it won't block the UI.
    private func getPokemon() {
        Task {
            // Gen 1: IDs 1 through 151.
            for id in 1..<152 {
                do {
                    // 1) Download a Pokemon model from the API.
                    let fetchedPokemon = try await fetcher.fetchPokemon(id)
                    
                    // 2) Create a new Core Data object in the current context.
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
                    
                    // 4) Persist changes to disk (commit this batch).
                    try viewContext.save()
                } catch {
                    // For now, just log the error. In production, handle it gracefully.
                    print(error)
                }
            }
        }
    }
    
}

// Preview uses an in-memory Core Data stack so you can see the UI without touching real data.
// It injects a temporary `managedObjectContext` into the environment for the view.
#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

