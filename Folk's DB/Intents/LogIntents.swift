//
//  LogIntents.swift
//  Folk's DB
//
//  Log-style use: add values under generated, time-ordered keys, then read them back by date.
//
import AppIntents
import Foundation
import SwiftData

struct AddEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Entry"
    static let description = IntentDescription(
        "Adds a value under a generated key based on the current time, for logs like moods, workouts or expenses. Pass a Dictionary to log several fields at once.",
        categoryName: "Log"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Value",
        inputOptions: String.IntentInputOptions(multiline: true),
        requestValueDialog: "What should the entry say?"
    )
    var value: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Type", default: .automatic)
    var type: ValueType

    @Parameter(title: "Expires After", description: "Optional. The entry is removed after this much time.", defaultUnit: .hours, supportsNegativeNumbers: false)
    var expiresAfter: Measurement<UnitDuration>?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$value) to \(\.$collection)") {
            \.$type
            \.$expiresAfter
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<EntryEntity> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        let entry = try store.addEntry(try TypedValue.parse(value, as: type), to: model, expiry: store.expiry(after: expiresAfter) ?? .clear)
        return .result(value: EntryEntity(entry))
    }
}

struct GetEntriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Entries"
    static let description = IntentDescription("Gets the entries of a collection, optionally only those added in a date range.", categoryName: "Log")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Added After")
    var start: Date?

    @Parameter(title: "Added Before")
    var end: Date?

    @Parameter(title: "Sort By", default: .created)
    var sort: EntrySort

    @Parameter(title: "Order", default: .descending)
    var order: SortDirection

    @Parameter(title: "Limit", inclusiveRange: (1, 100_000))
    var limit: Int?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Get entries in \(\.$collection)") {
            \.$start
            \.$end
            \.$sort
            \.$order
            \.$limit
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[EntryEntity]> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        let entries = store.entries(in: model, from: start, to: end, sort: sort, ascending: order.isAscending, limit: limit)
        return .result(value: entries.map(EntryEntity.init))
    }
}

struct GetLatestEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Latest Entry"
    static let description = IntentDescription("Gets the most recently added entry in a collection.", categoryName: "Log")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Get latest entry in \(\.$collection)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<EntryEntity> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        guard let entry = store.latestEntry(in: model) else { throw FolkError.emptyCollection(collection.name) }
        return .result(value: EntryEntity(entry))
    }
}
