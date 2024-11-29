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
    @Binding var existingData: KeyValueData? // Reference to existing data
    
    @State private var keyValuePairs: [String: String] = [:]
    @State private var key: String = ""
    @State private var value: String = ""

    var onSave: (KeyValueData) -> Void

    var body: some View {
        NavigationView {
            Form {
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
                    keyValuePairs = existingData.keyValuePairs // Load existing pairs
                }
            }
            .navigationTitle(existingData == nil ? "Add Data" : "Edit Data")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newData = KeyValueData(
                            id: existingData?.id ?? UUID().uuidString,
                            keyValuePairs: keyValuePairs
                        )
                        onSave(newData)
                        dismiss()
                    }
                }
            }
        }
    }
}
