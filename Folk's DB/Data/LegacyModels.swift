//
//  LegacyModels.swift
//  Folk's DB
//
//  The record model from version 1.0, kept exactly as it shipped so existing stores open.
//  LegacyMigrator converts these rows into entries on launch. Don't use it for new data.
//
import Foundation
import SwiftData

@Model
class KeyValueData {
    @Attribute(.unique) var id: String // Unique record ID
    var keyValuePairs: [String: String] // Key-value attributes
    var collection: Collection?

    init(id: String = UUID().uuidString, keyValuePairs: [String: String] = [:], collection: Collection? = nil) {
        self.id = id
        self.keyValuePairs = keyValuePairs
        self.collection = collection
    }
}
