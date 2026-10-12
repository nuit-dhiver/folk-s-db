//
//  DemoData.swift
//  Folk's DB
//
//  Sample collections for App Store screenshots. Debug builds in the simulator only:
//  launch with the "-seedDemoData" argument to replace all data with this set.
//
#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DemoData {
    static let launchArgument = "-seedDemoData"

    static func seedIfRequested(_ container: ModelContainer) {
        // Seeding deletes everything, so never on a real device that may hold real data
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        do {
            try seed(container)
        } catch {
            print("Seeding demo data failed: \(error)")
        }
        #endif
    }

    private static func list(_ items: String...) -> TypedValue {
        TypedValue(.array(items.map(JSONValue.string)))
    }

    static func seed(_ container: ModelContainer) throws {
        let start = Date.now
        let store = FolkStore(container: container)
        for collection in store.allCollections() {
            try store.deleteCollection(collection)
        }

        let day = try store.createCollection(name: "My Day")
        try store.set(.number(3), for: "coffeeCount", in: day)
        try store.set(.number(6), for: "waterGlasses", in: day)
        try store.set(.number(42), for: "streak", in: day)
        try store.set(.bool(true), for: "ranToday", in: day, expiry: .at(start.addingTimeInterval(14 * 3600 + 20 * 60)))
        try store.set(.bool(false), for: "focusMode", in: day)
        try store.set(.date(start.addingTimeInterval(-26 * 3600)), for: "lastWorkout", in: day)
        try store.set(.text("Small steps, every day."), for: "motto", in: day)
        try store.set(list("Oat milk", "Avocados", "Sourdough", "Blueberries"), for: "groceries", in: day)
        try store.set(TypedValue(.object([
            "name": .string("Alex"),
            "city": .string("Berlin"),
            "theme": .string("dark"),
            "goal": .number(10000),
        ])), for: "profile", in: day)
        try store.set(TypedValue(.object([
            "temp": .number(18),
            "sky": .string("Partly cloudy"),
        ])), for: "weatherCache", in: day, expiry: .at(start.addingTimeInterval(45 * 60)))

        let mood = try store.createCollection(name: "Mood Log")
        let moods: [(hoursAgo: Double, mood: String, energy: Double, note: String)] = [
            (2, "😊", 4, "Great run"),
            (9, "😌", 3, "Calm morning"),
            (26, "😐", 2, "Long meetings"),
            (33, "😄", 5, "Dinner with friends"),
            (50, "😴", 1, "Slept badly"),
            (57, "🙂", 3, "Read in the park"),
            (74, "😊", 4, "Shipped a feature"),
            (98, "😌", 3, "Lazy Sunday"),
        ]
        for item in moods.reversed() {
            let log = FolkStore(container: container, now: { start.addingTimeInterval(-item.hoursAgo * 3600) })
            try log.addEntry(TypedValue(.object([
                "mood": .string(item.mood),
                "energy": .number(item.energy),
                "note": .string(item.note),
            ])), to: mood)
        }

        let home = try store.createCollection(name: "Smart Home")
        try store.set(.number(21.5), for: "thermostat", in: home)
        try store.set(.bool(true), for: "awayMode", in: home)
        try store.set(.text("Movie night"), for: "scene", in: home)
        try store.set(.date(start.addingTimeInterval(-3 * 3600)), for: "lastArrival", in: home)
        try store.set(list("Living room", "Kitchen", "Hallway"), for: "lightsOn", in: home)

        let jobs = try store.createCollection(name: "Jobs")
        try store.set(list("Resize photos", "Back up notes", "Send invoice"), for: "queue", in: jobs)
        try store.set(.number(128), for: "processed", in: jobs)
        try store.set(.date(start.addingTimeInterval(-40 * 60)), for: "lastRun", in: jobs)

        let reading = try store.createCollection(name: "Reading")
        for (key, pages) in [("currentBook", 212.0), ("pagesToday", 34.0), ("booksThisYear", 17.0), ("yearlyGoal", 24.0)] {
            try store.set(.number(pages), for: key, in: reading)
        }
        try store.set(list("Dune", "Piranesi", "The Overstory"), for: "wishlist", in: reading)

        let flags = try store.createCollection(name: "Flags")
        try store.set(.bool(true), for: "morningRoutine", in: flags, expiry: .at(start.addingTimeInterval(9 * 3600)))
        try store.set(.bool(true), for: "plantsWatered", in: flags, expiry: .at(start.addingTimeInterval(2 * 86400)))
        try store.set(.bool(false), for: "betaFeatures", in: flags)

        let settings = try store.createCollection(name: "Shortcut Settings")
        try store.set(.text("https://example.com/hook"), for: "webhookURL", in: settings)
        try store.set(.text("en-US"), for: "locale", in: settings)
        try store.set(.number(15), for: "retryMinutes", in: settings)

        // Written last, so Shortcuts suggests it first for "Show Entry"
        try store.set(TypedValue(.object([
            "coffee": .number(3),
            "water": .number(6),
            "pushups": .number(40),
            "mood": .string("Great"),
        ])), for: "today", in: day)
    }
}
#endif
