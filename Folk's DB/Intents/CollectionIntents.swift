//
//  CollectionIntents.swift
//  Folk's DB
//
//  Shortcuts actions for collections. Collection names are unique (ignoring upper/lower case).
//
import AppIntents
import SwiftData

struct CreateCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Collection"
    static let description = IntentDescription(
        "Creates a collection. If one with this name exists and “Reuse Existing” is on, that one is returned instead.",
        categoryName: "Collections"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Reuse Existing", default: true)
    var reuseExisting: Bool

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Create collection \(\.$name)") {
            \.$reuseExisting
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<CollectionEntity> {
        let collection = try FolkStore(container: container).createCollection(name: name, reuseExisting: reuseExisting)
        return .result(value: CollectionEntity(collection))
    }
}

struct GetCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Collection by Name"
    static let description = IntentDescription("Finds a collection by its name, ignoring upper/lower case.", categoryName: "Collections")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Create If Missing", default: false)
    var createIfMissing: Bool

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Get collection named \(\.$name)") {
            \.$createIfMissing
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<CollectionEntity> {
        let store = FolkStore(container: container)
        if let collection = store.collection(named: name) {
            return .result(value: CollectionEntity(collection))
        }
        guard createIfMissing else { throw FolkError.collectionNotFound(name) }
        return .result(value: CollectionEntity(try store.createCollection(name: name)))
    }
}

struct RenameCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Rename Collection"
    static let description = IntentDescription("Renames a collection.", categoryName: "Collections")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "New Name")
    var newName: String

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Rename \(\.$collection) to \(\.$newName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<CollectionEntity> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        try store.renameCollection(model, to: newName)
        return .result(value: CollectionEntity(model))
    }
}

struct ClearCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Collection"
    static let description = IntentDescription("Deletes every key in a collection but keeps the collection. Returns how many keys were deleted.", categoryName: "Collections")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Ask Before Clearing", default: true)
    var confirm: Bool

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Clear \(\.$collection)") {
            \.$confirm
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        if confirm {
            try await requestConfirmation(dialog: "Delete all \(model.entries.count) keys in “\(model.name)”?")
        }
        return .result(value: try store.clearCollection(model))
    }
}

struct DeleteCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Collection"
    static let description = IntentDescription("Deletes a collection and all of its keys.", categoryName: "Collections")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Ask Before Deleting", default: true)
    var confirm: Bool

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$collection)") {
            \.$confirm
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        if confirm {
            try await requestConfirmation(dialog: "Delete “\(model.name)” and its \(model.entries.count) keys?")
        }
        try store.deleteCollection(model)
        return .result()
    }
}
