//
//  Persistence.swift
//  Dex
//
//  Created by Stoyan Hristov on 17.11.25.
//

import CoreData

/*
 Core Data quick mental model (junior-friendly):
 - Persistent container = the Core Data "stack". It knows about your data model (Dex.xcdatamodeld),
   loads/creates the SQLite file on disk, and gives you contexts to talk to the database.
 - Context (NSManagedObjectContext) = a scratchpad for changes. You create/fetch/edit objects in a context.
   When you call save(), the context pushes those changes to the persistent store (the database).
 - Managed object (e.g. Pokemon) = a row/record described by your model. Created inside a context.

 Threading:
 - Use container.viewContext on the main thread for UI. It's main-queue bound.
 - Background work should use a background context (not shown here).
*/

/// A tiny wrapper that builds and exposes the Core Data stack for the app.
struct PersistenceController {
    // Singleton you can reuse anywhere: PersistenceController.shared
    static let shared = PersistenceController()
    
    // Why a computed property?
    // - The preview stack is built on demand and may be rebuilt by Xcode previews.
    // - Each time we access this, we look up (or create elsewhere) the sample Pokemon from the preview context.
    // - Returning it via a computed property avoids keeping a global, long-lived reference to a managed object.
    static var previewPokemon: Pokemon {
        let context = PersistenceController.preview.container.viewContext
        
        // Fetch one Pokemon from the in-memory preview store:
        // - We build a simple fetch request for Pokemon.
        // - fetchLimit = 1 means "just give me the first match" (we only inserted one in preview).
        // - In a demo it's fine to assume it exists; in production prefer safe optional handling.
        // try! will crash if the fetch throws. For previews and learning code this is acceptable,
        // but in production use do/catch to handle errors gracefully.
        let fetchRequest: NSFetchRequest<Pokemon> = Pokemon.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        let results = try! context.fetch(fetchRequest)
        
        // Force-unwrapping because preview created exactly one Pokemon.
        // Safer alternative:
        //   if let first = results.first { return first } else { /* create a placeholder */ }
        return results.first!
        
    }

    // A throwaway, in‑memory Core Data stack filled with sample data for SwiftUI previews.
    // About @MainActor on preview:
    // - viewContext is main-queue bound, and SwiftUI previews run UI code on the main thread.
    // - Marking this factory with @MainActor is often fine, but not strictly required because we only touch viewContext synchronously inside this closure during setup.
    // - Removing @MainActor here does NOT make the app "faster"; it simply avoids over-constraining the type and lets this static be constructed without thread annotations.
    // - Rule of thumb:
    //     * If you access UI-bound state from multiple threads, use @MainActor or hop to the main actor.
    //     * For one-time, synchronous preview bootstrapping like this, leaving it off is acceptable.
    static let preview: PersistenceController = {
        // Build an in‑memory store (nothing is written to disk).
        let result = PersistenceController(inMemory: true)

        // Get the main context from the container.
        // Think of this as your "session" to read/write objects on the main thread.
        let viewContext = result.container.viewContext

        // Create a new managed object and insert it into this context.
        // You are not "pointing to the container" directly; you are inserting into the context
        // that belongs to the container.
        let newPokemon = Pokemon(context: viewContext)

        // Set properties defined in your Core Data model.
        // Required (non-optional) attributes must have a value before save() succeeds.
        // Optional attributes can be left nil.
        newPokemon.id = 1
        newPokemon.name = "bulbasaur"
        newPokemon.types = ["grass", "poison"] // Likely a transformable or [String];
        newPokemon.hp = 45
        newPokemon.attack = 49
        newPokemon.specialAttack = 65
        newPokemon.specialDefense = 65
        newPokemon.speed = 45
        newPokemon.sprite = URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/1.png") // URL is commonly optional.
        newPokemon.shiny = URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/shiny/1.png") // Optional is common here too.

        // Save the context. This writes pending changes in viewContext to the in‑memory store.
        do {
            try viewContext.save()
        } catch {
            // If something required is missing or validation fails, save() throws.
            print(error)
        }
        return result
    }()

    // The persistent container holds:
    // - the managed object model (what entities/attributes exist),
    // - the persistent store(s) on disk or memory,
    // - and gives you contexts (like viewContext) to work with data.
    let container: NSPersistentContainer

    // Init builds the container. If inMemory is true, it uses a null URL so nothing is stored on disk.
    init(inMemory: Bool = false)
    
    {
        // Name must match the .xcdatamodeld file ("Dex").
        container = NSPersistentContainer(name: "Dex")

        if inMemory {
            // Redirect the first store to /dev/null to keep data only in RAM (great for previews/tests).
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Load (or create) the actual persistent stores (e.g., SQLite file).
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
               print(error)
            }
        }
        
        // Merge policy: if the same object changed in memory and on disk, prefer the store's values for conflicting properties.
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump

        // When background contexts save, automatically merge their changes into viewContext so the UI updates.
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

/*
 Core Data optionals (what can be nil?) — quick guide:

 - Optional vs required is set in the data model editor.
   • If you check "Optional" for an attribute, the Swift property is typically Optional (e.g., String?, URL?).
   • If you uncheck "Optional", the Swift property is typically non-optional (e.g., Int16, Double).
     - For numeric types, non-optional properties are scalar (Int16/Int32/Int64/Double/Bool) and default to 0/false if you never set them.
     - For String/Date/Transformable, you usually still interact with optionals in Swift unless you add your own "wrapped" computed properties.

 - Relationships:
   • To-one relationships are optional by default (can be nil) unless you mark them required.
   • To-many relationships are non-optional Sets in Swift, but they can be empty (which is effectively "no related objects").

 - Saving:
   • Before calling save(), make sure all required (non-optional) attributes/relationships have valid values.
   • If a required value is missing, save() will throw a validation error.
*/
