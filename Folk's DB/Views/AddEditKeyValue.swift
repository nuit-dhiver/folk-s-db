//
//  AddEditKeyValue.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 29.11.24.
//
import SwiftUICore
import SwiftUI

struct AddEditKeyValueView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var existingData: KeyValueData? // Reference for editing
    var parentCollection: Collection // The collection the record belongs to

    @State private var recordID: String = ""
    @State private var keyValuePairs: [String: String] = [:]
    @State private var key: String = ""
    @State private var value: String = ""

    var onSave: (KeyValueData) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Record ID")) {
                    Text(recordID.isEmpty ? "New Record" : recordID)
                }

                Section(header: Text("Add Key-Value Pair")) {
                    TextField("Key", text: $key)
                    TextField("Value", text: $value)

                    Button("Add Pair") {
                        if !key.isEmpty {
                            keyValuePairs[key] = value
                            key = ""
                            value = ""
                        }
                    }
                }

                Section(header: Text("Current Pairs")) {
                    ForEach(keyValuePairs.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Text(keyValuePairs[key] ?? "")
                        }
                    }
                }
            }
            .onAppear {
                if let existingData = existingData {
                    recordID = existingData.id // Load record ID for editing
                    keyValuePairs = existingData.keyValuePairs
                } else {
                    recordID = UUID().uuidString // Generate new ID for new records
                }
            }
            .navigationTitle(existingData == nil ? "Add Record" : "Edit Record")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newData = KeyValueData(
                            id: recordID,
                            keyValuePairs: keyValuePairs,
                            collection: parentCollection
                        )

                        if let existingData = existingData {
                            existingData.keyValuePairs = keyValuePairs
                        } else {
                            parentCollection.keyValueData.append(newData) 
                            try? parentCollection.modelContext?.save()
                        }

                        onSave(newData)
                        dismiss()
                    }
                }


            }
        }
    }
}
