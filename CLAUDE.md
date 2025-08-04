# Folk's DB - Claude Documentation

## Project Overview
Folk's DB is an iOS application that serves as a document-oriented key-value datastore for iOS devices. It provides an alternative to traditional text files and other data storage methods, featuring a clean SwiftUI interface and SwiftData persistence layer.

**Key Features:**
- Collections-based data organization
- Document-like key-value records with unique IDs
- GUI-based data management
- JSON export functionality
- Shortcuts integration (planned/mentioned in README)

## Architecture

### Technology Stack
- **Framework**: SwiftUI + SwiftData
- **Platform**: iOS
- **Language**: Swift
- **Persistence**: SwiftData (CoreData successor)
- **Deployment**: App Store (ID: 6739632007)

### Data Models

#### Collection (`KeyValue.swift:11-21`)
```swift
@Model
class Collection {
    @Attribute(.unique) var id: String
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \KeyValueData.collection) var keyValueData: [KeyValueData]
}
```
- Primary container for organizing related data
- One-to-many relationship with KeyValueData records
- Cascade delete ensures cleanup of child records

#### KeyValueData (`KeyValue.swift:24-34`)
```swift
@Model
class KeyValueData {
    @Attribute(.unique) var id: String // Unique record ID
    var keyValuePairs: [String: String] // Key-value attributes
    var collection: Collection?
}
```
- Individual records within collections
- Flexible key-value pair storage as [String: String] dictionary
- Each record has unique UUID identifier

### Application Structure

#### App Entry Point (`Folk_s_DBApp.swift:13-20`)
```swift
@main
struct KeyValueStoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Collection.self, KeyValueData.self])
        }
    }
}
```
- Initializes SwiftData model container for both data models
- Single window group architecture

### View Hierarchy

#### 1. ContentView (`ContentView.swift`)
- **Purpose**: Main collections list view
- **Key Features**:
  - Lists all collections with NavigationLink navigation
  - Swipe-to-delete for collections
  - Add new collection button
  - Uses `@Query` for reactive data binding

#### 2. CollectionDetailView (`CollectionDetailView.swift`)
- **Purpose**: Shows records within a selected collection
- **Key Features**:
  - Lists all KeyValueData records in collection
  - Tap-to-edit existing records
  - Swipe-to-delete for individual records
  - Add new record functionality
  - Export collection to JSON

#### 3. AddEditKeyValueView (`AddEditKeyValue.swift`)
- **Purpose**: Create/edit individual records
- **Key Features**:
  - Dynamic key-value pair entry
  - Supports both new record creation and editing
  - Real-time display of current key-value pairs
  - Form-based interface

#### 4. AddCollectionView (`CollectionView.swift`)
- **Purpose**: Create new collections
- **Simple form**: Single text field for collection name

### Data Export Functionality

#### ExportCollectionAsJSON (`ExportCollection.swift:9-35`)
```swift
func ExportCollectionAsJSON(collection: Collection) throws -> URL
```
- Converts Collection object to JSON format
- Includes collection metadata and all records
- Saves to temporary directory with filename pattern: `{collectionName}-export.json`
- Returns file URL for sharing/saving

#### Export Flow (`CollectionDetailView.swift:78-101`)
1. Convert collection to JSON using `ExportCollectionAsJSON`
2. Create `UIDocumentPickerViewController` for file export
3. Present picker through current window scene
4. Handle success/failure through `DocumentPickerDelegate`

### File Structure
```
Folk's DB/
├── Folk_s_DBApp.swift          # App entry point
├── ContentView.swift           # Main collections view
├── Item.swift                  # Legacy model (unused)
├── Data/
│   ├── KeyValue.swift          # Core data models
│   └── ExportCollection.swift  # JSON export functionality
└── Views/
    ├── CollectionView.swift        # Add collection view
    ├── CollectionDetailView.swift  # Collection detail/records view
    ├── AddEditKeyValue.swift      # Record add/edit view
    ├── DocumentPickerDelegate.swift # File picker delegate
    └── ShareSheet.swift           # iOS share sheet wrapper
```

## Development Guidelines

### Code Conventions
- SwiftUI declarative syntax
- `@Environment(\.modelContext)` for SwiftData operations
- `@Query` for reactive data fetching
- `@Bindable` for two-way data binding with SwiftData models
- Consistent naming: PascalCase for types, camelCase for properties/functions

### Data Management Patterns
- **CRUD Operations**: Direct SwiftData context manipulation
- **Error Handling**: `try? context.save()` pattern for non-critical saves
- **UI Updates**: Automatic through SwiftData's reactive binding
- **Deletion**: Cascade deletes configured at model level

### Testing Structure
- `Folk's DBTests/` - Unit tests
- `Folk's DBUITests/` - UI automation tests
- Preview providers for SwiftUI components

## Build & Deployment

### Requirements
- Xcode (latest)
- iOS deployment target (check project settings)
- Apple Developer account (for App Store)

### Key Configuration Files
- `Folk's DB.xcodeproj/` - Xcode project configuration
- `Folk's DB.entitlements` - App capabilities (currently empty)
- `Folk-s-DB-Info.plist` - Basic app transport security settings

### Available Commands
- Build: Use Xcode build system
- Test: Xcode Test navigator or `⌘+U`
- Archive: Xcode Archive for App Store submission

## Known Issues & Technical Debt
1. **Item.swift**: Legacy SwiftData model that appears unused
2. **Error Handling**: Basic `try?` error handling, could be more robust
3. **UI State**: Some state management could be centralized
4. **Export UX**: Document picker presentation could be more integrated

## Extension Points for New Features
1. **Import Functionality**: Reverse of export, parse JSON to create collections
2. **Search/Filter**: Add search capability across collections/records
3. **Shortcuts Integration**: iOS Shortcuts app integration as mentioned in README
4. **Backup/Sync**: Cloud storage integration
5. **Data Types**: Expand beyond String values (numbers, dates, etc.)
6. **Bulk Operations**: Multi-select for batch operations
7. **Data Validation**: Input validation for keys/values
8. **Themes**: Dark mode, custom colors
9. **Export Formats**: CSV, XML, other formats beyond JSON
10. **Record Templates**: Predefined record structures for common use cases

## Recent Changes (from git history)
- Added delete functionality for collections and records
- Implemented JSON export feature
- App Store deployment completed
- Safety/security improvements