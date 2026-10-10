//
//  CollectionExport.swift
//  Folk's DB
//
//  The JSON file format for exporting and importing a collection.
//
//  {"format": "folks-db", "version": 2, "name": "Settings", "exportedAt": "...",
//   "entries": [{"key": "theme", "type": "text", "value": "dark", "createdAt": "...", "updatedAt": "...", "expiresAt": null}]}
//
import Foundation

struct CollectionExport: Codable {
    static let formatName = "folks-db"

    var format = CollectionExport.formatName
    var version = 2
    var name: String
    var exportedAt: Date
    var entries: [Item]

    struct Item: Codable {
        var key: String
        var type: String
        var value: JSONValue
        var createdAt: Date?
        var updatedAt: Date?
        var expiresAt: Date?
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension FolkStore {
    func exportData(_ collection: Collection) throws -> Data {
        let export = CollectionExport(
            name: collection.name,
            exportedAt: now(),
            entries: entries(in: collection).map { entry in
                CollectionExport.Item(
                    key: entry.key,
                    type: entry.kind.rawValue,
                    value: entry.value.json,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt,
                    expiresAt: entry.expiresAt
                )
            }
        )
        return try CollectionExport.encoder.encode(export)
    }

    /// Writes the export to a temporary file and returns its URL.
    func exportJSON(_ collection: Collection) throws -> URL {
        let safeName = collection.name.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).json")
        try exportData(collection).write(to: url)
        return url
    }

    /// Creates a new collection from JSON. Accepts:
    /// - this app's export format
    /// - the version 1.0 export (`{"name", "keyValueData": [{"id", "keyValuePairs"}]}`); record IDs become keys
    /// - a plain object, where each key becomes an entry
    /// - a list, where each item becomes an entry with a generated key
    /// The name is `overrideName`, else the one in the file, else `fallbackName`; " (2)" is added if it's taken.
    @discardableResult
    func importJSON(_ data: Data, name overrideName: String? = nil, fallbackName: String = "Imported") throws -> Collection {
        guard let text = String(data: data, encoding: .utf8), let json = try? JSONValue.parse(text) else { throw FolkError.invalidJSON }

        var fileName: String?
        var items: [CollectionExport.Item] = []
        switch json {
        case .object(let object) where object["format"] == .string(CollectionExport.formatName):
            let export = try CollectionExport.decoder.decode(CollectionExport.self, from: data)
            fileName = export.name
            items = export.entries
        case .object(let object) where object["keyValueData"]?.array != nil:
            if case .string(let name)? = object["name"] { fileName = name }
            for record in object["keyValueData"]?.array ?? [] {
                guard let fields = record.object else { continue }
                let key = fields["id"].map(\.displayText) ?? ""
                let pairs = fields["keyValuePairs"]?.object ?? [:]
                items.append(CollectionExport.Item(key: key, type: ValueKind.dictionary.rawValue, value: .object(pairs)))
            }
        case .object(let object):
            items = object.map { CollectionExport.Item(key: $0.key, type: TypedValue($0.value).kind.rawValue, value: $0.value) }
        case .array(let array):
            items = array.map { CollectionExport.Item(key: "", type: TypedValue($0).kind.rawValue, value: $0) }
        default:
            throw FolkError.invalidJSON
        }

        let requested = [overrideName, fileName, fallbackName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Imported"
        let collection = try createCollection(name: uniqueCollectionName(requested))

        var usedKeys = Set<String>()
        var written: [Entry] = []
        for item in items {
            var key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty || usedKeys.contains(key) {
                key = nextLogKey(in: collection, reserved: usedKeys)
            }
            usedKeys.insert(key)
            let kind = ValueKind(rawValue: item.type) ?? TypedValue(item.value).kind
            let entry = try write(TypedValue(kind: kind, json: item.value), key: key, existing: nil, in: collection, expiry: .clear, saving: false)
            entry.createdAt = item.createdAt ?? entry.createdAt
            entry.updatedAt = item.updatedAt ?? entry.updatedAt
            entry.expiresAt = item.expiresAt
            written.append(entry)
        }
        try save()
        index(entries: written, collections: [collection])
        return collection
    }
}
