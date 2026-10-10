//
//  OpenIntents.swift
//  Folk's DB
//
//  Open a collection or entry in the app, from Shortcuts, Siri or a Spotlight result.
//  Handled in ContentView with `.onAppIntentExecution`.
//
import AppIntents

struct OpenCollectionIntent: OpenIntent, TargetContentProvidingIntent {
    static let title: LocalizedStringResource = "Open Collection"
    static let description = IntentDescription("Opens a collection in Folk's DB.", categoryName: "Collections")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Collection")
    var target: CollectionEntity

    init() {}

    init(target: CollectionEntity) {
        self.target = target
    }
}

struct OpenEntryIntent: OpenIntent, TargetContentProvidingIntent {
    static let title: LocalizedStringResource = "Open Entry"
    static let description = IntentDescription("Opens an entry for editing in Folk's DB.", categoryName: "Values")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Entry")
    var target: EntryEntity

    init() {}

    init(target: EntryEntity) {
        self.target = target
    }
}
