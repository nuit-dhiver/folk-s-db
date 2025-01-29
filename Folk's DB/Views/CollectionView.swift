//
//  CollectionView.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 02.12.24.
//
import SwiftUI
import SwiftUICore



struct AddCollectionView: View {
    @Environment(\.dismiss) var dismiss

    @State private var collectionName: String = ""
    var onSave: (Collection) -> Void

    var body: some View {
        NavigationView {
            Form {
                TextField("Collection Name", text: $collectionName)
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
                        let newCollection = Collection(name: collectionName)
                        onSave(newCollection)
                        dismiss()
                    }
                }
            }
        }
    }
}

