//
//  IntentSupport.swift
//  Folk's DB
//
//  Shared helpers and AppEnum conformances for App Intents.
//
import AppIntents
import Foundation
import SwiftData

extension FolkStore {
    func requireCollection(_ entity: CollectionEntity) throws -> Collection {
        guard let collection = collection(id: entity.id) else { throw FolkError.collectionNotFound(entity.name) }
        return collection
    }

    func requireEntry(_ entity: EntryEntity) throws -> Entry {
        guard let entry = entry(lookupKey: entity.id) else { throw FolkError.keyNotFound(entity.key) }
        return entry
    }

    func requireEntry(_ key: String, in collection: Collection) throws -> Entry {
        guard let entry = entry(key, in: collection) else { throw FolkError.keyNotFound(key) }
        return entry
    }

    /// The expiry for an optional "Expires After" duration.
    func expiry(after duration: Measurement<UnitDuration>?) -> Expiry? {
        guard let duration else { return nil }
        return .at(now().addingTimeInterval(duration.converted(to: .seconds).value))
    }
}

/// Shortcuts lists count from 1; -1 is the last item. Converts to a 0-based index (negative stays negative).
func listIndex(fromPosition position: Int) throws -> Int {
    guard position != 0 else { throw FolkError.indexOutOfRange(0) }
    return position > 0 ? position - 1 : position
}

enum SortDirection: String, CaseIterable, Sendable {
    case ascending, descending

    var isAscending: Bool { self == .ascending }
}

/// Suggests the existing keys of the collection chosen in the same action. Typed keys and variables still work.
struct KeyOptionsProvider: DynamicOptionsProvider {
    @Dependency var container: ModelContainer

    @IntentParameterDependency<GetValueIntent>(\.$collection) var getValue
    @IntentParameterDependency<GetEntryIntent>(\.$collection) var getEntry
    @IntentParameterDependency<DeleteKeyIntent>(\.$collection) var deleteKey
    @IntentParameterDependency<KeyExistsIntent>(\.$collection) var keyExists
    @IntentParameterDependency<RenameKeyIntent>(\.$collection) var renameKey
    @IntentParameterDependency<GetListIntent>(\.$collection) var getList
    @IntentParameterDependency<GetListItemIntent>(\.$collection) var getListItem
    @IntentParameterDependency<RemoveFromListIntent>(\.$collection) var removeFromList
    @IntentParameterDependency<PopFromListIntent>(\.$collection) var popFromList

    @MainActor
    func results() async throws -> [String] {
        let chosen = getValue?.collection ?? getEntry?.collection ?? deleteKey?.collection ?? keyExists?.collection
            ?? renameKey?.collection ?? getList?.collection ?? getListItem?.collection ?? removeFromList?.collection
            ?? popFromList?.collection
        let store = FolkStore(container: container)
        guard let chosen, let collection = store.collection(id: chosen.id) else { return [] }
        return store.keys(in: collection)
    }
}

// MARK: - AppEnum conformances

extension ValueKind: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Type"
    static let caseDisplayRepresentations: [ValueKind: DisplayRepresentation] = [
        .text: "Text",
        .number: "Number",
        .boolean: "Boolean",
        .date: "Date",
        .list: "List",
        .dictionary: "Dictionary",
    ]
}

extension ValueType: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Type"
    static let caseDisplayRepresentations: [ValueType: DisplayRepresentation] = [
        .automatic: DisplayRepresentation(title: "Automatic", subtitle: "Detects numbers, true/false, lists and dictionaries"),
        .text: DisplayRepresentation(title: "Text", subtitle: "Always text, e.g. to keep the zero in 01234"),
        .number: "Number",
        .boolean: "Boolean",
        .date: "Date",
        .list: DisplayRepresentation(title: "List", subtitle: "A JSON list, or one item per line"),
        .dictionary: DisplayRepresentation(title: "Dictionary", subtitle: "A Dictionary, JSON object, or “key: value” lines"),
    ]
}

extension MatchOperator: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Comparison"
    static let caseDisplayRepresentations: [MatchOperator: DisplayRepresentation] = [
        .equals: "is",
        .notEquals: "is not",
        .contains: "contains",
        .beginsWith: "begins with",
        .greaterThan: "is greater than",
        .lessThan: "is less than",
        .exists: "has any value",
    ]
}

extension UpdateMode: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Update Mode"
    static let caseDisplayRepresentations: [UpdateMode: DisplayRepresentation] = [
        .merge: DisplayRepresentation(title: "Merge", subtitle: "Keep other keys"),
        .replace: DisplayRepresentation(title: "Replace", subtitle: "Delete keys that aren't in the dictionary"),
    ]
}

extension EntrySort: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Sort By"
    static let caseDisplayRepresentations: [EntrySort: DisplayRepresentation] = [
        .key: "Key",
        .created: "Date Added",
        .updated: "Last Updated",
        .value: "Value",
    ]
}

extension ListEnd: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "End"
    static let caseDisplayRepresentations: [ListEnd: DisplayRepresentation] = [
        .first: "First",
        .last: "Last",
    ]
}

extension SortDirection: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Order"
    static let caseDisplayRepresentations: [SortDirection: DisplayRepresentation] = [
        .ascending: "Ascending",
        .descending: "Descending",
    ]
}
