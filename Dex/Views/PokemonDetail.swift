//
//  PokemonDetail.swift
//  Dex
//
//  Created by Stoyan Hristov on 21.11.25.
//

// Detail screen: shows one Pokémon with image(s), type chips, favorite toggle, and stats.

import SwiftUI
import CoreData

// Core Data is used to persist favorites and Pokémon fields.

// Displays the tapped Pokémon and lets you toggle favorite or switch to shiny.
struct PokemonDetail: View {
    // Core Data context (workspace) for saving favorite changes.
    // Core Data context from the environment (injected at app start).
    // Think of it as your scratchpad to fetch/insert/delete objects; call save() to persist.
    @Environment(\.managedObjectContext) private var viewContext
    
    // The selected Pokémon instance, injected by the parent via .environmentObject.
    // @EnvironmentObject lets a parent view provide a shared object to many child views without passing it through initializers.
    // Junior-friendly mental model:
    // - A parent (ContentView) sets `.environmentObject(pokemon)` on the destination.
    // - Any child that declares `@EnvironmentObject private var pokemon: Pokemon` can then read THAT SAME instance.
    // - It's great for data you want to reuse across multiple screens without plumbing it through every initializer.
    // In this screen, `pokemon` is the specific Core Data Pokemon the user tapped in the list.
    // we need the environmentObject here, because we actually change the database data by toggling favorite
    @EnvironmentObject private var pokemon: Pokemon
    
    // Local UI state: whether to show the shiny sprite.
    @State private var showShiny = false
    
    var body: some View {
        // Scrollable layout: header image + sprite, then types/favorite, then stats.
        ScrollView {
            ZStack {
                // Background artwork chosen by the Pokémon’s type/theme.
                Image(pokemon.background)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: .black, radius: 6)
                
                // Sprite image: toggles between normal and shiny based on showShiny.
                AsyncImage(url: showShiny ? pokemon.shinyURL :  pokemon.spriteURL) { image in
                    image
                    // Image modifiers (junior-friendly):
                    // - .interpolation(.none): keep pixel art crisp (no smoothing).
                    // - .resizable(): allows the image to change size.
                    // - .scaledToFit(): scales uniformly so it fits without cropping.
                    // - .padding(.top, 50): adds space at the top so it doesn't touch the header.
                    // - .shadow(color: .black, radius: 6): draws a soft shadow for depth.
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(.top, 50)
                        .shadow(color: .black ,radius: 6)
                } placeholder: {
                    ProgressView()
                }
            }
            
            // Types on the left; favorite toggle on the right.
            HStack {
                // Render each type as a colored capsule chip.
                ForEach(pokemon.types!, id: \.self) {type in
                    Text(type.capitalized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .shadow(color: .white, radius: 1)
                        .padding(.vertical, 7)
                        .padding(.horizontal)
                        .background(Color(type.capitalized))
                        .clipShape(.capsule)
                    
                }
                Spacer()
                
                // Toggle favorite and persist the change to Core Data.
                Button {
                    pokemon.favorite.toggle()
                    
                    do {
                        try viewContext.save()
                    } catch {
                        print(error)
                    }
                    
                } label: {
                    Image(systemName: pokemon.favorite ? "star.fill" : "star")
                        .font(.largeTitle)
                        .tint(.yellow)
                }
            }
            .padding()
            
            // Section title for the stats area.
            Text("Stats")
                .font(.title)
                .padding(.bottom, -7)
                
            // Custom view that visualizes the Pokémon’s stats.
            Stats(pokemon: pokemon)
        }
        // Use the Pokémon’s name as the navigation title.
        // Show the Pokémon's name as the title. Using ! for simplicity here; consider a safe default in production.
        .navigationTitle(pokemon.name!.capitalized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Toolbar action: toggle between normal and shiny sprites.
                Button {
                    showShiny.toggle()
                } label: {
                    Image(systemName: showShiny ? "wand.and.stars" : "wand.and.stars.inverse")
                        .tint(showShiny ? .yellow : .primary)
                }
            }
        }
    }
}

#Preview {
    // to show navigation title and toolbar buttons
    NavigationStack {
        PokemonDetail()
            // Inject a sample Pokemon object so the detail view has data to show in previews.
            .environmentObject(PersistenceController.previewPokemon)
    }
        
}

/*
Junior notes (extras):

- What are the stats?
  - hp: how much damage a Pokémon can take before fainting.
  - attack/defense: physical damage dealt/taken.
  - specialAttack/specialDefense: special (non-physical) damage dealt/taken.
  - speed: who acts first in turn order.

- Where do these stats come from?
  - They are decoded from the API’s `stats` array and stored on the `Pokemon` object.
  - The `Stats` view displays them (often as bars or numbers). If you see a `max(...)` in that view, it’s usually used to cap or normalize bar lengths so visuals don’t exceed a maximum width.

- EnvironmentObject vs Environment:
  - `@EnvironmentObject` passes a shared object (the selected Pokémon) down the view tree.
  - `@Environment(\.managedObjectContext)` provides the Core Data context for reads/writes.

- Why the list and detail both update?
  - Toggling favorite saves to Core Data; SwiftUI updates any views observing those objects.

- Best practices (quick):
  - Avoid force unwraps in production; provide safe defaults (e.g., `pokemon.name ?? "Unknown"`).
  - Consider accessibility: add labels/hints for images and buttons.
  - Keep heavy work off the main thread; use background contexts for large saves.
  - Prefer small images and caching for smooth scrolling.
  - For crisp pixel art, `.interpolation(.none)` is appropriate (as used here).
*/
