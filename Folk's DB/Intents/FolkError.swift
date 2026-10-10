//
//  FolkError.swift
//  Folk's DB
//
//  Errors with messages that Shortcuts shows to the user.
//
import AppIntents
import Foundation

enum FolkError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case emptyName
    case emptyKey
    case collectionNotFound(String)
    case collectionExists(String)
    case keyNotFound(String)
    case keyExists(String)
    case emptyCollection(String)
    case invalidJSON
    case invalidValue(type: String, value: String)
    case invalidPath(String)
    case notANumber(key: String, value: String)
    case notAList(String)
    case notADictionary
    case indexOutOfRange(Int)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyName:
            return "The name can't be empty."
        case .emptyKey:
            return "The key can't be empty."
        case .collectionNotFound(let name):
            return "There's no collection named “\(name)”."
        case .collectionExists(let name):
            return "A collection named “\(name)” already exists."
        case .keyNotFound(let key):
            return "There's no key “\(key)”."
        case .keyExists(let key):
            return "The key “\(key)” already exists."
        case .emptyCollection(let name):
            return "The collection “\(name)” is empty."
        case .invalidJSON:
            return "The value must be a Dictionary, a JSON object, or “key: value” lines."
        case .invalidValue(let type, let value):
            return "“\(value)” isn't a valid \(type)."
        case .invalidPath(let path):
            return "“\(path)” isn't a valid field path. Use dots between names, like address.city or items.0."
        case .notANumber(let key, let value):
            return "The value of “\(key)” is “\(value)”, which isn't a number."
        case .notAList(let key):
            return "The value of “\(key)” isn't a list."
        case .notADictionary:
            return "The field path goes through a value that isn't a dictionary or list."
        case .indexOutOfRange(let index):
            return "There's no item at position \(index)."
        }
    }
}

extension FolkError: LocalizedError {
    var errorDescription: String? { String(localized: localizedStringResource) }
}
