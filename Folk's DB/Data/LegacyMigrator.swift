//
//  LegacyMigrator.swift
//  Folk's DB
//
//  Converts version 1.0 data on launch:
//  - duplicate collection names get a suffix ("Mood (2)"), since names are now unique
//  - each record becomes a dictionary entry whose key is the old record ID
//  Safe to run on every launch: once converted, there's nothing left to do. Everything is saved at once.
//
import Foundation
import SwiftData

@MainActor
enum LegacyMigrator {
    static let recoveredCollectionName = "Recovered Records"

    /// Returns the number of records converted.
    @discardableResult
    static func migrate(_ context: ModelContext, now: Date = .now) throws -> Int {
        let collections = try context.fetch(FetchDescriptor<Collection>(sortBy: [SortDescriptor(\.name)]))
        renameDuplicates(collections)

        let records = try context.fetch(FetchDescriptor<KeyValueData>())
        guard !records.isEmpty else {
            if context.hasChanges { try context.save() }
            return 0
        }

        var recovered: Collection?
        var usedLookupKeys = Set(try context.fetch(FetchDescriptor<Entry>()).map(\.lookupKey))
        for record in records {
            let collection: Collection
            if let owner = record.collection {
                collection = owner
            } else {
                // Records without a collection shouldn't exist, but never drop data
                if recovered == nil {
                    let taken = Set(collections.map { FolkStore.nameKey($0.name) })
                    let newCollection = Collection(name: FolkStore.uniqueName(recoveredCollectionName, taken: taken))
                    context.insert(newCollection)
                    recovered = newCollection
                }
                collection = recovered!
            }

            var key = record.id
            var number = 2
            while usedLookupKeys.contains(Entry.lookupKey(collectionID: collection.id, key: key)) {
                key = "\(record.id) (\(number))"
                number += 1
            }
            usedLookupKeys.insert(Entry.lookupKey(collectionID: collection.id, key: key))

            let value = TypedValue(kind: .dictionary, json: .object(record.keyValuePairs.mapValues(JSONValue.string)))
            let entry = Entry(key: key, value: value, collectionID: collection.id, now: now)
            context.insert(entry)
            entry.collection = collection
            context.delete(record)
        }
        try context.save()
        return records.count
    }

    private static func renameDuplicates(_ collections: [Collection]) {
        var taken = Set<String>()
        for collection in collections {
            let name = FolkStore.uniqueName(collection.name, taken: taken)
            if name != collection.name { collection.name = name }
            taken.insert(FolkStore.nameKey(name))
        }
    }
}
