//
//  ExecuteQueryIntent.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 28.11.24.
//
import AppIntents
import SQLite3


struct ExecuteQuery: AppIntent {
    
    static var title: LocalizedStringResource = "Execute Query"
    static var description: IntentDescription = "Execute a user-provided SQL query on a SQLite database."
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult{
        //navigationModel.selectedCollection = trailManager.favoritesCollection
        return .result()
    }
    
    }



