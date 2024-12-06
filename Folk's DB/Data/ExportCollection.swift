//
//  ExportCollection.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 06.12.24.
//
import Foundation

func ExportCollectionAsJSON(collection: Collection) throws -> URL {
    // Convert the Collection object into a dictionary format suitable for JSON
    let collectionDictionary: [String: Any] = [
        "id": collection.id,
        "name": collection.name,
        "keyValueData": collection.keyValueData.map { keyValueData in
            return [
                "id": keyValueData.id,
                "keyValuePairs": keyValueData.keyValuePairs
            ]
        }
    ]
    
    // Serialize the dictionary into JSON data
    let jsonData = try JSONSerialization.data(withJSONObject: collectionDictionary, options: .prettyPrinted)
    
    // Determine the file URL for saving the JSON file
    let fileName = "\(collection.name)-export.json"
    let temporaryDirectory = FileManager.default.temporaryDirectory
    let fileURL = temporaryDirectory.appendingPathComponent(fileName)
    
    // Write the JSON data to the file
    try jsonData.write(to: fileURL)
    
    // Return the file URL for further use (e.g., sharing)
    return fileURL
}
