//
//  CollectionView.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 02.12.24.
//
import SwiftUI



struct AddCollectionView: View {
    @Environment(\.dismiss) var dismiss

    @State private var collectionName: String = ""
    @State private var errorMessage: String?
    var onSave: (String) throws -> Void

    var body: some View {
        NavigationView {
            Form {
                TextField("Collection Name", text: $collectionName)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("New Collection")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        do {
                            try onSave(collectionName)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(collectionName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
