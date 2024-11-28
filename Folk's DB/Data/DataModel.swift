//
//  DataModel.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 28.11.24.
//
import Foundation
import SwiftData

// The main model class
@Model
class UserDefinedData {
    @Attribute(.unique) var id: String
    var dynamicFieldsJSON: String // JSON representation of dynamic fields

    init(id: String, dynamicFields: [String: CodableValue]) {
        self.id = id
        self.dynamicFieldsJSON = Self.encodeDynamicFields(dynamicFields)
    }
    
    // Helper to encode dynamic fields into JSON
    static func encodeDynamicFields(_ fields: [String: CodableValue]) -> String {
        let encoder = JSONEncoder()
        if let jsonData = try? encoder.encode(fields),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}" // Default to empty JSON
    }
    
    // Helper to decode JSON into dynamic fields
    func decodedDynamicFields() -> [String: CodableValue] {
        let decoder = JSONDecoder()
        if let jsonData = dynamicFieldsJSON.data(using: .utf8),
           let fields = try? decoder.decode([String: CodableValue].self, from: jsonData) {
            return fields
        }
        return [:] // Default to empty dictionary
    }
}

// CodableValue enum remains the same
enum CodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    
    // Decoding logic
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            throw DecodingError.typeMismatch(CodableValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    // Encoding logic
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}

