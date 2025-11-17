//
//  DexApp.swift
//  Dex
//
//  Created by Stoyan Hristov on 17.11.25.
//

import SwiftUI
import CoreData

@main
struct DexApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
