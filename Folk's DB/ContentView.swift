//
//  ContentView.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 27.11.24.
//
import AppIntents
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum Route: Hashable {
    case collection(id: String, openKey: String? = nil)
}

struct ContentView: View {
    @Environment(\.modelContext) private var context // SwiftData context
    @Query(sort: \Collection.name) private var collections: [Collection] // Query all collections

    @State private var showAddCollectionSheet = false
    @State private var showImporter = false
    @State private var path: [Route] = []
    @State private var searchText = ""
    @State private var renaming: Collection?
    @State private var newName = ""
    @State private var errorMessage: String?

    private var store: FolkStore { FolkStore(context: context) }

    private var visibleCollections: [Collection] {
        guard !searchText.isEmpty else { return collections }
        return collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                List {
                    ForEach(visibleCollections) { collection in
                        NavigationLink(value: Route.collection(id: collection.id)) {
                            LabeledContent(collection.name) {
                                Text("\(collection.entries.count)")
                            }
                        }
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                newName = collection.name
                                renaming = collection
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    try? store.deleteCollection(collection)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .overlay {
                    if collections.isEmpty {
                        ContentUnavailableView(
                            "No Collections",
                            systemImage: "tray",
                            description: Text("A collection holds keys and their values. Create one here or from the Shortcuts app.")
                        )
                    }
                }
                .searchable(text: $searchText, prompt: "Search collections")

                Button("Add New Collection") {
                    showAddCollectionSheet = true
                }
                .padding()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case let .collection(id, openKey):
                    if let collection = store.collection(id: id) {
                        CollectionDetailView(collection: collection, openKey: openKey)
                    } else {
                        ContentUnavailableView("Collection Not Found", systemImage: "tray")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Import", systemImage: "square.and.arrow.down") {
                        showImporter = true
                    }
                }
            }
            .sheet(isPresented: $showAddCollectionSheet) {
                AddCollectionView { name in
                    try store.createCollection(name: name)
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                importCollection(result)
            }
            .alert("Rename Collection", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    if let renaming {
                        do {
                            try store.renameCollection(renaming, to: newName)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .alert("Something Went Wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .navigationTitle("Collections")
        }
        // Opened from Shortcuts, Siri or a Spotlight result
        .onAppIntentExecution(OpenCollectionIntent.self) { intent in
            path = [.collection(id: intent.target.id)]
        }
        .onAppIntentExecution(OpenEntryIntent.self) { intent in
            path = [.collection(id: intent.target.collectionID, openKey: intent.target.key)]
        }
        Text("Made with 😐 in Germany")
    }

    private func importCollection(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let collection = try store.importJSON(try Data(contentsOf: url), fallbackName: url.deletingPathExtension().lastPathComponent)
            path = [.collection(id: collection.id)]
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#Preview {
    ContentView()
        .modelContainer(Persistence.inMemory())
}
