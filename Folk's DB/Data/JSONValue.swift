//
//  JSONValue.swift
//  Folk's DB
//
//  The value stored under a key: text, number, boolean, date, list or dictionary.
//  Stored as canonical JSON; dates are ISO 8601 strings tagged with the `date` kind.
//
import Foundation

indirect enum JSONValue: Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Conversions

extension JSONValue {
    init(any: Any) {
        switch any {
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            self = CFGetTypeID(number) == CFBooleanGetTypeID() ? .bool(number.boolValue) : .number(number.doubleValue)
        case let array as [Any]:
            self = .array(array.map(JSONValue.init(any:)))
        case let object as [String: Any]:
            self = .object(object.mapValues(JSONValue.init(any:)))
        default:
            self = .null
        }
    }

    var anyValue: Any {
        switch self {
        case .string(let string): string
        case .number(let number): number
        case .bool(let bool): bool
        case .null: NSNull()
        case .array(let array): array.map(\.anyValue)
        case .object(let object): object.mapValues(\.anyValue)
        }
    }

    /// Parses any JSON text, including bare values like `42` or `"hi"`.
    static func parse(_ text: String) throws -> JSONValue {
        guard let data = text.data(using: .utf8),
              let any = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else {
            throw FolkError.invalidJSON
        }
        return JSONValue(any: any)
    }

    var jsonText: String {
        let data = try? JSONSerialization.data(withJSONObject: anyValue, options: [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed])
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "null"
    }

    /// Human-readable text: plain strings without quotes, "5" rather than "5.0", JSON for lists and dictionaries.
    var displayText: String {
        switch self {
        case .string(let string): string
        case .number(let number): Self.format(number)
        case .bool(let bool): bool ? "true" : "false"
        case .null: ""
        case .array, .object: jsonText
        }
    }

    var number: Double? {
        switch self {
        case .number(let number): number
        case .string(let string): Self.parseNumber(string)
        default: nil
        }
    }

    var array: [JSONValue]? {
        if case .array(let array) = self { array } else { nil }
    }

    var object: [String: JSONValue]? {
        if case .object(let object) = self { object } else { nil }
    }

    static func format(_ number: Double) -> String {
        if number.rounded() == number, abs(number) < 1e15 {
            return String(Int64(number))
        }
        return String(number)
    }

    static func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let number = Double(trimmed), number.isFinite { return number }
        // Accept a decimal comma ("2,5") when there's no decimal point
        if !trimmed.contains("."), let number = Double(trimmed.replacingOccurrences(of: ",", with: ".")), number.isFinite {
            return number
        }
        return nil
    }
}

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string): try container.encode(string)
        case .number(let number): try container.encode(number)
        case .bool(let bool): try container.encode(bool)
        case .null: try container.encodeNil()
        case .array(let array): try container.encode(array)
        case .object(let object): try container.encode(object)
        }
    }
}

// MARK: - Field paths

/// A dot-separated path into dictionaries and lists, e.g. `address.city` or `items.0` (`-1` is the last item).
struct FieldPath: Hashable, Sendable {
    let components: [String]

    init(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: ".", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard !trimmed.isEmpty, !components.contains(where: \.isEmpty) else { throw FolkError.invalidPath(text) }
        self.components = components
    }

    /// nil for nil or blank text, so optional intent parameters can be passed straight through.
    static func optional(_ text: String?) throws -> FieldPath? {
        guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return try FieldPath(text)
    }

    var description: String { components.joined(separator: ".") }
}

extension JSONValue {
    func value(at path: FieldPath?) -> JSONValue? {
        guard let path else { return self }
        var current = self
        for component in path.components {
            switch current {
            case .object(let object):
                guard let next = object[component] else { return nil }
                current = next
            case .array(let array):
                guard let index = Self.index(component, count: array.count) else { return nil }
                current = array[index]
            default:
                return nil
            }
        }
        return current
    }

    /// Returns a copy with `newValue` at `path`, creating dictionaries along the way.
    func setting(_ newValue: JSONValue, at path: FieldPath?) throws -> JSONValue {
        guard let path else { return newValue }
        return try setting(newValue, at: path.components[...])
    }

    private func setting(_ newValue: JSONValue, at path: ArraySlice<String>) throws -> JSONValue {
        guard let first = path.first else { return newValue }
        let rest = path.dropFirst()
        switch self {
        case .object(var object):
            object[first] = try (object[first] ?? .null).setting(newValue, at: rest)
            return .object(object)
        case .array(var array):
            if let index = Self.index(first, count: array.count) {
                array[index] = try array[index].setting(newValue, at: rest)
            } else if Int(first) == array.count {
                array.append(try JSONValue.null.setting(newValue, at: rest))
            } else {
                throw FolkError.indexOutOfRange(Int(first) ?? 0)
            }
            return .array(array)
        case .null:
            return .object([first: try JSONValue.null.setting(newValue, at: rest)])
        default:
            throw FolkError.notADictionary
        }
    }

    /// Returns a copy without the value at `path`, and whether anything was removed.
    func removing(at path: FieldPath) throws -> (JSONValue, Bool) {
        try removing(at: path.components[...])
    }

    private func removing(at path: ArraySlice<String>) throws -> (JSONValue, Bool) {
        guard let first = path.first else { return (self, false) }
        let rest = path.dropFirst()
        switch self {
        case .object(var object):
            guard let child = object[first] else { return (self, false) }
            if rest.isEmpty {
                object.removeValue(forKey: first)
                return (.object(object), true)
            }
            let (newChild, removed) = try child.removing(at: rest)
            object[first] = newChild
            return (.object(object), removed)
        case .array(var array):
            guard let index = Self.index(first, count: array.count) else { return (self, false) }
            if rest.isEmpty {
                array.remove(at: index)
                return (.array(array), true)
            }
            let (newChild, removed) = try array[index].removing(at: rest)
            array[index] = newChild
            return (.array(array), removed)
        default:
            throw FolkError.notADictionary
        }
    }

    /// Resolves a list index; negative numbers count from the end.
    static func index(_ text: String, count: Int) -> Int? {
        guard let index = Int(text) else { return nil }
        return Self.index(index, count: count)
    }

    static func index(_ index: Int, count: Int) -> Int? {
        let resolved = index < 0 ? count + index : index
        return (0..<count).contains(resolved) ? resolved : nil
    }
}
