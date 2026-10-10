//
//  QueryIntents.swift
//  Folk's DB
//
//  Searching a collection and working with it as one dictionary.
//
import AppIntents
import SwiftData

struct FindEntriesWhereIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Entries Where"
    static let description = IntentDescription(
        "Finds entries whose value, or a field inside it, matches. Numbers and dates compare as numbers and dates; text ignores upper/lower case.",
        categoryName: "Search"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Field", description: "Optional. A path inside dictionary values, like mood or address.city. Leave empty to compare the whole value.")
    var field: String?

    @Parameter(title: "Comparison", default: .equals)
    var comparison: MatchOperator

    @Parameter(title: "Value", default: "")
    var value: String

    @Parameter(title: "Sort By", default: .key)
    var sort: EntrySort

    @Parameter(title: "Order", default: .ascending)
    var order: SortDirection

    @Parameter(title: "Limit", inclusiveRange: (1, 100_000))
    var limit: Int?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        When(\FindEntriesWhereIntent.$comparison, .equalTo, MatchOperator.exists) {
            Summary("Find entries in \(\.$collection) where \(\.$field) \(\.$comparison)") {
                \.$sort
                \.$order
                \.$limit
            }
        } otherwise: {
            Summary("Find entries in \(\.$collection) where \(\.$field) \(\.$comparison) \(\.$value)") {
                \.$sort
                \.$order
                \.$limit
            }
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[EntryEntity]> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        let entries = store.find(
            in: model,
            field: try FieldPath.optional(field),
            operator: comparison,
            value: value,
            sort: sort,
            ascending: order.isAscending,
            limit: limit
        )
        return .result(value: entries.map(EntryEntity.init))
    }
}

struct ListKeysIntent: AppIntent {
    static let title: LocalizedStringResource = "List Keys"
    static let description = IntentDescription("Gets the keys in a collection, optionally only those that begin with a prefix.", categoryName: "Search")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Prefix")
    var prefix: String?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("List keys in \(\.$collection)") {
            \.$prefix
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        return .result(value: store.keys(in: model, prefix: prefix))
    }
}

struct GetCollectionDictionaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Collection as Dictionary"
    static let description = IntentDescription("Gets every key and value in a collection as one Dictionary.", categoryName: "Search")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$collection) as a dictionary")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = FolkStore(container: container)
        return .result(value: store.dictionary(of: try store.requireCollection(collection)).jsonText)
    }
}

struct SetValuesFromDictionaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Values from Dictionary"
    static let description = IntentDescription(
        "Sets every key in a Dictionary at once. Replace also deletes keys that aren't in the Dictionary. Returns how many keys were set.",
        categoryName: "Search"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Dictionary", description: "A Dictionary or JSON object", inputOptions: String.IntentInputOptions(multiline: true))
    var dictionary: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Mode", default: .merge)
    var mode: UpdateMode

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Set values from \(\.$dictionary) in \(\.$collection)") {
            \.$mode
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        guard let object = try TypedValue.parse(dictionary, as: .dictionary).json.object else { throw FolkError.invalidJSON }
        return .result(value: try store.setValues(object, in: model, mode: mode))
    }
}
