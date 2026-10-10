//
//  EntrySnippetView.swift
//  Folk's DB
//
import AppIntents
import SwiftUI

struct EntrySnippetView: View {
    let entry: EntryEntity
    let collection: CollectionEntity

    private static let maxRows = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            switch entry.typed.json {
            case .number(let number) where entry.kind == .number:
                numberRow(label: entry.key, number: number, field: nil)
            case .object(let object):
                let keys = object.keys.sorted()
                ForEach(keys.prefix(Self.maxRows), id: \.self) { key in
                    fieldRow(key: key, value: object[key] ?? .null)
                }
                more(keys.count)
            case .array(let items):
                if items.isEmpty {
                    Text("The list is empty.").foregroundStyle(.secondary)
                }
                ForEach(Array(items.prefix(Self.maxRows).enumerated()), id: \.offset) { index, item in
                    listRow(position: index + 1, item: item)
                }
                more(items.count)
            default:
                Text(entry.preview)
                    .font(.title3.weight(.semibold))
            }
        }
        .padding()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Label(entry.key, systemImage: entry.kind.systemImage)
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer()
                Text(collection.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            // On its own line, so a long relative time doesn't squeeze the key
            if let expiresAt = entry.expiresAt {
                Label {
                    // A fixed time: a relative one keeps counting up once it passes while the card is open
                    Text("Expires \(expiresAt, format: .dateTime.month(.abbreviated).day().hour().minute())")
                } icon: {
                    Image(systemName: "timer")
                }
                .font(.caption2)
                .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func fieldRow(key: String, value: JSONValue) -> some View {
        if case .number(let number) = value, !key.contains(".") {
            numberRow(label: key, number: number, field: key)
        } else {
            HStack {
                Text(key).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 8)
                Text(value.displayText).fontWeight(.semibold).lineLimit(2).multilineTextAlignment(.trailing)
            }
        }
    }

    private func numberRow(label: String, number: Double, field: String?) -> some View {
        HStack(spacing: 12) {
            Text(label).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            Text(JSONValue.format(number))
                .font(field == nil ? .title2.weight(.bold) : .body.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Button(intent: IncrementIntent(key: entry.key, collection: collection, amount: -1, field: field)) {
                Image(systemName: "minus")
            }
            .accessibilityLabel("Decrease \(label)")
            Button(intent: IncrementIntent(key: entry.key, collection: collection, amount: 1, field: field)) {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Increase \(label)")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }

    private func listRow(position: Int, item: JSONValue) -> some View {
        HStack {
            Text(item.displayText).lineLimit(2)
            Spacer(minLength: 8)
            Button(intent: RemoveFromListIntent(key: entry.key, collection: collection, position: position)) {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Remove \(item.displayText)")
        }
    }

    @ViewBuilder
    private func more(_ count: Int) -> some View {
        if count > Self.maxRows {
            Text("+\(count - Self.maxRows) more")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
