//
//  EntrySnippetIntent.swift
//  Folk's DB
//
//  Interactive snippet (iOS 26): shows an entry as a card in Shortcuts and Siri.
//  Numbers get −/+ buttons, dictionaries get them on their number fields, and list items can be removed.
//
import AppIntents
import SwiftData

struct ShowEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Entry"
    static let description = IntentDescription(
        "Shows an entry as an interactive card. Numbers get − and + buttons, and list items can be removed.",
        categoryName: "Values"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Entry")
    var entry: EntryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$entry)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<EntryEntity> & ShowsSnippetIntent {
        .result(value: entry, snippetIntent: EntrySnippetIntent(entry: entry))
    }
}

struct EntrySnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Entry Card"
    static let isDiscoverable = false

    @Parameter(title: "Entry")
    var entry: EntryEntity

    @Dependency var container: ModelContainer

    init() {}

    init(entry: EntryEntity) {
        self.entry = entry
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        // Re-read the entry so the card reflects changes made by its buttons
        let model = try FolkStore(container: container).requireEntry(entry)
        let collection = model.collection.map(CollectionEntity.init) ?? CollectionEntity(id: entry.collectionID, name: entry.collectionName, entryCount: 0)
        return .result(view: EntrySnippetView(entry: EntryEntity(model), collection: collection))
    }
}
