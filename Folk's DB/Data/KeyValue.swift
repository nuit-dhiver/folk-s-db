//
//  KeyValue.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 29.11.24.
//
import SwiftData
import Foundation

@Model
class KeyValueData {
    @Attribute(.unique) var id: String // Unique identifier for each entry
    var keyValuePairs: [String: String] // User-defined key-value pairs
    
    init(id: String = UUID().uuidString, keyValuePairs: [String: String] = [:]) {
        self.id = id
        self.keyValuePairs = keyValuePairs
    }
}
