//
//  FolkStore.swift
//  Folk's DB
//
//  All reads and writes go through here, from both the UI and App Intents,
//  so uniqueness, expiry, timestamps, saving and Spotlight indexing behave the same everywhere.
//
import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

enum UpdateMode: String, CaseIterable, Sendable {
    case merge, replace
}

enum MatchOperator: String, CaseIterable, Sendable {
    case equals, notEquals, contains, beginsWith, greaterThan, lessThan, exists
}

enum EntrySort: String, CaseIterable, Sendable {
    case key, created, updated, value
}

enum ListEnd: String, CaseIterable, Sendable {
    case first, last
}

enum Expiry: Equatable {
    case keep, clear, at(Date)
}

@MainActor
final class FolkStore {
    let context: ModelContext
    let now: () -> Date
    private let indexesSpotlight: Bool

    init(context: ModelContext, indexesSpotlight: Bool = true, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.indexesSpotlight = indexesSpotlight
        self.now = now
    }

    convenience init(container: ModelContainer, indexesSpotlight: Bool = true, now: @escaping () -> Date = { .now }) {
        self.init(context: container.mainContext, indexesSpotlight: indexesSpotlight, now: now)
    }

    // MARK: - Collections

    func allCollections() -> [Collection] {
        let collections = (try? context.fetch(FetchDescriptor<Collection>())) ?? []
        return collections.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func collection(id: String) -> Collection? {
        var descriptor = FetchDescriptor<Collection>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func collection(named name: String) -> Collection? {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return allCollections().first { Self.sameName($0.name, wanted) }
    }

    @discardableResult
    func createCollection(name: String, reuseExisting: Bool = false) throws -> Collection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FolkError.emptyName }
        if let existing = collection(named: trimmed) {
            guard reuseExisting else { throw FolkError.collectionExists(existing.name) }
            return existing
        }
        let collection = Collection(name: trimmed)
        context.insert(collection)
        try save()
        index(collections: [collection])
        FolkShortcuts.updateAppShortcutParameters()
        return collection
    }

    func renameCollection(_ collection: Collection, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FolkError.emptyName }
        if let other = self.collection(named: trimmed), other.id != collection.id {
            throw FolkError.collectionExists(other.name)
        }
        collection.name = trimmed
        try save()
        index(entries: collection.entries, collections: [collection])
        FolkShortcuts.updateAppShortcutParameters()
    }

    func deleteCollection(_ collection: Collection) throws {
        let lookupKeys = collection.entries.map(\.lookupKey)
        let collectionID = collection.id
        context.delete(collection)
        try save()
        deindex(lookupKeys: lookupKeys, collectionIDs: [collectionID])
        FolkShortcuts.updateAppShortcutParameters()
    }

    /// Deletes every entry in a collection. Returns how many were deleted.
    @discardableResult
    func clearCollection(_ collection: Collection) throws -> Int {
        let entries = collection.entries
        let lookupKeys = entries.map(\.lookupKey)
        entries.forEach(context.delete)
        try save()
        deindex(lookupKeys: lookupKeys)
        index(collections: [collection])
        return lookupKeys.count
    }

    /// "Mood", or "Mood (2)", "Mood (3)"… if that name is taken.
    func uniqueCollectionName(_ base: String) -> String {
        Self.uniqueName(base, taken: Set(allCollections().map { Self.nameKey($0.name) }))
    }

    /// `base`, or `base (2)`, `base (3)`… whichever `nameKey` isn't in `taken`.
    nonisolated static func uniqueName(_ base: String, taken: Set<String>) -> String {
        var name = base
        var number = 2
        while taken.contains(nameKey(name)) {
            name = "\(base) (\(number))"
            number += 1
        }
        return name
    }

    /// Collection names are unique ignoring case and accents; this is the form they're compared in.
    nonisolated static func nameKey(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    nonisolated static func sameName(_ lhs: String, _ rhs: String) -> Bool {
        nameKey(lhs) == nameKey(rhs)
    }

    // MARK: - Reading entries

    /// Live (not expired) entries, sorted by key.
    func entries(in collection: Collection) -> [Entry] {
        let date = now()
        return collection.entries
            .filter { !$0.isExpired(at: date) }
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    /// The live entry for `key`. An expired entry reads as missing; `purgeExpired()` deletes it later.
    func entry(_ key: String, in collection: Collection) -> Entry? {
        entry(lookupKey: lookupKey(key, in: collection))
    }

    func entry(lookupKey: String) -> Entry? {
        guard let entry = storedEntry(lookupKey: lookupKey), !entry.isExpired(at: now()) else { return nil }
        return entry
    }

    /// The stored entry for a lookup key, including an expired one that hasn't been purged yet.
    private func storedEntry(lookupKey: String) -> Entry? {
        var descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.lookupKey == lookupKey })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func lookupKey(_ key: String, in collection: Collection) -> String {
        Entry.lookupKey(collectionID: collection.id, key: key.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func value(_ key: String, field: FieldPath? = nil, in collection: Collection) -> JSONValue? {
        entry(key, in: collection)?.value.json.value(at: field)
    }

    func keys(in collection: Collection, prefix: String? = nil) -> [String] {
        let keys = entries(in: collection).map(\.key)
        guard let prefix, !prefix.isEmpty else { return keys }
        return keys.filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
    }

    // MARK: - Writing entries

    /// Sets a key (or a field inside it) to a value, creating the entry if needed.
    /// Without an explicit `expiry`, replacing a whole value clears its expiry and writing a field keeps it.
    /// Returns false when `onlyIfMissing` is set and a value already exists.
    @discardableResult
    func set(
        _ value: TypedValue,
        for key: String,
        field: FieldPath? = nil,
        in collection: Collection,
        expiry: Expiry? = nil,
        onlyIfMissing: Bool = false
    ) throws -> Bool {
        let key = try validKey(key)
        let existing = entry(key, in: collection)
        if onlyIfMissing, let existing, existing.value.json.value(at: field) != nil {
            return false
        }
        let newValue: TypedValue
        if let field {
            newValue = TypedValue(try (existing?.value.json ?? .null).setting(value.json, at: field))
        } else {
            newValue = value
        }
        try write(newValue, key: key, existing: existing, in: collection, expiry: expiry ?? (field == nil ? .clear : .keep))
        return true
    }

    /// Deletes a key, or just a field inside it. Returns whether anything was deleted.
    @discardableResult
    func delete(_ key: String, field: FieldPath? = nil, in collection: Collection) throws -> Bool {
        guard let entry = entry(key, in: collection) else { return false }
        guard let field else {
            try deleteEntry(entry)
            return true
        }
        let (newJSON, removed) = try entry.value.json.removing(at: field)
        if removed {
            try write(TypedValue(newJSON), key: entry.key, existing: entry, in: collection, expiry: .keep)
        }
        return removed
    }

    func deleteEntry(_ entry: Entry) throws {
        let lookupKey = entry.lookupKey
        let collection = entry.collection
        context.delete(entry)
        try save()
        deindex(lookupKeys: [lookupKey])
        if let collection { index(collections: [collection]) }
    }

    func renameKey(_ key: String, to newKey: String, in collection: Collection) throws {
        guard let entry = entry(key, in: collection) else { throw FolkError.keyNotFound(key) }
        let newKey = try validKey(newKey)
        guard newKey != entry.key else { return }
        guard self.entry(newKey, in: collection) == nil else { throw FolkError.keyExists(newKey) }
        if let expired = storedEntry(lookupKey: lookupKey(newKey, in: collection)) {
            // Free the unique lookup key held by an expired entry before taking it
            context.delete(expired)
            try save()
        }
        let oldLookupKey = entry.lookupKey
        entry.key = newKey
        entry.lookupKey = Entry.lookupKey(collectionID: collection.id, key: newKey)
        entry.updatedAt = now()
        try save()
        deindex(lookupKeys: [oldLookupKey])
        index(entries: [entry])
    }

    func setExpiry(_ date: Date?, for key: String, in collection: Collection) throws {
        guard let entry = entry(key, in: collection) else { throw FolkError.keyNotFound(key) }
        entry.expiresAt = date
        try save()
    }

    // MARK: - Numbers

    /// Adds `amount` to a number (a missing value counts as 0) and returns the result.
    @discardableResult
    func increment(_ key: String, field: FieldPath? = nil, in collection: Collection, by amount: Double) throws -> Double {
        let key = try validKey(key)
        let existing = entry(key, in: collection)
        let base: Double
        switch existing?.value.json.value(at: field) {
        case nil, .null?:
            base = 0
        case let current?:
            guard let number = current.number else {
                throw FolkError.notANumber(key: field?.description ?? key, value: current.displayText)
            }
            base = number
        }
        let result = base + amount
        guard result.isFinite else { throw FolkError.invalidValue(type: "number", value: "\(base) + \(amount)") }
        if let field {
            try set(.number(result), for: key, field: field, in: collection, expiry: .keep)
        } else {
            try write(.number(result), key: key, existing: existing, in: collection, expiry: .keep)
        }
        return result
    }

    // MARK: - Lists

    /// The items of a list. A missing key is an empty list.
    func list(_ key: String, field: FieldPath? = nil, in collection: Collection) throws -> [JSONValue] {
        switch value(key, field: field, in: collection) {
        case nil, .null?: return []
        case .array(let items)?: return items
        default: throw FolkError.notAList(field?.description ?? key)
        }
    }

    /// Appends items, creating the list if needed. Returns the new item count.
    @discardableResult
    func append(_ items: [JSONValue], to key: String, field: FieldPath? = nil, in collection: Collection) throws -> Int {
        let list = try list(key, field: field, in: collection) + items
        try storeList(list, key: key, field: field, in: collection)
        return list.count
    }

    func listItem(at index: Int, of key: String, field: FieldPath? = nil, in collection: Collection) throws -> JSONValue {
        let list = try list(key, field: field, in: collection)
        guard let resolved = JSONValue.index(index, count: list.count) else { throw FolkError.indexOutOfRange(index) }
        return list[resolved]
    }

    /// Removes every item whose text equals `matching`, or the item at `index`. Returns how many were removed.
    @discardableResult
    func removeFromList(_ key: String, field: FieldPath? = nil, in collection: Collection, matching: String? = nil, at index: Int? = nil) throws -> Int {
        var list = try list(key, field: field, in: collection)
        let before = list.count
        if let index {
            guard let resolved = JSONValue.index(index, count: list.count) else { throw FolkError.indexOutOfRange(index) }
            list.remove(at: resolved)
        } else if let matching {
            list.removeAll { $0.displayText == matching }
        }
        let removed = before - list.count
        if removed > 0 {
            try storeList(list, key: key, field: field, in: collection)
        }
        return removed
    }

    /// Removes and returns the first or last item; nil when the list is empty.
    func pop(_ key: String, field: FieldPath? = nil, in collection: Collection, from end: ListEnd) throws -> JSONValue? {
        var list = try list(key, field: field, in: collection)
        guard !list.isEmpty else { return nil }
        let item = end == .first ? list.removeFirst() : list.removeLast()
        try storeList(list, key: key, field: field, in: collection)
        return item
    }

    private func storeList(_ items: [JSONValue], key: String, field: FieldPath?, in collection: Collection) throws {
        let key = try validKey(key)
        if let field {
            try set(TypedValue(.array(items)), for: key, field: field, in: collection, expiry: .keep)
        } else {
            try write(TypedValue(.array(items)), key: key, existing: entry(key, in: collection), in: collection, expiry: .keep)
        }
    }

    // MARK: - Log entries

    /// Adds a value under a generated, time-ordered key such as "2026-10-10T09:00:00.123Z".
    @discardableResult
    func addEntry(_ value: TypedValue, to collection: Collection, expiry: Expiry = .clear) throws -> Entry {
        try write(value, key: nextLogKey(in: collection), existing: nil, in: collection, expiry: expiry)
    }

    func nextLogKey(in collection: Collection, reserved: Set<String> = []) -> String {
        let base = DateCoding.string(from: now())
        var key = base
        var number = 2
        while reserved.contains(key) || entry(key, in: collection) != nil {
            key = "\(base)-\(String(format: "%03d", number))"
            number += 1
        }
        return key
    }

    /// Entries created in a date range, sorted and limited.
    func entries(in collection: Collection, from start: Date? = nil, to end: Date? = nil, sort: EntrySort = .created, ascending: Bool = true, limit: Int? = nil) -> [Entry] {
        let filtered = entries(in: collection).filter { entry in
            (start.map { entry.createdAt >= $0 } ?? true) && (end.map { entry.createdAt <= $0 } ?? true)
        }
        return Self.limit(sorted(filtered, by: sort, ascending: ascending), to: limit)
    }

    /// The most recently added entry.
    func latestEntry(in collection: Collection) -> Entry? {
        sorted(entries(in: collection), by: .created, ascending: false).first
    }

    // MARK: - Queries

    /// Entries whose value (or a field inside it) matches. Entries without that value never match.
    func find(
        in collection: Collection,
        field: FieldPath? = nil,
        operator op: MatchOperator,
        value query: String,
        sort: EntrySort = .key,
        ascending: Bool = true,
        limit: Int? = nil
    ) -> [Entry] {
        let matches = entries(in: collection).filter { Self.matches($0.value.json.value(at: field), op, query) }
        return Self.limit(sorted(matches, by: sort, ascending: ascending, field: field), to: limit)
    }

    nonisolated static func matches(_ target: JSONValue?, _ op: MatchOperator, _ query: String) -> Bool {
        guard let target, target != .null else { return false }
        let text = target.displayText
        switch op {
        case .exists:
            return true
        case .equals, .notEquals:
            let equal: Bool
            if let number = target.number, let queryNumber = JSONValue.parseNumber(query) {
                equal = number == queryNumber
            } else {
                equal = text.compare(query, options: .caseInsensitive) == .orderedSame
            }
            return op == .equals ? equal : !equal
        case .contains:
            return text.localizedCaseInsensitiveContains(query)
        case .beginsWith:
            return text.lowercased().hasPrefix(query.lowercased())
        case .greaterThan, .lessThan:
            let order = compare(target, .string(query))
            return op == .greaterThan ? order == .orderedDescending : order == .orderedAscending
        }
    }

    /// Compares as numbers (dates count as numbers) when both sides can be, otherwise as text.
    nonisolated static func compare(_ lhs: JSONValue, _ rhs: JSONValue) -> ComparisonResult {
        if let left = comparableNumber(lhs), let right = comparableNumber(rhs) {
            return left == right ? .orderedSame : (left < right ? .orderedAscending : .orderedDescending)
        }
        return lhs.displayText.localizedStandardCompare(rhs.displayText)
    }

    nonisolated private static func comparableNumber(_ value: JSONValue) -> Double? {
        if let number = value.number { return number }
        if case .string(let text) = value, let date = DateCoding.date(from: text) ?? DateCoding.parseDay(text) {
            return date.timeIntervalSince1970
        }
        return nil
    }

    func sorted(_ entries: [Entry], by sort: EntrySort, ascending: Bool, field: FieldPath? = nil) -> [Entry] {
        let indexed = entries.enumerated().sorted { lhs, rhs in
            let (first, second) = ascending ? (lhs.element, rhs.element) : (rhs.element, lhs.element)
            let order: ComparisonResult
            switch sort {
            case .key: order = first.key.localizedStandardCompare(second.key)
            case .created: order = first.createdAt == second.createdAt ? first.key.compare(second.key) : (first.createdAt < second.createdAt ? .orderedAscending : .orderedDescending)
            case .updated: order = first.updatedAt == second.updatedAt ? .orderedSame : (first.updatedAt < second.updatedAt ? .orderedAscending : .orderedDescending)
            case .value: order = Self.compare(Self.sortValue(first, field: field), Self.sortValue(second, field: field))
            }
            return order == .orderedSame ? lhs.offset < rhs.offset : order == .orderedAscending
        }
        return indexed.map(\.element)
    }

    private static func sortValue(_ entry: Entry, field: FieldPath?) -> JSONValue {
        if field == nil, let number = entry.numberValue {
            return .number(number) // numbers, booleans and dates
        }
        return entry.value.json.value(at: field) ?? .null
    }

    private static func limit(_ entries: [Entry], to limit: Int?) -> [Entry] {
        guard let limit, limit >= 0 else { return entries }
        return Array(entries.prefix(limit))
    }

    // MARK: - Whole collection

    /// Every live entry as `{key: value}`.
    func dictionary(of collection: Collection) -> JSONValue {
        .object(Dictionary(uniqueKeysWithValues: entries(in: collection).map { ($0.key, $0.value.json) }))
    }

    /// Sets many keys at once. `replace` also deletes keys that aren't in `values`. Returns the number of keys written.
    @discardableResult
    func setValues(_ values: [String: JSONValue], in collection: Collection, mode: UpdateMode) throws -> Int {
        if mode == .replace {
            let keep = Set(values.keys)
            let removed = collection.entries.filter { !keep.contains($0.key) }
            let lookupKeys = removed.map(\.lookupKey)
            removed.forEach(context.delete)
            deindex(lookupKeys: lookupKeys)
        }
        var written: [Entry] = []
        for (key, json) in values {
            let key = try validKey(key)
            written.append(try write(TypedValue(json), key: key, existing: entry(key, in: collection), in: collection, expiry: .clear, saving: false))
        }
        try save()
        index(entries: written, collections: [collection])
        return written.count
    }

    // MARK: - Maintenance

    /// Deletes expired entries. Returns how many were deleted.
    @discardableResult
    func purgeExpired() -> Int {
        let date = now()
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.expiresAt != nil })
        let expired = ((try? context.fetch(descriptor)) ?? []).filter { $0.isExpired(at: date) }
        guard !expired.isEmpty else { return 0 }
        let lookupKeys = expired.map(\.lookupKey)
        expired.forEach(context.delete)
        try? save()
        deindex(lookupKeys: lookupKeys)
        return lookupKeys.count
    }

    func reindexAll() {
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        index(entries: entries.filter { !$0.isExpired(at: now()) }, collections: allCollections())
    }

    // MARK: - Private

    @discardableResult
    func write(_ value: TypedValue, key: String, existing: Entry?, in collection: Collection, expiry: Expiry, saving: Bool = true) throws -> Entry {
        let entry: Entry
        if let existing {
            existing.value = value
            existing.updatedAt = now()
            entry = existing
        } else if let expired = storedEntry(lookupKey: lookupKey(key, in: collection)) {
            // The key's lookup key is unique, so reuse an expired row that hasn't been purged as a new entry
            expired.value = value
            expired.createdAt = now()
            expired.updatedAt = now()
            entry = expired
        } else {
            entry = Entry(key: key, value: value, collectionID: collection.id, now: now())
            context.insert(entry)
            entry.collection = collection
        }
        switch expiry {
        case .keep: break
        case .clear: entry.expiresAt = nil
        case .at(let date): entry.expiresAt = date
        }
        if saving {
            try save()
            index(entries: [entry], collections: existing == nil ? [collection] : [])
        }
        return entry
    }

    func validKey(_ key: String) throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FolkError.emptyKey }
        return trimmed
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    func index(entries: [Entry] = [], collections: [Collection] = []) {
        guard indexesSpotlight else { return }
        let entryEntities = entries.map(EntryEntity.init)
        let collectionEntities = collections.map(CollectionEntity.init)
        Task {
            if !collectionEntities.isEmpty {
                try? await CSSearchableIndex.default().indexAppEntities(collectionEntities)
            }
            if !entryEntities.isEmpty {
                try? await CSSearchableIndex.default().indexAppEntities(entryEntities)
            }
        }
    }

    func deindex(lookupKeys: [String] = [], collectionIDs: [String] = []) {
        guard indexesSpotlight, !(lookupKeys.isEmpty && collectionIDs.isEmpty) else { return }
        Task {
            if !collectionIDs.isEmpty {
                try? await CSSearchableIndex.default().deleteAppEntities(identifiedBy: collectionIDs, ofType: CollectionEntity.self)
            }
            if !lookupKeys.isEmpty {
                try? await CSSearchableIndex.default().deleteAppEntities(identifiedBy: lookupKeys, ofType: EntryEntity.self)
            }
        }
    }
}
