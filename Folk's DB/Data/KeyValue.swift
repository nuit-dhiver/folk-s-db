//
//  KeyValue.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 29.11.24.
//
import SwiftData
import Foundation

@Model
class Collection {
    @Attribute(.unique) var id: String
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \KeyValueData.collection) var keyValueData: [KeyValueData]

    init(id: String = UUID().uuidString, name: String, keyValueData: [KeyValueData] = []) {
        self.id = id
        self.name = name
        self.keyValueData = keyValueData
    }
}

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
