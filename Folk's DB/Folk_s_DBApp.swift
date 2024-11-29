//
//  Folk_s_DBApp.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 27.11.24.
//

import SwiftUI
import SwiftData

@main
//struct Folk_s_DBApp: App {
//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            Item.self,
//        ])
//        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//
//        do {
//            return try ModelContainer(for: schema, configurations: [modelConfiguration])
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()

struct KeyValueStoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [KeyValueData.self]) // Initialize SwiftData container
        }
    }
}

//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//        .modelContainer(sharedModelContainer)
//    }
//}
