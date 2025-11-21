//
//  PokemonDetail.swift
//  Dex
//
//  Created by Stoyan Hristov on 21.11.25.
//

import SwiftUI
import CoreData

struct PokemonDetail: View {
    // Core Data context from the environment (injected at app start).
    // Think of it as your scratchpad to fetch/insert/delete objects; call save() to persist.
    @Environment(\.managedObjectContext) private var viewContext
    
    // @EnvironmentObject lets a parent view provide a shared object to many child views without passing it through initializers.
    // Junior-friendly mental model:
    // - A parent (ContentView) sets `.environmentObject(pokemon)` on the destination.
    // - Any child that declares `@EnvironmentObject private var pokemon: Pokemon` can then read THAT SAME instance.
    // - It's great for data you want to reuse across multiple screens without plumbing it through every initializer.
    // In this screen, `pokemon` is the specific Core Data Pokemon the user tapped in the list.
    @EnvironmentObject private var pokemon: Pokemon
    
    @State private var showShiny = false
    
    var body: some View {
        ScrollView {
            ZStack {
                Image(.normalgrasselectricpoisonfairy)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: .black, radius: 6)
                
                AsyncImage(url: pokemon.sprite) { image in
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
            
            // Row with type chips on the left and a favorite toggle button on the right.
            HStack {
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
                
                // Toggle the favorite flag and save to Core Data so it persists.
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
        }
        // Show the Pokémon's name as the title. Using ! for simplicity here; consider a safe default in production.
        .navigationTitle(pokemon.name!.capitalized)
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

