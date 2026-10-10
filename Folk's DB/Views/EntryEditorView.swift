//
//  EntryEditorView.swift
//  Folk's DB
//
//  Create or edit a key and its typed value.
//
import SwiftUI
import SwiftData

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let collection: Collection
    let entry: Entry? // nil when adding a new key

    @State private var key = ""
    @State private var kind: ValueKind = .text
    @State private var text = ""
    @State private var number = ""
    @State private var bool = false
    @State private var date = Date.now
    @State private var listItems: [EditableItem] = []
    @State private var fields: [EditableField] = []
    @State private var hasExpiry = false
    @State private var expiresAt = Date.now.addingTimeInterval(60 * 60)
    @State private var errorMessage: String?
    @State private var loaded = false

    private var store: FolkStore { FolkStore(context: context) }

    private var trimmedKey: String { key.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var keyTaken: Bool {
        !trimmedKey.isEmpty && trimmedKey != entry?.key && store.entry(trimmedKey, in: collection) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Key", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Key")
                } footer: {
                    if keyTaken {
                        Text("“\(trimmedKey)” already exists in this collection.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Value") {
                    Picker("Type", selection: $kind) {
                        ForEach(ValueKind.allCases, id: \.self) { kind in
                            Label(kind.rawValue.capitalized, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    valueEditor
                }

                Section {
                    Toggle("Expires", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Expires At", selection: $expiresAt, in: Date.now...)
                    }
                } footer: {
                    Text("An expired key is removed and reads as missing.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedKey.isEmpty || keyTaken)
                }
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private var valueEditor: some View {
        switch kind {
        case .text:
            TextField("Value", text: $text, axis: .vertical)
                .lineLimit(1...8)
                .accessibilityIdentifier("entryTextValue")
        case .number:
            TextField("Value", text: $number)
                .keyboardType(.decimalPad)
        case .boolean:
            Toggle("Value", isOn: $bool)
        case .date:
            DatePicker("Value", selection: $date)
        case .list:
            ForEach($listItems) { $item in
                TextField("Item", text: $item.text)
            }
            .onDelete { listItems.remove(atOffsets: $0) }
            .onMove { listItems.move(fromOffsets: $0, toOffset: $1) }
            Button("Add Item", systemImage: "plus") {
                listItems.append(EditableItem())
            }
        case .dictionary:
            ForEach($fields) { $field in
                HStack {
                    TextField("Field", text: $field.key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Divider()
                    TextField("Value", text: $field.value)
                }
            }
            .onDelete { fields.remove(atOffsets: $0) }
            Button("Add Field", systemImage: "plus") {
                fields.append(EditableField())
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let entry else { return }
        let value = entry.value
        key = entry.key
        kind = value.kind
        // Fill every editor from the current value, so switching the type carries it over where it makes sense
        text = value.displayText
        number = value.json.number.map(JSONValue.format) ?? ""
        if case .bool(let current) = value.json { bool = current }
        date = value.date ?? .now
        listItems = (value.json.array ?? []).map { EditableItem(text: $0.displayText) }
        fields = (value.json.object ?? [:]).sorted { $0.key < $1.key }.map { EditableField(key: $0.key, value: $0.value.displayText) }
        hasExpiry = entry.expiresAt != nil
        expiresAt = entry.expiresAt ?? expiresAt
    }

    private func buildValue() throws -> TypedValue {
        switch kind {
        case .text:
            return .text(text)
        case .number:
            guard let value = JSONValue.parseNumber(number) else { throw FolkError.invalidValue(type: "number", value: number) }
            return .number(value)
        case .boolean:
            return .bool(bool)
        case .date:
            return .date(date)
        case .list:
            // Items are detected like Shortcuts input: numbers, true/false and JSON become typed, everything else stays text
            return TypedValue(kind: .list, json: .array(listItems.map { TypedValue.detect($0.text).json }))
        case .dictionary:
            var object: [String: JSONValue] = [:]
            for field in fields {
                let fieldKey = field.key.trimmingCharacters(in: .whitespaces)
                if !fieldKey.isEmpty { object[fieldKey] = TypedValue.detect(field.value).json }
            }
            return TypedValue(kind: .dictionary, json: .object(object))
        }
    }

    private func save() {
        do {
            let value = try buildValue()
            let newKey = try store.validKey(key)
            let expiry: Expiry = hasExpiry ? .at(expiresAt) : .clear
            if let entry, newKey != entry.key {
                try store.renameKey(entry.key, to: newKey, in: collection)
            } else if entry == nil, store.entry(newKey, in: collection) != nil {
                throw FolkError.keyExists(newKey)
            }
            try store.set(value, for: newKey, in: collection, expiry: expiry)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EditableItem: Identifiable {
    let id = UUID()
    var text = ""
}

private struct EditableField: Identifiable {
    let id = UUID()
    var key = ""
    var value = ""
}
