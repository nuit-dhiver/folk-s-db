//
//  ReadTableDataIntent.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 27.11.24.
//
import AppIntents

struct ReadTableDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Data from Table"

    static var description = IntentDescription(
        "Reads all rows from the specified table in the embedded SQLite database.",
        categoryName: "Database"
    )

    @Parameter(title: "Table Name")
    var tableName: String

    func perform() async throws -> some IntentResult {
        // Initialize SQLiteManager
        let sqliteManager = SQLiteManager(databaseName: "MyDatabase")

        // Fetch rows from the specified table
        let rows = sqliteManager.fetchRows(from: tableName)

        // Format the result as a string for Shortcuts
        let formattedResult = rows
            .map { $0.map { "\($0.key): \($0.value)" }.joined(separator: ", ") }
            .joined(separator: "\n")

        return .result(dialog: "Data fetched from \(tableName):\n\(formattedResult)")
    }
}
