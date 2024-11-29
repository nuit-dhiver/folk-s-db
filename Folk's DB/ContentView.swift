//
//  ContentView.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 27.11.24.
//
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context // SwiftData context
    @Query private var keyValueData: [KeyValueData] // Query all KeyValueData entries
    
    @State private var showAddEditSheet = false
    @State private var selectedData: KeyValueData? // For editing

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(keyValueData) { data in
                        VStack(alignment: .leading) {
                            Text("ID: \(data.id)").bold()
                            ForEach(data.keyValuePairs.keys.sorted(), id: \.self) { key in
                                Text("\(key): \(data.keyValuePairs[key] ?? "")")
                            }
                        }
                        .onTapGesture {
                            selectedData = data // Select data for editing
                            showAddEditSheet = true
                        }
                    }
                }
                
                Button("Add New Data") {
                    selectedData = nil // No selection for new data
                    showAddEditSheet = true
                }
                .padding()
            }
            .sheet(isPresented: $showAddEditSheet) {
                AddEditKeyValueView(existingData: $selectedData) { updatedData in
                    if let selectedData = selectedData {
                        // Update existing entry
                        selectedData.keyValuePairs = updatedData.keyValuePairs
                    } else {
                        // Add new entry
                        context.insert(updatedData)
                    }
                    try? context.save()
                }
            }
            .navigationTitle("VolksDB")
        }
    }
}
#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
