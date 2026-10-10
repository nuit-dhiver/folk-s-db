//
//  TransferIntents.swift
//  Folk's DB
//
//  Export and import collections as JSON files.
//
import AppIntents
import Foundation
import SwiftData
import UniformTypeIdentifiers

struct ExportCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Collection as JSON"
    static let description = IntentDescription("Exports a collection, with every key, value and date, as a JSON file.", categoryName: "Import & Export")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Collection")
    var collection: CollectionEntity

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Export \(\.$collection) as JSON")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let store = FolkStore(container: container)
        let url = try store.exportJSON(try store.requireCollection(collection))
        return .result(value: IntentFile(fileURL: url, filename: url.lastPathComponent, type: .json))
    }
}

struct ImportCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Import Collection from JSON"
    static let description = IntentDescription(
        "Creates a collection from a Folk's DB export (new or old format), a Dictionary (each key becomes a key), or a List (each item becomes an entry).",
        categoryName: "Import & Export"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "JSON File", supportedContentTypes: [.json, .plainText])
    var file: IntentFile

    @Parameter(title: "Collection Name", description: "Optional. Overrides the name stored in the file.")
    var name: String?

    @Dependency var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Import \(\.$file) as a collection") {
            \.$name
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<CollectionEntity> {
        let store = FolkStore(container: container)
        let fallbackName = (file.filename as NSString).deletingPathExtension
        let collection = try store.importJSON(file.data, name: name, fallbackName: fallbackName)
        return .result(value: CollectionEntity(collection))
    }
}
