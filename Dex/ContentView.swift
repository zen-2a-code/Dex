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

struct ContentView: View {
    // Read the Core Data context from the SwiftUI environment.
    // This is provided by .environment(\.managedObjectContext, someContext) higher up.
    @Environment(\.managedObjectContext) private var viewContext

    // Live query to Core Data. When objects change (insert/delete/update) and you save,
    // this results list updates and the UI refreshes.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pokemon.id, ascending: true)], // sort by id ascending
        animation: .default)
    private var pokedex: FetchedResults<Pokemon> // Acts like an array of Pokemon from Core Data

    var body: some View {
        NavigationView { // Provides a navigation bar and push-style navigation
            List { // Table-like list of rows
                // Iterate over the fetched results. Each element is a managed object (Pokemon).
                ForEach(pokedex) { pokemon in
                    // Tapping a row navigates to a detail view (here: just shows the name).
                    NavigationLink {
                        Text(pokemon.name ?? "no name") // name might be optional in the model, so we coalesce to a fallback
                    } label: {
                        Text(pokemon.name ?? "no name")
                    }
                }
            }
            .toolbar { // Add buttons to the navigation bar
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton() // Toggles list edit mode (useful when you add delete/reorder handlers)
                }
                ToolbarItem {
                    // Placeholder add button. Typically you'd insert a new Pokemon into viewContext and save().
                    Button("Add Item", systemImage: "plus") {
                        // Example (not implemented here): create a Pokemon(context: viewContext), set properties, try? viewContext.save()
                    }
                }
            }
        }
    }
}

// Preview: builds the view with a temporary, in-memory Core Data stack and injects its context.
// That way the view can fetch data during previews without touching real app data.
#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
