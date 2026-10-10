//
//  TypedValue.swift
//  Folk's DB
//
//  A JSON value together with its kind, and parsing of text input (which is how Shortcuts passes values).
//
import Foundation

enum ValueKind: String, CaseIterable, Sendable {
    case text, number, boolean, date, list, dictionary

    var systemImage: String {
        switch self {
        case .text: "textformat"
        case .number: "number"
        case .boolean: "switch.2"
        case .date: "calendar"
        case .list: "list.bullet"
        case .dictionary: "curlybraces"
        }
    }
}

/// How to read text input. `automatic` detects the type.
enum ValueType: String, CaseIterable, Sendable {
    case automatic, text, number, boolean, date, list, dictionary
}

struct TypedValue: Hashable, Sendable {
    let kind: ValueKind
    let json: JSONValue

    init(kind: ValueKind, json: JSONValue) {
        self.kind = kind
        self.json = json
    }

    /// The natural kind of a JSON value. Strings stay text; dates only come from an explicit date.
    init(_ json: JSONValue) {
        switch json {
        case .string, .null: kind = .text
        case .number: kind = .number
        case .bool: kind = .boolean
        case .array: kind = .list
        case .object: kind = .dictionary
        }
        self.json = json
    }

    static func text(_ text: String) -> TypedValue { TypedValue(kind: .text, json: .string(text)) }
    static func number(_ number: Double) -> TypedValue { TypedValue(kind: .number, json: .number(number)) }
    static func bool(_ bool: Bool) -> TypedValue { TypedValue(kind: .boolean, json: .bool(bool)) }
    static func date(_ date: Date) -> TypedValue { TypedValue(kind: .date, json: .string(DateCoding.string(from: date))) }

    var date: Date? {
        guard kind == .date, case .string(let text) = json else { return nil }
        return DateCoding.date(from: text)
    }

    /// Text shown to people and returned to Shortcuts. Dates use the ISO form so other actions can parse them.
    var displayText: String { json.displayText }

    /// Numbers, booleans (0/1) and dates (seconds since 1970) as a number, for sorting and comparing.
    var sortNumber: Double? {
        switch kind {
        case .number: json.number
        case .boolean: if case .bool(let bool) = json { bool ? 1 : 0 } else { nil }
        case .date: date?.timeIntervalSince1970
        default: nil
        }
    }

    // MARK: Parsing text input

    static func parse(_ text: String, as type: ValueType) throws -> TypedValue {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type {
        case .automatic:
            return detect(text)
        case .text:
            return .text(text)
        case .number:
            guard let number = JSONValue.parseNumber(trimmed) else { throw FolkError.invalidValue(type: "number", value: text) }
            return .number(number)
        case .boolean:
            guard let bool = parseBool(trimmed) else { throw FolkError.invalidValue(type: "boolean", value: text) }
            return .bool(bool)
        case .date:
            guard let date = DateCoding.parse(trimmed) else { throw FolkError.invalidValue(type: "date", value: text) }
            return .date(date)
        case .list:
            if trimmed.hasPrefix("["), let json = try? JSONValue.parse(trimmed), json.array != nil {
                return TypedValue(json)
            }
            let items = trimmed.isEmpty ? [] : trimmed.split(whereSeparator: \.isNewline).map { detect(String($0)).json }
            return TypedValue(.array(items))
        case .dictionary:
            if trimmed.isEmpty { return TypedValue(.object([:])) }
            if trimmed.hasPrefix("{") {
                guard let json = try? JSONValue.parse(trimmed), json.object != nil else { throw FolkError.invalidJSON }
                return TypedValue(json)
            }
            return TypedValue(.object(try parseLines(trimmed)))
        }
    }

    /// Detects a JSON object or list, true/false, or a plain number; everything else is text.
    /// Numbers with leading zeros, a "+" sign or more than 15 digits stay text, so zip codes, phone and card numbers survive.
    static func detect(_ text: String) -> TypedValue {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")), let json = try? JSONValue.parse(trimmed) {
            return TypedValue(json)
        }
        switch trimmed.lowercased() {
        case "true": return .bool(true)
        case "false": return .bool(false)
        default: break
        }
        if trimmed.wholeMatch(of: /-?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?/) != nil,
           trimmed.filter(\.isNumber).count <= 15,
           let number = Double(trimmed), number.isFinite {
            return .number(number)
        }
        return .text(text)
    }

    private static func parseBool(_ text: String) -> Bool? {
        switch text.lowercased() {
        case "true", "yes", "on", "1": true
        case "false", "no", "off", "0": false
        default: nil
        }
    }

    /// `key: value` (or `key = value`) lines, one pair per line.
    private static func parseLines(_ text: String) throws -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let separator = line.firstIndex(where: { $0 == ":" || $0 == "=" }) else { throw FolkError.invalidJSON }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { throw FolkError.invalidJSON }
            result[key] = detect(String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)).json
        }
        return result
    }
}

enum DateCoding {
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plain = Date.ISO8601FormatStyle()
    private static let dateOnly = Date.ISO8601FormatStyle().year().month().day()

    static func string(from date: Date) -> String {
        date.formatted(fractional)
    }

    /// Strict ISO 8601, as written by `string(from:)`.
    static func date(from text: String) -> Date? {
        (try? fractional.parse(text)) ?? (try? plain.parse(text))
    }

    /// A date without a time, like "2026-10-10".
    static func parseDay(_ text: String) -> Date? {
        try? dateOnly.parse(text)
    }

    /// ISO 8601 (with or without time), or any date a person might write, like "Oct 10, 2026 at 9:00".
    static func parse(_ text: String) -> Date? {
        if let date = date(from: text) ?? parseDay(text) {
            return date
        }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.date
    }
}
