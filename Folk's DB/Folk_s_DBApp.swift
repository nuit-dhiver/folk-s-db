//
//  Folk_s_DBApp.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 27.11.24.
//

import AppIntents
import SwiftUI
import SwiftData

@main

struct KeyValueStoreApp: App {
    init() {
        let container = Persistence.shared
        // Lets App Intents and entity queries resolve `@Dependency var container: ModelContainer`
        AppDependencyManager.shared.add(dependency: container)

        do {
            try LegacyMigrator.migrate(container.mainContext)
        } catch {
            print("Converting version 1.0 records failed: \(error)")
        }
        let store = FolkStore(container: container)
        store.purgeExpired()
        store.reindexAll()
        FolkShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(Persistence.shared)
        }
    }
}
