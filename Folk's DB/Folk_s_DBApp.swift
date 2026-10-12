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

        var converted = 0
        do {
            converted = try LegacyMigrator.migrate(container.mainContext)
        } catch {
            print("Converting version 1.0 records failed: \(error)")
        }
        #if DEBUG
        DemoData.seedIfRequested(container)
        #endif
        let store = FolkStore(container: container)
        store.purgeExpired()

        // Writes keep Spotlight current, so rebuild the whole index only after converting old data or when its format changes.
        // This also keeps background launches for a single Shortcuts action fast.
        let defaults = UserDefaults.standard
        if converted > 0 || defaults.integer(forKey: Self.spotlightIndexVersionKey) < Self.spotlightIndexVersion {
            store.reindexAll()
            FolkShortcuts.updateAppShortcutParameters()
            defaults.set(Self.spotlightIndexVersion, forKey: Self.spotlightIndexVersionKey)
        }
    }

    private static let spotlightIndexVersionKey = "spotlightIndexVersion"
    private static let spotlightIndexVersion = 1 // Bump when EntryEntity/CollectionEntity indexing changes

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(Persistence.shared)
        }
    }
}
