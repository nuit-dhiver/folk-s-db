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
    @Query private var collections: [Collection] // Query all collections

    @State private var showAddCollectionSheet = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(collections) { collection in
                        NavigationLink(destination: CollectionDetailView(collection: collection)) {
                            Text(collection.name)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    context.delete(collection)
                                    try? context.save()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                
                Button("Add New Collection") {
                    showAddCollectionSheet = true
                }
                .padding()
            }
            .sheet(isPresented: $showAddCollectionSheet) {
                AddCollectionView { newCollection in
                    context.insert(newCollection)
                    try? context.save()
                }
            }
            .navigationTitle("Collections")
        }
        Text("Made with 😐 in Germany")
    }
}
#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
