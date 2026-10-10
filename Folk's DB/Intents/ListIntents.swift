//
//  ListIntents.swift
//  Folk's DB
//
//  List values: append, read, remove, and pop (for queues and stacks).
//  Positions count from 1 like Shortcuts' own list actions; -1 is the last item.
//
import AppIntents
import SwiftData

struct AppendToListIntent: AppIntent {
    static let title: LocalizedStringResource = "Append to List"
    static let description = IntentDescription(
        "Adds one or more items to the end of a list, creating it if needed. Returns the number of items in the list.",
        categoryName: "Lists"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Items")
    var items: [String]

    @Parameter(title: "Key")
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Item Type", default: .automatic)
    var itemType: ValueType

    @Parameter(title: "Field", description: "Optional. A path to a list inside a dictionary value, like tasks.today.")
    var field: String?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Append \(\.$items) to \(\.$key) in \(\.$collection)") {
            \.$itemType
            \.$field
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        let values = try items.map { try TypedValue.parse($0, as: itemType).json }
        return .result(value: try store.append(values, to: key, field: try FieldPath.optional(field), in: model))
    }
}

struct GetListIntent: AppIntent {
    static let title: LocalizedStringResource = "Get List"
    static let description = IntentDescription("Gets the items of a list, ready for “Repeat with Each”. A missing key is an empty list.", categoryName: "Lists")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key", optionsProvider: KeyOptionsProvider())
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Field", description: "Optional. A path to a list inside a dictionary value, like tasks.today.")
    var field: String?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Get list \(\.$key) from \(\.$collection)") {
            \.$field
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        return .result(value: try store.list(key, field: try FieldPath.optional(field), in: model).map(\.displayText))
    }
}

struct GetListItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Get List Item"
    static let description = IntentDescription("Gets the item at a position in a list. 1 is the first item and -1 is the last.", categoryName: "Lists")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Position", default: 1)
    var position: Int

    @Parameter(title: "Key", optionsProvider: KeyOptionsProvider())
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Field", description: "Optional. A path to a list inside a dictionary value, like tasks.today.")
    var field: String?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Get item \(\.$position) of \(\.$key) from \(\.$collection)") {
            \.$field
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        let item = try store.listItem(at: try listIndex(fromPosition: position), of: key, field: try FieldPath.optional(field), in: model)
        return .result(value: item.displayText)
    }
}

struct RemoveFromListIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove from List"
    static let description = IntentDescription(
        "Removes the item at a position, or every item equal to a value. Returns how many items were removed.",
        categoryName: "Lists"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key", optionsProvider: KeyOptionsProvider())
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Item", description: "Removes every item equal to this. Ignored when a position is set.")
    var item: String?

    @Parameter(title: "Position", description: "1 is the first item and -1 is the last.")
    var position: Int?

    @Parameter(title: "Field", description: "Optional. A path to a list inside a dictionary value, like tasks.today.")
    var field: String?

    @Dependency var container: ModelContainer

    init() {}

    init(key: String, collection: CollectionEntity, position: Int, field: String? = nil) {
        self.key = key
        self.collection = collection
        self.position = position
        self.field = field
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Remove \(\.$item) from \(\.$key) in \(\.$collection)") {
            \.$position
            \.$field
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        let fieldPath = try FieldPath.optional(field)
        let removed: Int
        if let position {
            removed = try store.removeFromList(key, field: fieldPath, in: model, at: try listIndex(fromPosition: position))
        } else {
            removed = try store.removeFromList(key, field: fieldPath, in: model, matching: item ?? "")
        }
        return .result(value: removed)
    }
}

struct PopFromListIntent: AppIntent {
    static let title: LocalizedStringResource = "Pop from List"
    static let description = IntentDescription(
        "Removes and returns the first item (a queue) or the last item (a stack). Returns nothing when the list is empty.",
        categoryName: "Lists"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "End", default: .first)
    var end: ListEnd

    @Parameter(title: "Key", optionsProvider: KeyOptionsProvider())
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Field", description: "Optional. A path to a list inside a dictionary value, like tasks.today.")
    var field: String?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Pop \(\.$end) item from \(\.$key) in \(\.$collection)") {
            \.$field
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String?> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        let item = try store.pop(key, field: try FieldPath.optional(field), in: model, from: end)
        return .result(value: item?.displayText)
    }
}
