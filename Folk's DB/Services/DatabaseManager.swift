//
//  DatabaseManager.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 27.11.24.
//
import Foundation
import SQLite3

import Foundation
import SQLite3

class SQLiteManager {
    private var db: OpaquePointer?

    init(databaseName: String) {
        openDatabase(databaseName: databaseName)
    }

    private func openDatabase(databaseName: String) {
        let fileURL = try! FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("\(databaseName).sqlite")

        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database.")
        }
    }

    func fetchRows(from tableName: String) -> [[String: Any]] {
        var queryStatement: OpaquePointer?
        var result: [[String: Any]] = []

        let queryString = "SELECT * FROM \(tableName);"
        if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                var row: [String: Any] = [:]
                for columnIndex in 0..<sqlite3_column_count(queryStatement) {
                    let columnName = String(cString: sqlite3_column_name(queryStatement, columnIndex))
                    let columnValue: Any
                    switch sqlite3_column_type(queryStatement, columnIndex) {
                    case SQLITE_INTEGER:
                        columnValue = sqlite3_column_int(queryStatement, columnIndex)
                    case SQLITE_FLOAT:
                        columnValue = sqlite3_column_double(queryStatement, columnIndex)
                    case SQLITE_TEXT:
                        columnValue = String(cString: sqlite3_column_text(queryStatement, columnIndex))
                    case SQLITE_NULL:
                        columnValue = NSNull()
                    default:
                        columnValue = NSNull()
                    }
                    row[columnName] = columnValue
                }
                result.append(row)
            }
        } else {
            print("SELECT statement could not be prepared.")
        }

        sqlite3_finalize(queryStatement)
        return result
    }
}
