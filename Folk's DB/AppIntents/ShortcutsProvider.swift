//
//  ShortcutsProvider.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 02.12.24.
//
import AppIntents
import SwiftData





struct KeyValueAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        
            AppShortcut(
                intent: ReadValueIntent(),
                phrases: ["Read value from \(.applicationName)"],
                shortTitle: "Read Value",
                systemImageName: "text.book.closed"
            )
            AppShortcut(
                intent: WriteValueIntent(),
                phrases: ["Write value to \(.applicationName)"],
                shortTitle: "Write Value",
                systemImageName: "square.and.pencil"
            )
    }
}
struct ReadValueIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Value from Collection"

    @Parameter(title: "Collection Name")
    var collectionName: String

    @Parameter(title: "Key")
    var key: String

    static var description = IntentDescription(
        "Reads a value for a specific key from a selected collection.",
        categoryName: "Collection Operations"
    )

    func perform() async throws -> some IntentResult {
        let collection = findCollection(by: collectionName)!

        let value = findValue(in: collection, for: key)

        return .result(value: value)
    }

    private func findCollection(by name: String) -> Collection? {
        // Logic to fetch collection from SwiftData
        let context = try? SwiftDataContext.shared.context()
        return context?.fetch(Collection.self).first(where: { $0.name == name })
    }

    private func findValue(in collection: Collection, for key: String) -> String? {
        return collection.keyValueData
            .flatMap { $0.keyValuePairs }
            .first(where: { $0.key == key })?.value
    }
}

struct WriteValueIntent: AppIntent {
    static var title: LocalizedStringResource = "Write Value to Collection"

    @Parameter(title: "Collection Name")
    var collectionName: String

    @Parameter(title: "Key")
    var key: String

    @Parameter(title: "Value")
    var value: String

    static var description = IntentDescription(
        "Writes a value for a specific key into a selected collection.",
        categoryName: "Collection Operations"
    )

    func perform() async throws -> some IntentResult {
        guard let collection = try findCollection(by: collectionName) else {
            throw NSError(domain: "AppIntents", code: 1, userInfo: [NSLocalizedDescriptionKey: "Collection not found."])
        }

        if let record = collection.keyValueData.first(where: { $0.keyValuePairs.keys.contains(key) }) {
            record.keyValuePairs[key] = value
        } else {
            let newRecord = KeyValueData(keyValuePairs: [key: value], collection: collection)
            let context = try SwiftDataContext.shared.context()
            context.insert(newRecord)
        }

        let context = try SwiftDataContext.shared.context()
        try context.save()

        return .result(dialog: "Value \(value) saved for key \(key).")
    }

    private func findCollection(by name: String) throws -> Collection? {
        let context = try SwiftDataContext.shared.context()
        let descriptor = FetchDescriptor<Collection>(
            predicate: #Predicate { $0.name == name }
        )
        return try context.fetch(descriptor).first
    }
}
