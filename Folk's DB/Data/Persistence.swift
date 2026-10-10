//
//  Persistence.swift
//  Folk's DB
//
//  The single ModelContainer shared by the UI and by App Intents.
//
import SwiftData

enum Persistence {
    static let schema: [any PersistentModel.Type] = [Collection.self, Entry.self, KeyValueData.self]

    // Default configuration, the same store location version 1.0 used, so existing data is picked up
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: Schema(schema))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    static func inMemory() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: Schema(schema), configurations: configuration)
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }
}
