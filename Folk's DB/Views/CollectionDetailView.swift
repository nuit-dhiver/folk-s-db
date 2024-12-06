//
//  CollectionDetailView.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 02.12.24.
//
import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var collection: Collection

    @State private var showAddEditSheet = false
    @State private var selectedData: KeyValueData? // For editing existing data
    @State private var showingShareSheet = false
    @State private var fileURL: URL? // URL of the exported JSON file

    var body: some View {
        VStack {
            List {
                ForEach(collection.keyValueData) { data in
                    VStack(alignment: .leading) {
                        Text("Record ID: \(data.id)").bold()
                        ForEach(data.keyValuePairs.keys.sorted(), id: \.self) { key in
                            Text("\(key): \(data.keyValuePairs[key] ?? "")")
                        }
                    }
                    .onTapGesture {
                        selectedData = data
                        showAddEditSheet = true
                    }
                }
            }

            HStack {
                Button("Add Record") {
                    selectedData = nil // New record
                    showAddEditSheet = true
                }
                .padding()

                Button("Export Data") {
                    ExportAndShareCollection()
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAddEditSheet) {
            AddEditKeyValueView(
                existingData: $selectedData,
                parentCollection: collection
            ) { updatedData in
                if let selectedData = selectedData {
                    selectedData.keyValuePairs = updatedData.keyValuePairs // Update existing record
                } else {
                    context.insert(updatedData) // Add new record
                }
                try? context.save()
            }
        }
        .sheet(isPresented: $showingShareSheet, content: {
            if let fileURL = fileURL {
                Text("Preparing to share file: \(fileURL.path)")
                ShareSheet(activityItems: [fileURL])
            } else {
                Text("No file URL available for sharing.")
            }
        })
            
        .navigationTitle(collection.name)
    }

    private func ExportAndShareCollection() {
        do {
            let exportedFileURL = try ExportCollectionAsJSON(collection: collection)
            self.fileURL = exportedFileURL
            showingShareSheet = true
        } catch {
            print("Failed to export collection: \(error)")
        }
    }
}
