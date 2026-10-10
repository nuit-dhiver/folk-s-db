//
//  CollectionEntity.swift
//  Folk's DB
//
//  How a Collection appears in Shortcuts, Siri and Spotlight.
//
import AppIntents
import CoreSpotlight
import SwiftData

struct CollectionEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Collection",
        numericFormat: "\(placeholder: .int) collections"
    )
    static let defaultQuery = CollectionQuery()

    let id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Entry Count")
    var entryCount: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(entryCount) entries",
            image: .init(systemName: "tray.full")
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.displayName = name
        attributes.contentDescription = "Folk's DB collection · \(entryCount) entries"
        return attributes
    }

    init(id: String, name: String, entryCount: Int) {
        self.id = id
        self.name = name
        self.entryCount = entryCount
    }

    init(_ collection: Collection) {
        self.init(id: collection.id, name: collection.name, entryCount: collection.entries.count)
    }
}

struct CollectionQuery: EntityStringQuery, EnumerableEntityQuery {
    @Dependency var container: ModelContainer

    @MainActor
    func entities(for identifiers: [CollectionEntity.ID]) async throws -> [CollectionEntity] {
        let store = FolkStore(container: container)
        return identifiers.compactMap(store.collection(id:)).map(CollectionEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [CollectionEntity] {
        FolkStore(container: container).allCollections()
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(CollectionEntity.init)
    }

    @MainActor
    func allEntities() async throws -> [CollectionEntity] {
        FolkStore(container: container).allCollections().map(CollectionEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [CollectionEntity] {
        try await allEntities()
    }
}
