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
    @State private var documentPickerDelegate: DocumentPickerDelegate? = nil

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
                    ExportCollection()
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
            ShareSheet(activityItems: [fileURL])
        })
            
        .navigationTitle(collection.name)
    }

    private func ExportCollection() {
        do {
            let exportedFileURL = try ExportCollectionAsJSON(collection: collection)
            self.fileURL = exportedFileURL
            
            let delegate = DocumentPickerDelegate()
            self.documentPickerDelegate = delegate
            
            // Show the iOS file picker for saving
            let documentPicker = UIDocumentPickerViewController(forExporting: [exportedFileURL])
            documentPicker.delegate = delegate
            
            // Find the current window scene and present the document picker
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(documentPicker, animated: true) {
                    //self.showSaveAlert = true
                }
        }
        } catch {
            print("Error exporting collection: \(error)")
        }
    }
    }
    
