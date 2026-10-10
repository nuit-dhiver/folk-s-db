//
//  EntryEntity.swift
//  Folk's DB
//
//  How an entry (a key and its value) appears in Shortcuts, Siri and Spotlight.
//  Transferable as JSON, so "Get Dictionary from Input" turns a dictionary value into a native Dictionary.
//
import AppIntents
import CoreSpotlight
import CoreTransferable
import SwiftData
import UniformTypeIdentifiers

struct EntryEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Entry",
        numericFormat: "\(placeholder: .int) entries"
    )
    static let defaultQuery = EntryQuery()

    /// The entry's lookup key: unique, and stable unless the key is renamed
    let id: String
    let collectionID: String
    let typed: TypedValue

    @Property(title: "Key")
    var key: String

    @Property(title: "Collection")
    var collectionName: String

    @Property(title: "Type")
    var kind: ValueKind

    @Property(title: "Created")
    var createdAt: Date

    @Property(title: "Updated")
    var updatedAt: Date

    @Property(title: "Expires")
    var expiresAt: Date?

    @ComputedProperty(title: "Value")
    var text: String { typed.displayText }

    @ComputedProperty(title: "Number")
    var number: Double? { typed.kind == .date ? nil : typed.json.number }

    @ComputedProperty(title: "Date")
    var date: Date? { typed.date }

    @ComputedProperty(title: "Boolean")
    var bool: Bool? { if case .bool(let bool) = typed.json { bool } else { nil } }

    @ComputedProperty(title: "List Items")
    var items: [String] { typed.json.array?.map(\.displayText) ?? [] }

    @ComputedProperty(title: "JSON")
    var json: String { typed.json.jsonText }

    @ComputedProperty(title: "Count")
    var count: Int {
        switch typed.json {
        case .array(let array): array.count
        case .object(let object): object.count
        case .null: 0
        default: 1
        }
    }

    /// A short one-line preview of the value
    var preview: String {
        let text = typed.kind == .date ? (typed.date?.formatted(date: .abbreviated, time: .shortened) ?? self.text) : self.text
        return text.count > 80 ? String(text.prefix(80)) + "…" : text
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(key)",
            subtitle: "\(preview) · \(collectionName)",
            image: .init(systemName: typed.kind.systemImage)
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.displayName = key
        attributes.contentDescription = "\(collectionName) · \(preview)"
        attributes.keywords = [key, collectionName]
        attributes.contentModificationDate = updatedAt
        return attributes
    }

    init(_ entry: Entry) {
        id = entry.lookupKey
        collectionID = entry.collection?.id ?? ""
        typed = entry.value
        key = entry.key
        collectionName = entry.collection?.name ?? ""
        kind = entry.kind
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        expiresAt = entry.expiresAt
    }
}

extension EntryEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { entry in
            Data(entry.typed.json.jsonText.utf8)
        }
        ProxyRepresentation { entry in
            entry.text
        }
    }
}

/// Powers the automatic "Find Entries" action in Shortcuts, with filters, sorting and a limit.
struct EntryQuery: EntityPropertyQuery {
    @Dependency var container: ModelContainer

    static let properties = QueryProperties {
        Property(\EntryEntity.$collectionName) {
            EqualToComparator { name in { (entry: EntryEntity) in FolkStore.sameName(entry.collectionName, name) } }
            ContainsComparator { name in { (entry: EntryEntity) in entry.collectionName.localizedCaseInsensitiveContains(name) } }
        }
        Property(\EntryEntity.$key) {
            EqualToComparator { key in { (entry: EntryEntity) in entry.key == key } }
            ContainsComparator { key in { (entry: EntryEntity) in entry.key.localizedCaseInsensitiveContains(key) } }
            HasPrefixComparator { key in { (entry: EntryEntity) in entry.key.lowercased().hasPrefix(key.lowercased()) } }
        }
        Property(\EntryEntity.$kind) {
            EqualToComparator { kind in { (entry: EntryEntity) in entry.kind == kind } }
            NotEqualToComparator { kind in { (entry: EntryEntity) in entry.kind != kind } }
        }
        Property(\EntryEntity.$createdAt) {
            LessThanComparator { date in { (entry: EntryEntity) in entry.createdAt < date } }
            GreaterThanComparator { date in { (entry: EntryEntity) in entry.createdAt > date } }
        }
        Property(\EntryEntity.$updatedAt) {
            LessThanComparator { date in { (entry: EntryEntity) in entry.updatedAt < date } }
            GreaterThanComparator { date in { (entry: EntryEntity) in entry.updatedAt > date } }
        }
    }

    static let sortingOptions = SortingOptions {
        SortableBy(\EntryEntity.$key)
        SortableBy(\EntryEntity.$createdAt)
        SortableBy(\EntryEntity.$updatedAt)
        SortableBy(\EntryEntity.$collectionName)
    }

    @MainActor
    func entities(for identifiers: [EntryEntity.ID]) async throws -> [EntryEntity] {
        let store = FolkStore(container: container)
        return identifiers.compactMap(store.entry(lookupKey:)).map(EntryEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [EntryEntity] {
        allEntities().filter {
            $0.key.localizedCaseInsensitiveContains(string) || $0.text.localizedCaseInsensitiveContains(string)
        }
    }

    @MainActor
    func entities(
        matching comparators: [(EntryEntity) -> Bool],
        mode: ComparatorMode,
        sortedBy: [EntityQuerySort<EntryEntity>],
        limit: Int?
    ) async throws -> [EntryEntity] {
        var results = allEntities().filter { entry in
            switch mode {
            case .and: comparators.allSatisfy { $0(entry) }
            case .or: comparators.isEmpty || comparators.contains { $0(entry) }
            }
        }
        // Stable sort, applied from the least to the most significant sort key
        for sort in sortedBy.reversed() {
            results = results.enumerated().sorted { lhs, rhs in
                let (first, second) = sort.order == .ascending ? (lhs.element, rhs.element) : (rhs.element, lhs.element)
                if Self.isOrdered(first, second, by: sort.by) { return true }
                if Self.isOrdered(second, first, by: sort.by) { return false }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }
        if let limit { results = Array(results.prefix(limit)) }
        return results
    }

    @MainActor
    func suggestedEntities() async throws -> [EntryEntity] {
        Array(allEntities().sorted { $0.updatedAt > $1.updatedAt }.prefix(20))
    }

    private static func isOrdered(_ lhs: EntryEntity, _ rhs: EntryEntity, by keyPath: PartialKeyPath<EntryEntity>) -> Bool {
        switch keyPath {
        case \EntryEntity.$createdAt: lhs.createdAt < rhs.createdAt
        case \EntryEntity.$updatedAt: lhs.updatedAt < rhs.updatedAt
        case \EntryEntity.$collectionName: lhs.collectionName.localizedStandardCompare(rhs.collectionName) == .orderedAscending
        default: lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
        }
    }

    @MainActor
    private func allEntities() -> [EntryEntity] {
        let store = FolkStore(container: container)
        return store.allCollections().flatMap(store.entries(in:)).map(EntryEntity.init)
    }
}
