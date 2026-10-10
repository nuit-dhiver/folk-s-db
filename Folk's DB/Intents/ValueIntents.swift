//
//  ValueIntents.swift
//  Folk's DB
//
//  The everyday key-value actions: get, set, delete, increment.
//  "Field" is an optional path into a dictionary or list value, like address.city or items.0.
//
import AppIntents
import SwiftData

struct GetValueIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Value"
    static let description = IntentDescription(
        "Gets the value of a key. Lists and dictionaries come back as JSON, which Shortcuts can use as a Dictionary. Returns the default if the key doesn't exist or has expired.",
        categoryName: "Values"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key", optionsProvider: KeyOptionsProvider())
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Field", description: "Optional. A path inside a dictionary or list value, like address.city or items.0.")
    var field: String?

    @Parameter(title: "Default Value", default: "")
    var defaultValue: String

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$key) from \(\.$collection)") {
            \.$field
            \.$defaultValue
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        let value = store.value(key, field: try FieldPath.optional(field), in: model)
        return .result(value: value.map(\.displayText) ?? defaultValue)
    }
}

struct SetValueIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Value"
    static let description = IntentDescription(
        "Sets a key to a value, creating it if needed. Pass text, a number, a List or a Dictionary. Returns whether the value was set (it isn't when “Only If Missing” is on and the key already has a value).",
        categoryName: "Values"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key")
    var key: String

    @Parameter(title: "Value", inputOptions: String.IntentInputOptions(multiline: true))
    var value: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Type", default: .automatic)
    var type: ValueType

    @Parameter(title: "Field", description: "Optional. A path inside a dictionary or list value, like address.city or items.0.")
    var field: String?

    @Parameter(title: "Expires After", description: "Optional. The key is removed after this much time.", defaultUnit: .hours, supportsNegativeNumbers: false)
    var expiresAfter: Measurement<UnitDuration>?

    @Parameter(title: "Only If Missing", default: false)
    var onlyIfMissing: Bool

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$key) to \(\.$value) in \(\.$collection)") {
            \.$type
            \.$field
            \.$expiresAfter
            \.$onlyIfMissing
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        let wasSet = try store.set(
            try TypedValue.parse(value, as: type),
            for: key,
            field: try FieldPath.optional(field),
            in: model,
            expiry: store.expiry(after: expiresAfter),
            onlyIfMissing: onlyIfMissing
        )
        return .result(value: wasSet)
    }
}

struct SetDateIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Date"
    static let description = IntentDescription("Sets a key to a date, such as the last time a shortcut ran.", categoryName: "Values")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key")
    var key: String

    @Parameter(title: "Date")
    var date: Date

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Field", description: "Optional. A path inside a dictionary or list value, like address.city or items.0.")
    var field: String?

    @Parameter(title: "Expires After", description: "Optional. The key is removed after this much time.", defaultUnit: .hours, supportsNegativeNumbers: false)
    var expiresAfter: Measurement<UnitDuration>?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$key) to \(\.$date) in \(\.$collection)") {
            \.$field
            \.$expiresAfter
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<EntryEntity> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        try store.set(.date(date), for: key, field: try FieldPath.optional(field), in: model, expiry: store.expiry(after: expiresAfter))
        return .result(value: EntryEntity(try store.requireEntry(key, in: model)))
    }
}

struct DeleteKeyIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Key"
    static let description = IntentDescription("Deletes a key and its value, or just a field inside it. Returns whether anything was deleted.", categoryName: "Values")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key", optionsProvider: KeyOptionsProvider())
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Field", description: "Optional. A path inside a dictionary or list value, like address.city or items.0.")
    var field: String?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$key) from \(\.$collection)") {
            \.$field
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        return .result(value: try store.delete(key, field: try FieldPath.optional(field), in: model))
    }
}

struct KeyExistsIntent: AppIntent {
    static let title: LocalizedStringResource = "Key Exists"
    static let description = IntentDescription("Checks whether a key (or a field inside it) has a value that hasn't expired.", categoryName: "Values")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key", optionsProvider: KeyOptionsProvider())
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Field", description: "Optional. A path inside a dictionary or list value, like address.city or items.0.")
    var field: String?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$key) exists in \(\.$collection)") {
            \.$field
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        return .result(value: store.value(key, field: try FieldPath.optional(field), in: model) != nil)
    }
}

struct IncrementIntent: AppIntent {
    static let title: LocalizedStringResource = "Increment"
    static let description = IntentDescription(
        "Adds a number to a value and returns the result. A missing key starts at 0. Use a negative amount to decrease.",
        categoryName: "Values"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key")
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Parameter(title: "Amount", default: 1)
    var amount: Double

    @Parameter(title: "Field", description: "Optional. A path inside a dictionary or list value, like address.city or items.0.")
    var field: String?

    @Dependency var container: ModelContainer

    init() {}

    init(key: String, collection: CollectionEntity, amount: Double, field: String? = nil) {
        self.key = key
        self.collection = collection
        self.amount = amount
        self.field = field
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Increment \(\.$key) in \(\.$collection) by \(\.$amount)") {
            \.$field
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        return .result(value: try store.increment(key, field: try FieldPath.optional(field), in: model, by: amount))
    }
}

struct RenameKeyIntent: AppIntent {
    static let title: LocalizedStringResource = "Rename Key"
    static let description = IntentDescription("Renames a key, keeping its value.", categoryName: "Values")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key", optionsProvider: KeyOptionsProvider())
    var key: String

    @Parameter(title: "New Key")
    var newKey: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Rename \(\.$key) to \(\.$newKey) in \(\.$collection)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<EntryEntity> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        try store.renameKey(key, to: newKey, in: model)
        return .result(value: EntryEntity(try store.requireEntry(newKey, in: model)))
    }
}

struct GetEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Entry"
    static let description = IntentDescription(
        "Gets a key with its value and details: type, number, date, list items, when it was added, updated, and when it expires.",
        categoryName: "Values"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Key", optionsProvider: KeyOptionsProvider())
    var key: String

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Get entry \(\.$key) from \(\.$collection)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<EntryEntity> {
        let store = FolkStore(container: container)
        let model = try store.requireCollection(collection)
        return .result(value: EntryEntity(try store.requireEntry(key, in: model)))
    }
}
