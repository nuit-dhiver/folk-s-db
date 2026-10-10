//
//  Folk_s_DBTests.swift
//  Folk's DBTests
//
//  Created by Mohammad-Hossein Emami on 27.11.24.
//

import Foundation
import SwiftData
import Testing
@testable import Folk_s_DB

/// A clock tests can move forward, for expiry and ordering.
@MainActor
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

@MainActor
struct FolkStoreTests {
    let container = Persistence.inMemory()
    let clock = TestClock()
    var store: FolkStore {
        let clock = clock
        return FolkStore(container: container, indexesSpotlight: false, now: { clock.now })
    }

    // MARK: Collections

    @Test func collectionNamesAreUnique() throws {
        let mood = try store.createCollection(name: " Mood ")
        #expect(mood.name == "Mood")
        #expect(throws: FolkError.collectionExists("Mood")) { try store.createCollection(name: "mood") }
        #expect(try store.createCollection(name: "MOOD", reuseExisting: true).id == mood.id)
        #expect(throws: FolkError.emptyName) { try store.createCollection(name: "  ") }

        let other = try store.createCollection(name: "Other")
        #expect(throws: FolkError.collectionExists("Mood")) { try store.renameCollection(other, to: "mood") }
        try store.renameCollection(mood, to: "Moods")
        #expect(store.collection(named: "moods")?.id == mood.id)
        #expect(store.uniqueCollectionName("Other") == "Other (2)")
    }

    @Test func deleteAndClearCollection() throws {
        let collection = try store.createCollection(name: "Temp")
        try store.set(.text("a"), for: "a", in: collection)
        try store.set(.text("b"), for: "b", in: collection)
        #expect(try store.clearCollection(collection) == 2)
        #expect(store.entries(in: collection).isEmpty)

        try store.set(.text("c"), for: "c", in: collection)
        try store.deleteCollection(collection)
        #expect(store.allCollections().isEmpty)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Entry>()) == 0)
    }

    // MARK: Set / get

    @Test func setGetAndUpsert() throws {
        let settings = try store.createCollection(name: "Settings")
        try store.set(.text("dark"), for: "theme", in: settings)
        let created = try #require(store.entry("theme", in: settings)).createdAt

        clock.advance(10)
        try store.set(.number(2), for: "theme", in: settings)

        let entry = try #require(store.entry("theme", in: settings))
        #expect(entry.kind == .number)
        #expect(store.value("theme", in: settings) == .number(2))
        #expect(entry.createdAt == created)
        #expect(entry.updatedAt == clock.now)
        #expect(store.entries(in: settings).count == 1)
    }

    @Test func sameKeyInDifferentCollections() throws {
        let first = try store.createCollection(name: "A")
        let second = try store.createCollection(name: "B")
        try store.set(.text("1"), for: "key", in: first)
        try store.set(.text("2"), for: "key", in: second)
        #expect(store.value("key", in: first) == .string("1"))
        #expect(store.value("key", in: second) == .string("2"))
    }

    @Test func onlyIfMissing() throws {
        let flags = try store.createCollection(name: "Flags")
        #expect(try store.set(.bool(true), for: "ranToday", in: flags, onlyIfMissing: true))
        #expect(try !store.set(.bool(false), for: "ranToday", in: flags, onlyIfMissing: true))
        #expect(store.value("ranToday", in: flags) == .bool(true))
    }

    @Test func keysMustNotBeEmpty() throws {
        let collection = try store.createCollection(name: "C")
        #expect(throws: FolkError.emptyKey) { try store.set(.text("x"), for: "  ", in: collection) }
    }

    @Test func renameKey() throws {
        let collection = try store.createCollection(name: "C")
        try store.set(.text("1"), for: "old", in: collection)
        try store.set(.text("2"), for: "taken", in: collection)
        #expect(throws: FolkError.keyExists("taken")) { try store.renameKey("old", to: "taken", in: collection) }

        try store.renameKey("old", to: "new", in: collection)
        #expect(store.entry("old", in: collection) == nil)
        #expect(store.entry("new", in: collection)?.lookupKey == Entry.lookupKey(collectionID: collection.id, key: "new"))
        #expect(throws: FolkError.keyNotFound("missing")) { try store.renameKey("missing", to: "x", in: collection) }
    }

    // MARK: Field paths

    @Test func fieldPaths() throws {
        let people = try store.createCollection(name: "People")
        let city = try FieldPath("address.city")
        try store.set(.text("Berlin"), for: "sam", field: city, in: people)

        #expect(store.entry("sam", in: people)?.kind == .dictionary)
        #expect(store.value("sam", field: city, in: people) == .string("Berlin"))
        #expect(store.value("sam", in: people) == .object(["address": .object(["city": .string("Berlin")])]))

        #expect(try store.delete("sam", field: city, in: people))
        #expect(store.value("sam", field: city, in: people) == nil)
        #expect(store.entry("sam", in: people) != nil)

        try store.set(.text("dark"), for: "theme", in: people)
        #expect(throws: FolkError.notADictionary) { try store.set(.text("x"), for: "theme", field: FieldPath("a"), in: people) }
    }

    // MARK: Expiry

    @Test func expiringKeys() throws {
        let cache = try store.createCollection(name: "Cache")
        try store.set(.text("sunny"), for: "weather", in: cache, expiry: .at(clock.now.addingTimeInterval(60)))

        clock.advance(59)
        #expect(store.value("weather", in: cache) == .string("sunny"))

        clock.advance(2)
        #expect(store.value("weather", in: cache) == nil)
        #expect(cache.entries.isEmpty) // purged on read
    }

    @Test func writingAWholeValueClearsExpiryButFieldWritesKeepIt() throws {
        let cache = try store.createCollection(name: "Cache")
        let expiry = clock.now.addingTimeInterval(60)
        try store.set(TypedValue(.object([:])), for: "doc", in: cache, expiry: .at(expiry))
        try store.set(.number(1), for: "doc", field: FieldPath("count"), in: cache)
        #expect(store.entry("doc", in: cache)?.expiresAt == expiry)

        try store.set(.text("replaced"), for: "doc", in: cache)
        #expect(store.entry("doc", in: cache)?.expiresAt == nil)
    }

    @Test func purgeExpired() throws {
        let cache = try store.createCollection(name: "Cache")
        try store.set(.text("a"), for: "a", in: cache, expiry: .at(clock.now.addingTimeInterval(10)))
        try store.set(.text("b"), for: "b", in: cache, expiry: .at(clock.now.addingTimeInterval(100)))
        try store.set(.text("c"), for: "c", in: cache)
        clock.advance(50)
        #expect(store.purgeExpired() == 1)
        #expect(cache.entries.map(\.key).sorted() == ["b", "c"])
    }

    // MARK: Numbers

    @Test func increment() throws {
        let counters = try store.createCollection(name: "Counters")
        #expect(try store.increment("visits", in: counters, by: 1) == 1)
        #expect(try store.increment("visits", in: counters, by: 2.5) == 3.5)
        #expect(store.entry("visits", in: counters)?.kind == .number)

        // Numbers stored as text (like converted 1.0 records) still count
        try store.set(.text("4"), for: "legacy", in: counters)
        #expect(try store.increment("legacy", in: counters, by: 1) == 5)

        try store.set(.text("abc"), for: "word", in: counters)
        #expect(throws: FolkError.notANumber(key: "word", value: "abc")) { try store.increment("word", in: counters, by: 1) }

        let water = try FieldPath("water")
        #expect(try store.increment("today", field: water, in: counters, by: 1) == 1)
        #expect(try store.increment("today", field: water, in: counters, by: 1) == 2)
        #expect(store.value("today", in: counters) == .object(["water": .number(2)]))
    }

    // MARK: Lists

    @Test func listOperations() throws {
        let lists = try store.createCollection(name: "Lists")
        #expect(try store.append([.string("a"), .string("b")], to: "queue", in: lists) == 2)
        #expect(try store.append([.number(3)], to: "queue", in: lists) == 3)
        #expect(try store.listItem(at: -1, of: "queue", in: lists) == .number(3))
        #expect(throws: FolkError.indexOutOfRange(5)) { try store.listItem(at: 5, of: "queue", in: lists) }

        #expect(try store.pop("queue", in: lists, from: .first) == .string("a"))
        #expect(try store.pop("queue", in: lists, from: .last) == .number(3))
        #expect(try store.list("queue", in: lists) == [.string("b")])

        try store.append([.string("x"), .string("b")], to: "queue", in: lists)
        #expect(try store.removeFromList("queue", in: lists, matching: "b") == 2)
        #expect(try store.removeFromList("queue", in: lists, at: 0) == 1)
        #expect(try store.pop("queue", in: lists, from: .first) == nil)
        #expect(try store.list("missing", in: lists).isEmpty)

        try store.set(.text("not a list"), for: "text", in: lists)
        #expect(throws: FolkError.notAList("text")) { try store.append([.string("x")], to: "text", in: lists) }
    }

    // MARK: Log entries

    @Test func logEntriesGetOrderedUniqueKeys() throws {
        let log = try store.createCollection(name: "Log")
        let first = try store.addEntry(.text("one"), to: log)
        let second = try store.addEntry(.text("two"), to: log) // same instant
        clock.advance(60)
        let third = try store.addEntry(.text("three"), to: log)

        #expect(first.key == DateCoding.string(from: Date(timeIntervalSince1970: 1_800_000_000)))
        #expect(second.key == first.key + "-002")
        #expect(Set([first.key, second.key, third.key]).count == 3)
        #expect(store.latestEntry(in: log)?.key == third.key)

        let recent = store.entries(in: log, from: clock.now.addingTimeInterval(-30))
        #expect(recent.map(\.key) == [third.key])
        let newestFirst = store.entries(in: log, sort: .created, ascending: false, limit: 2)
        #expect(newestFirst.map(\.key) == [third.key, second.key])
    }

    // MARK: Queries

    @Test func findEntries() throws {
        let moods = try store.createCollection(name: "Moods")
        try store.set(TypedValue(.object(["mood": .string("Happy"), "energy": .number(4)])), for: "mon", in: moods)
        try store.set(TypedValue(.object(["mood": .string("tired"), "energy": .number(2)])), for: "tue", in: moods)
        try store.set(TypedValue(.object(["mood": .string("happy"), "energy": .number(5), "note": .string("gym")])), for: "wed", in: moods)

        func keys(_ field: String?, _ op: MatchOperator, _ value: String = "", sort: EntrySort = .key, ascending: Bool = true) throws -> [String] {
            store.find(in: moods, field: try FieldPath.optional(field), operator: op, value: value, sort: sort, ascending: ascending).map(\.key)
        }
        #expect(try keys("mood", .equals, "HAPPY") == ["mon", "wed"])
        #expect(try keys("mood", .notEquals, "happy") == ["tue"])
        #expect(try keys("mood", .contains, "app") == ["mon", "wed"])
        #expect(try keys("mood", .beginsWith, "t") == ["tue"])
        #expect(try keys("energy", .greaterThan, "3") == ["mon", "wed"])
        #expect(try keys("energy", .lessThan, "3") == ["tue"])
        #expect(try keys("note", .exists) == ["wed"])
        #expect(try keys("energy", .exists, sort: .value, ascending: false) == ["wed", "mon", "tue"])
        #expect(store.find(in: moods, field: try FieldPath("energy"), operator: .exists, value: "", limit: 1).count == 1)
    }

    @Test func findComparesWholeValuesAndDates() throws {
        let scores = try store.createCollection(name: "Scores")
        try store.set(.number(10), for: "ann", in: scores)
        try store.set(.number(9), for: "bob", in: scores)
        try store.set(.date(Date(timeIntervalSince1970: 1_800_000_000)), for: "deadline", in: scores)

        #expect(store.find(in: scores, operator: .greaterThan, value: "9.5").map(\.key) == ["ann", "deadline"])
        #expect(store.find(in: scores, operator: .equals, value: "10.0").map(\.key) == ["ann"])
        let afterDate = store.find(in: scores, operator: .greaterThan, value: "2026-01-01").map(\.key)
        #expect(afterDate.contains("deadline"))
    }

    // MARK: Whole collection

    @Test func dictionaryAndBulkSet() throws {
        let settings = try store.createCollection(name: "Settings")
        try store.set(.text("dark"), for: "theme", in: settings)
        try store.set(.number(1), for: "old", in: settings)

        #expect(try store.setValues(["volume": .number(7), "theme": .string("light")], in: settings, mode: .merge) == 2)
        #expect(store.dictionary(of: settings) == .object(["theme": .string("light"), "volume": .number(7), "old": .number(1)]))

        try store.setValues(["only": .bool(true)], in: settings, mode: .replace)
        #expect(store.dictionary(of: settings) == .object(["only": .bool(true)]))
        #expect(store.keys(in: settings) == ["only"])
    }

    @Test func keysWithPrefix() throws {
        let collection = try store.createCollection(name: "C")
        for key in ["user.name", "user.city", "app.theme"] {
            try store.set(.text("x"), for: key, in: collection)
        }
        #expect(store.keys(in: collection, prefix: "USER.") == ["user.city", "user.name"])
    }

    // MARK: Import / export

    @Test func exportImportRoundTrip() throws {
        let settings = try store.createCollection(name: "Settings")
        let expiry = clock.now.addingTimeInterval(3600)
        try store.set(.text("01234"), for: "zip", in: settings)
        try store.set(.date(Date(timeIntervalSince1970: 1_800_000_000)), for: "lastRun", in: settings, expiry: .at(expiry))
        try store.set(TypedValue(.array([.string("tea"), .number(2)])), for: "favorites", in: settings)

        let imported = try store.importJSON(try store.exportData(settings))
        #expect(imported.name == "Settings (2)")
        #expect(store.entries(in: imported).map(\.key) == ["favorites", "lastRun", "zip"])
        #expect(store.entry("zip", in: imported)?.value == .text("01234"))
        #expect(store.entry("lastRun", in: imported)?.kind == .date)
        #expect(store.entry("lastRun", in: imported)?.expiresAt == expiry)
        #expect(store.value("favorites", in: imported) == .array([.string("tea"), .number(2)]))
    }

    @Test func importVersion1Export() throws {
        let json = #"{"id": "x", "name": "Books", "keyValueData": [{"id": "dune", "keyValuePairs": {"title": "Dune", "rating": "5"}}]}"#
        let books = try store.importJSON(Data(json.utf8))
        #expect(books.name == "Books")
        #expect(store.value("dune", in: books) == .object(["title": .string("Dune"), "rating": .string("5")]))
    }

    @Test func importPlainObjectAndArray() throws {
        let object = try store.importJSON(Data(#"{"theme": "dark", "count": 3, "tags": ["a"]}"#.utf8), fallbackName: "prefs")
        #expect(object.name == "prefs")
        #expect(store.entries(in: object).map(\.kind) == [.number, .list, .text]) // count, tags, theme

        let array = try store.importJSON(Data(#"[{"mood": "ok"}, {"mood": "great"}]"#.utf8), name: "Log")
        #expect(store.entries(in: array).count == 2)
        #expect(store.entries(in: array).allSatisfy { $0.kind == .dictionary })

        #expect(throws: FolkError.invalidJSON) { try store.importJSON(Data("nope".utf8)) }
        #expect(throws: FolkError.invalidJSON) { try store.importJSON(Data("42".utf8)) }
    }

    // MARK: Entities

    @Test func entryEntityExposesTypedValues() throws {
        let collection = try store.createCollection(name: "C")
        try store.set(TypedValue(.array([.string("tea"), .number(2)])), for: "list", in: collection)
        try store.set(.number(42), for: "answer", in: collection)

        let list = EntryEntity(try #require(store.entry("list", in: collection)))
        #expect(list.items == ["tea", "2"])
        #expect(list.count == 2)
        #expect(list.json == #"["tea",2]"#)
        #expect(list.collectionName == "C")

        let answer = EntryEntity(try #require(store.entry("answer", in: collection)))
        #expect(answer.text == "42")
        #expect(answer.number == 42)
        #expect(answer.kind == .number)
    }
}

@MainActor
struct LegacyMigratorTests {
    let container = Persistence.inMemory()
    var context: ModelContext { container.mainContext }

    private func legacyRecord(_ id: String, _ pairs: [String: String], in collection: Collection?) {
        let record = KeyValueData(id: id, keyValuePairs: pairs)
        context.insert(record)
        record.collection = collection
    }

    @Test func convertsRecordsAndRenamesDuplicateCollections() throws {
        let first = Collection(name: "Mood")
        let second = Collection(name: "mood")
        context.insert(first)
        context.insert(second)
        legacyRecord("r1", ["mood": "happy", "energy": "4"], in: first)
        legacyRecord("r2", ["mood": "tired"], in: second)
        legacyRecord("r3", ["lost": "yes"], in: nil)
        try context.save()

        #expect(try LegacyMigrator.migrate(context) == 3)

        let names = try context.fetch(FetchDescriptor<Collection>()).map(\.name)
        #expect(Set(names.map { $0.lowercased() }).count == names.count)
        #expect(names.contains { $0.hasSuffix("(2)") })
        #expect(names.contains(LegacyMigrator.recoveredCollectionName))
        #expect(try context.fetchCount(FetchDescriptor<KeyValueData>()) == 0)

        let store = FolkStore(context: context, indexesSpotlight: false)
        let r1 = try #require(store.entry("r1", in: first))
        #expect(r1.kind == .dictionary)
        #expect(r1.value.json == .object(["mood": .string("happy"), "energy": .string("4")]))
        #expect(store.entry("r2", in: second) != nil)
        let recovered = try #require(store.collection(named: LegacyMigrator.recoveredCollectionName))
        #expect(store.value("r3", field: try FieldPath("lost"), in: recovered) == .string("yes"))

        // Converted text numbers can still be incremented
        #expect(try store.increment("r1", field: FieldPath("energy"), in: first, by: 1) == 5)

        // Running again changes nothing
        #expect(try LegacyMigrator.migrate(context) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 3)
    }
}

struct TypedValueTests {
    @Test func automaticDetection() {
        #expect(TypedValue.detect("42") == .number(42))
        #expect(TypedValue.detect("-3.5") == .number(-3.5))
        #expect(TypedValue.detect("TRUE") == .bool(true))
        #expect(TypedValue.detect(#"{"a": 1}"#) == TypedValue(.object(["a": .number(1)])))
        #expect(TypedValue.detect("[1, \"x\"]") == TypedValue(.array([.number(1), .string("x")])))
        // These stay text
        for text in ["01234", "+4930123456", "4111111111111111", "hello", "1,5", "{not json"] {
            #expect(TypedValue.detect(text) == .text(text), "\(text)")
        }
    }

    @Test func explicitTypes() throws {
        #expect(try TypedValue.parse("01234", as: .text) == .text("01234"))
        #expect(try TypedValue.parse("2,5", as: .number) == .number(2.5))
        #expect(throws: FolkError.invalidValue(type: "number", value: "abc")) { try TypedValue.parse("abc", as: .number) }
        #expect(try TypedValue.parse("yes", as: .boolean) == .bool(true))
        #expect(try TypedValue.parse("2026-10-10", as: .date).kind == .date)
        #expect(try TypedValue.parse("2026-10-10T09:00:00Z", as: .date).date == Date(timeIntervalSince1970: 1_791_622_800))
        #expect(try TypedValue.parse("a\n2\ntrue", as: .list) == TypedValue(.array([.string("a"), .number(2), .bool(true)])))
        #expect(try TypedValue.parse("[\"x\"]", as: .list) == TypedValue(.array([.string("x")])))
        #expect(try TypedValue.parse("mood: happy\nenergy = 4", as: .dictionary) == TypedValue(.object(["mood": .string("happy"), "energy": .number(4)])))
        #expect(throws: FolkError.invalidJSON) { try TypedValue.parse("{broken", as: .dictionary) }
        #expect(throws: FolkError.invalidJSON) { try TypedValue.parse("no separator", as: .dictionary) }
    }

    @Test func displayText() {
        #expect(JSONValue.number(5).displayText == "5")
        #expect(JSONValue.number(2.25).displayText == "2.25")
        #expect(JSONValue.string("hi").displayText == "hi")
        #expect(JSONValue.object(["b": .number(1), "a": .string("x/y")]).displayText == #"{"a":"x/y","b":1}"#)
    }

    @Test func codableKeepsBooleansAndNumbersApart() throws {
        let value = JSONValue.array([.bool(true), .number(1), .null, .object(["k": .string("v")])])
        let decoded = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
        #expect(decoded == value)
    }

    @Test func fieldPaths() throws {
        let doc = JSONValue.object(["items": .array([.string("a"), .string("b")]), "address": .object(["city": .string("Berlin")])])
        #expect(doc.value(at: try FieldPath("address.city")) == .string("Berlin"))
        #expect(doc.value(at: try FieldPath("items.-1")) == .string("b"))
        #expect(doc.value(at: try FieldPath("items.5")) == nil)
        #expect(doc.value(at: try FieldPath("address.city.x")) == nil)

        let appended = try doc.setting(.string("c"), at: FieldPath("items.2"))
        #expect(appended.value(at: try FieldPath("items")) == .array([.string("a"), .string("b"), .string("c")]))
        #expect(throws: FolkError.indexOutOfRange(9)) { try doc.setting(.null, at: FieldPath("items.9")) }

        let created = try JSONValue.null.setting(.number(1), at: FieldPath("a.b"))
        #expect(created == .object(["a": .object(["b": .number(1)])]))

        let (removed, didRemove) = try doc.removing(at: FieldPath("items.0"))
        #expect(didRemove)
        #expect(removed.value(at: try FieldPath("items")) == .array([.string("b")]))

        #expect(throws: FolkError.invalidPath("a..b")) { try FieldPath("a..b") }
        #expect(throws: FolkError.invalidPath("")) { try FieldPath("") }
        #expect(try FieldPath.optional("  ") == nil)
    }
}
