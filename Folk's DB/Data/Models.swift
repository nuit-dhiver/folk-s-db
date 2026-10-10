//
//  Models.swift
//  Folk's DB
//
//  A Collection is a namespace of unique keys. Each Entry maps one key to a typed value.
//  Schema changes must stay additive (new optional properties or new models) so stores from
//  earlier App Store versions keep opening with lightweight migration.
//
import Foundation
import SwiftData

@Model
class Collection {
    @Attribute(.unique) var id: String
    var name: String // Unique (case-insensitive), enforced by FolkStore rather than the schema so old stores with duplicates still open
    @Relationship(deleteRule: .cascade, inverse: \Entry.collection) var entries: [Entry] = []
    // Version 1.0 records; converted to entries on launch by LegacyMigrator
    @Relationship(deleteRule: .cascade, inverse: \KeyValueData.collection) var keyValueData: [KeyValueData] = []

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}

@Model
final class Entry {
    #Index<Entry>([\.key], [\.updatedAt], [\.expiresAt])

    // "<collection id>\u{1F}<key>": makes a key unique within its collection, and serves as the Shortcuts entity ID
    @Attribute(.unique) var lookupKey: String
    var key: String
    var kindRaw: String
    var json: String
    // Copies of the value for searching and sorting
    var textValue: String?
    var numberValue: Double?
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date?
    var collection: Collection?

    /// Insert the entry into a context before setting `collection`.
    init(key: String, value: TypedValue, collectionID: String, now: Date, expiresAt: Date? = nil) {
        self.lookupKey = Entry.lookupKey(collectionID: collectionID, key: key)
        self.key = key
        self.kindRaw = value.kind.rawValue
        self.json = value.json.jsonText
        self.textValue = value.displayText
        self.numberValue = value.sortNumber
        self.createdAt = now
        self.updatedAt = now
        self.expiresAt = expiresAt
    }

    static func lookupKey(collectionID: String, key: String) -> String {
        "\(collectionID)\u{1F}\(key)"
    }

    var kind: ValueKind { ValueKind(rawValue: kindRaw) ?? .text }

    var value: TypedValue {
        get { TypedValue(kind: kind, json: (try? JSONValue.parse(json)) ?? .string(json)) }
        set {
            kindRaw = newValue.kind.rawValue
            json = newValue.json.jsonText
            textValue = newValue.displayText
            numberValue = newValue.sortNumber
        }
    }

    func isExpired(at date: Date) -> Bool {
        expiresAt.map { $0 <= date } ?? false
    }
}
