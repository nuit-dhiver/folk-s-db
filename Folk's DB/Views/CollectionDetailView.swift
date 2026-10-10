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
    var openKey: String? = nil // Set when opened from Shortcuts or Spotlight

    @State private var searchText = ""
    @State private var sort: EntrySort = .key
    @State private var editing: EditorTarget?
    @State private var errorMessage: String?
    @State private var documentPickerDelegate: DocumentPickerDelegate? = nil

    private var store: FolkStore { FolkStore(context: context) }

    private var visibleEntries: [Entry] {
        let entries = store.sorted(store.entries(in: collection), by: sort, ascending: sort == .key)
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.key.localizedCaseInsensitiveContains(searchText) || ($0.textValue ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(visibleEntries) { entry in
                Button {
                    editing = .existing(entry)
                } label: {
                    EntryRow(entry: entry)
                }
                .foregroundStyle(.primary)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            try? store.deleteEntry(entry)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .overlay {
            if collection.entries.isEmpty {
                ContentUnavailableView(
                    "No Keys Yet",
                    systemImage: "key",
                    description: Text("Add a key here, or use “Set Value” and “Add Entry” in the Shortcuts app.")
                )
            } else if !searchText.isEmpty && visibleEntries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search keys and values")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Entry", systemImage: "plus") {
                    editing = .new
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Picker("Sort By", selection: $sort) {
                    Text("Key").tag(EntrySort.key)
                    Text("Last Updated").tag(EntrySort.updated)
                    Text("Date Added").tag(EntrySort.created)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Export Data", systemImage: "square.and.arrow.up") {
                    ExportCollection()
                }
            }
        }
        .sheet(item: $editing) { target in
            EntryEditorView(collection: collection, entry: target.entry)
        }
        .task(id: openKey) {
            if let openKey, let entry = store.entry(openKey, in: collection) {
                editing = .existing(entry)
            }
        }
        .alert("Export Failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationTitle(collection.name)
    }

    private func ExportCollection() {
        do {
            let exportedFileURL = try store.exportJSON(collection)

            let delegate = DocumentPickerDelegate()
            self.documentPickerDelegate = delegate

            // Show the iOS file picker for saving
            let documentPicker = UIDocumentPickerViewController(forExporting: [exportedFileURL])
            documentPicker.delegate = delegate

            // Find the current window scene and present the document picker
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(documentPicker, animated: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum EditorTarget: Identifiable {
    case new
    case existing(Entry)

    var id: String {
        switch self {
        case .new: "new"
        case .existing(let entry): entry.lookupKey
        }
    }

    var entry: Entry? {
        if case .existing(let entry) = self { entry } else { nil }
    }
}

private struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: entry.kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.key)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                // Under the value, like the Shortcuts card, so the time doesn't squeeze the key
                if let expiresAt = entry.expiresAt {
                    Label {
                        Text(expiresAt, style: .relative)
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .labelStyle(.titleAndIcon)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var preview: String {
        let value = entry.value
        if let date = value.date {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return value.displayText.isEmpty ? " " : value.displayText
    }
}
