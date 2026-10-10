//
//  AppShortcuts.swift
//  Folk's DB
//
//  Zero-setup shortcuts that show up in the Shortcuts app, Spotlight and Siri as soon as the app is installed.
//
import AppIntents

struct FolkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddEntryIntent(),
            phrases: [
                "Add an entry to \(\.$collection) in \(.applicationName)",
                "Log to \(\.$collection) in \(.applicationName)",
                "Add an entry in \(.applicationName)",
            ],
            shortTitle: "Add Entry",
            systemImageName: "plus.rectangle.on.rectangle"
        )
        AppShortcut(
            intent: GetLatestEntryIntent(),
            phrases: [
                "Show the latest entry in \(\.$collection) from \(.applicationName)",
                "Get the latest \(.applicationName) entry",
            ],
            shortTitle: "Latest Entry",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: GetValueIntent(),
            phrases: [
                "Get a value from \(\.$collection) in \(.applicationName)",
                "Look up a value in \(.applicationName)",
            ],
            shortTitle: "Get Value",
            systemImageName: "key"
        )
        AppShortcut(
            intent: ShowEntryIntent(),
            phrases: [
                "Show an entry in \(.applicationName)",
                "Show a \(.applicationName) entry",
            ],
            shortTitle: "Show Entry",
            systemImageName: "rectangle.and.text.magnifyingglass"
        )
        AppShortcut(
            intent: IncrementIntent(),
            phrases: [
                "Increment a counter in \(.applicationName)",
                "Count up in \(.applicationName)",
            ],
            shortTitle: "Increment",
            systemImageName: "plus.forwardslash.minus"
        )
        AppShortcut(
            intent: OpenCollectionIntent(),
            phrases: [
                "Open \(\.$target) in \(.applicationName)",
                "Open a collection in \(.applicationName)",
            ],
            shortTitle: "Open Collection",
            systemImageName: "tray.full"
        )
        AppShortcut(
            intent: CreateCollectionIntent(),
            phrases: [
                "Create a collection in \(.applicationName)",
                "New \(.applicationName) collection",
            ],
            shortTitle: "Create Collection",
            systemImageName: "folder.badge.plus"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .teal
}
