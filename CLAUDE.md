# Folk's DB - Claude Documentation

## Project Overview
Folk's DB is an iOS key-value datastore, built mainly so people who make Shortcuts have a permanent place for their data. It uses a SwiftUI interface and SwiftData for storage.

**Key Features:**
- Collections: namespaces of unique, human-readable keys
- Typed values: text, number, boolean, date, list, dictionary (a document)
- Expiring keys (TTL), list operations, field paths into documents, and auto-keyed log entries
- More than 30 Shortcuts actions, Siri phrases, Spotlight, and an interactive card (iOS 26 snippet)
- JSON import and export

## Architecture

### Technology Stack
- **Framework**: SwiftUI + SwiftData
- **Platform**: iOS 26.0+
- **Language**: Swift 5 mode
- **Automation**: App Intents (in the app target, no extension)
- **Deployment**: App Store (ID: 6739632007)

### Data Model (`Data/Models.swift`)
- **`Collection`**: `id` (unique) and `name`.
  - Names are unique, ignoring upper/lower case. `FolkStore` enforces this, not the schema, so old stores with duplicate names still open.
  - Relationships: `entries` (cascade), plus the legacy `keyValueData`.
- **`Entry`**: one key and its value.
  - `lookupKey` is unique and set to `"<collection id>\u{1F}<key>"`. It keeps a key unique within its collection, and it is also the Shortcuts entity ID.
  - `key`
  - `kindRaw` (`ValueKind`: text, number, boolean, date, list, dictionary)
  - `json`: the value as canonical JSON. Dates are ISO 8601 strings with kind `date`.
  - `textValue` and `numberValue`: copies of the value for search and sort.
  - `createdAt`, `updatedAt`, `expiresAt?`
  - `#Index` on key, updatedAt and expiresAt.
  - Construct with `collectionID`, insert it, then set `collection`.
- **`KeyValueData`** (`Data/LegacyModels.swift`): the 1.0 record model, kept *exactly* as it shipped so old stores open. `LegacyMigrator` converts these rows on launch. Never write new data to it.

**Values** (`Data/JSONValue.swift`, `Data/TypedValue.swift`):
- `JSONValue` is the JSON enum, and it handles field paths: `value(at:)`, `setting(_:at:)` and `removing(at:)`.
  - Path syntax: `FieldPath("address.city")`, `items.0`, and negative indexes counting from the end.
- `TypedValue` is a kind plus a `JSONValue`.
  - `TypedValue.parse(text, as: ValueType)` converts Shortcuts text input into a typed value.
  - `detect()` is the "automatic" type. It keeps leading-zero numbers, `+` numbers, and numbers with more than 15 digits as text.
- `DateCoding` handles ISO 8601 dates.

### Persistence and Migration
- `Persistence.shared` (`Data/Persistence.swift`) is the single `ModelContainer`, using the default configuration, which is the same store location as 1.0. `Persistence.inMemory()` is for tests and previews.
- `LegacyMigrator` (`Data/LegacyMigrator.swift`) runs on launch. It is idempotent and saves everything at once.
  - It renames duplicate collection names, for example "Mood (2)".
  - Each `KeyValueData` record becomes a dictionary `Entry` whose key is the old record ID.
  - Orphan records go to "Recovered Records".
- **Schema rule**: the app is live, so changes must stay additive: new optional properties, properties with defaults, or new models. Never rename or remove a stored property or model.

### FolkStore (`Data/FolkStore.swift`)
- `@MainActor` wrapper over `ModelContext`. **Every read and write goes through it**, from both the views and the intents.
- Injectable clock (`now:`) for tests, and `indexesSpotlight: false` turns off Spotlight in tests.
- Reads treat expired entries as missing and delete them. `purgeExpired()` runs on launch.
- By default, writing a whole value clears its expiry, and writing a field keeps it.
- API areas:
  - Collections
  - Entries: `set`, `value`, `delete`, `renameKey`, `keys`
  - Numbers: `increment`
  - Lists: `append`, `list`, `listItem`, `removeFromList`, `pop`
  - Logs: `addEntry`, `entries(in:from:to:)`, `latestEntry`
  - Queries: `find`, `sorted`
  - Bulk: `dictionary(of:)`, `setValues`
- Import and export live in `Data/CollectionExport.swift`.
  - Export format: `{"format":"folks-db","version":2,"name","entries":[{key,type,value,createdAt,updatedAt,expiresAt}]}`.
  - Import also accepts the 1.0 export, a plain object, and an array.

### Shortcuts / App Intents (`Intents/`)
- **Entities** (`Intents/Entities/`):
  - `CollectionEntity`
  - `EntryEntity`:
    - `@Property` / `@ComputedProperty` values: text, number, date, bool, items, json, count
    - `Transferable` as JSON
    - `EntryQuery` is an `EntityPropertyQuery`, which generates the "Find Entries" action.
  - Both entities are `IndexedEntity` for Spotlight.
- **Actions**:
  - `ValueIntents`, `ListIntents`, `LogIntents`, `QueryIntents`, `CollectionIntents`, `TransferIntents`, `OpenIntents`, and `Snippets/` (`ShowEntryIntent` with `EntrySnippetIntent`).
  - Pattern for each action:
    - `supportedModes = .background`
    - `@Dependency var container`
    - `@MainActor perform()` builds a `FolkStore`
    - errors are `FolkError` (`Intents/FolkError.swift`)
- **Values as text**: App Intents has no "any value" parameter, so values are `String` plus a `ValueType` parameter (default automatic). Shortcuts turns a Dictionary into JSON text, and a List into lines; the List type reads one item per line.
- **List positions** in intents count from 1, like Shortcuts' own list actions (`listIndex(fromPosition:)`). `FolkStore` uses 0-based indexes.
- **Key picker**: `KeyOptionsProvider` in `IntentSupport.swift` suggests existing keys. Each read-style action that uses it needs its own `@IntentParameterDependency` line in the provider. Actions that create keys (Set Value, Append, Increment) don't use the provider.
- **Metadata rules**:
  - Parameter titles and descriptions must be string literals; shared constants break metadata extraction.
  - Enums used as parameters declare `CaseIterable, Sendable` in their own file. Their `AppEnum` conformance goes in `IntentSupport.swift`.
- **Open**: `OpenCollectionIntent` and `OpenEntryIntent` are handled in `ContentView` with `.onAppIntentExecution`, which pushes a `Route` (`.collection(id:openKey:)`).
- **App Shortcuts**: `FolkShortcuts` in `AppShortcuts.swift`. The limit is 10 shortcuts, and every phrase must include `\(.applicationName)`.

### Views
- `ContentView`: the collections list, with entry counts, search, rename (context menu), delete, import (`.fileImporter`), and `NavigationStack` routing.
- `Views/CollectionDetailView`:
  - Rows show the key, a value preview, a type icon, and an expiry badge.
  - Search, sort, swipe to delete, and export (`UIDocumentPickerViewController` with `DocumentPickerDelegate`).
- `Views/EntryEditorView`:
  - The key field validates uniqueness, and a type picker sits above the value.
  - Each type has its own editor (list and dictionary rows), plus an optional expiry.
- `Views/CollectionView` (`AddCollectionView`): the new-collection sheet, showing an inline error for a duplicate name.

### File Structure
```
Folk's DB/
├── Folk_s_DBApp.swift          # Launch: dependency registration, migration, purge, Spotlight
├── ContentView.swift           # Collections list + Route
├── Item.swift                  # Legacy template model (unused, not in schema)
├── Data/
│   ├── Models.swift            # Collection, Entry
│   ├── LegacyModels.swift      # KeyValueData (1.0, read-only)
│   ├── LegacyMigrator.swift    # 1.0 records -> entries
│   ├── JSONValue.swift         # JSON enum + field paths
│   ├── TypedValue.swift        # ValueKind/ValueType, input parsing, DateCoding
│   ├── FolkStore.swift         # All reads/writes
│   ├── CollectionExport.swift  # Export format + import
│   └── Persistence.swift       # Shared ModelContainer
├── Intents/
│   ├── Entities/               # CollectionEntity, EntryEntity (+ queries)
│   ├── Snippets/               # Show Entry card (SnippetIntent + view)
│   ├── ValueIntents, ListIntents, LogIntents, QueryIntents, CollectionIntents,
│   ├── TransferIntents, OpenIntents, AppShortcuts
│   └── FolkError, IntentSupport (helpers, key picker, AppEnums)
└── Views/
    ├── CollectionView.swift        # Add collection
    ├── CollectionDetailView.swift  # Entries of a collection
    ├── EntryEditorView.swift       # Add/edit a key and typed value
    ├── DocumentPickerDelegate.swift
    └── ShareSheet.swift
```

## Development Guidelines

### Code Conventions
- SwiftUI declarative syntax
- `@Environment(\.modelContext)` for SwiftData operations
- `@Query` for reactive data fetching
- `@Bindable` for two-way data binding with SwiftData models
- Consistent naming: PascalCase for types, camelCase for properties/functions

### Data Management Patterns
- **CRUD Operations**: Through `FolkStore`. Don't write to `ModelContext` directly from views or intents.
- **Error Handling**: Views show `error.localizedDescription` or use `try?`. Intents throw `FolkError`, which Shortcuts shows to the user.
- **Schema changes**: additive only (see Persistence and Migration).
- **UI Updates**: Automatic through SwiftData's reactive binding
- **Deletion**: Cascade deletes configured at model level

### Testing Structure
- `Folk's DBTests/`: unit tests (Swift Testing) against `Persistence.inMemory()`, using a `TestClock` for expiry. They cover the store, the migrator, typed values, field paths, and import/export.
- `Folk's DBUITests/`: `EntryFlowUITests` creates a collection, adds a key, and edits it. Editor fields use accessibility IDs such as `entryTextValue`.

## Build & Deployment

### Requirements
- Xcode 26+
- iOS deployment target: 26.0
- Apple Developer account (for App Store)

### Key Configuration Files
- `Folk's DB.xcodeproj/` - Xcode project configuration (file-system synchronized groups: new files are picked up automatically)
- `Folk's DB.entitlements` - App capabilities (currently empty)
- `Folk-s-DB-Info.plist` - Basic app transport security settings

### Available Commands
- Build: Use Xcode build system
- Test: Xcode Test navigator or `⌘+U`. From the CLI:
  `xcodebuild test -project "Folk's DB.xcodeproj" -scheme "Folk's DB" -destination "platform=iOS Simulator,name=iPhone 17 Pro" -only-testing:"Folk's DBTests"`
- Archive: Xcode Archive for App Store submission

## Known Issues & Technical Debt
1. **Item.swift / ContentViewBackup.swift**: Leftover template code, unused
2. **Export UX**: Document picker presentation could be more integrated
3. **Nested dates**: Dates inside lists or dictionaries are stored as ISO text; only top-level values keep the `date` kind

## Extension Points for New Features
1. **Widgets / Control Center**: Needs a widget extension, an App Group, and a one-time move of the store into the group container
2. **Backup/Sync**: CloudKit would require dropping the `.unique` attributes
3. **Value history / undo**
4. **`@UnionValue` inputs** (iOS 26) so one parameter can accept a number, date or text natively
5. **Export Formats**: CSV and others besides JSON

## Recent Changes (from git history)
- Redesigned the data model as key → typed value, with expiry, lists, field paths and log entries; 1.0 records are converted on launch
- Shortcuts support: App Intents actions, entities, Spotlight, interactive snippet, App Shortcuts; deployment target raised to iOS 26
- Added delete functionality for collections and records
- Implemented JSON export feature
- App Store deployment completed
- Safety/security improvements
