# Folk's DB

A datastore for iOS devices, designed to serve as an alternative to traditional text files and other data storage methods.

## 🌟 Features

- **Collections of keys**: Each collection is a namespace of unique, human-readable keys, such as `theme`, `runCount` or `profile`.
- **Typed values**: A key holds text, a number, a boolean, a date, a list, or a dictionary (a document).
- **Expiring keys**: A value can expire after a set time. Good for caches, cooldowns and "already ran today" flags.
- **Lists and documents**: Append and pop list items. Read and write inside dictionaries with field paths like `address.city`.
- **Logs**: Add entries under time-ordered keys, then query them by date or by field.
- **Shortcuts**: More than 30 actions, plus Siri phrases, Spotlight search and interactive cards.

## 🚀 Getting Started

## Download on the App Store
[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/app/id6739632007)

### Installation from source
1. Clone the repository:
   ```bash
   git clone https://github.com/nuit-dhiver/folk-s-db
   
2. Open the project in Xcode and build the app to your iOS device.

### Usage

1. Use the GUI to create, view, and manage your collections, keys and values.
2. Integrate the datastore with the Shortcuts app by using the provided intents, allowing quick access and automation of data management tasks.

## ⚡️ Shortcuts

Folk's DB gives your shortcuts a permanent database. Everything below runs in the background, without opening the app. Requires iOS 26.

| Category | Actions |
|---|---|
| Values | Get Value · Set Value · Set Date · Delete Key · Key Exists · Increment · Rename Key · Get Entry · Show Entry · Open Entry |
| Lists | Append to List · Get List · Get List Item · Remove from List · Pop from List |
| Log | Add Entry · Get Entries · Get Latest Entry |
| Search | Find Entries Where … · Find Entries (filter, sort, limit) · List Keys · Get Collection as Dictionary · Set Values from Dictionary |
| Collections | Create · Get by Name · Rename · Clear · Delete · Open |
| Import & Export | Export Collection as JSON · Import Collection from JSON |

**Values and types.** **Set Value** accepts text, a number, a List or a Dictionary. With *Type: Automatic* it detects the type:
- Numbers, `true`/`false`, lists and dictionaries are stored as those types.
- Zip codes such as `01234`, phone numbers such as `+49…` and long card numbers stay text.

Set *Type* to *Text* to always keep exactly what you typed. Use **Set Date** for dates.

**Reading values back.** **Get Value** returns text; lists and dictionaries come back as JSON, which Shortcuts uses as a Dictionary. For typed details (number, date, list items, created/updated, expiry), use **Get Entry**. **Get List** returns items ready for *Repeat with Each*.

**Field paths.** The optional *Field* reads or writes inside a dictionary or list:
- `address.city` is a field inside a field, and `items.0` is the first item of a list.
- `-1` is the last item.
- Missing dictionaries are created when you write.

**Expiring keys.** Set *Expires After* on **Set Value**. Once it expires, the key reads as missing.

**Interactive card.** **Show Entry** displays a key as a card in Shortcuts and Siri:
- Numbers, and number fields of a dictionary, get − and + buttons.
- List items get a ✓ button that removes them.

**Siri and Spotlight.** These phrases work with no setup:
- "Add an entry to *Mood* in VolksDB"
- "Show the latest entry in *Mood* from VolksDB"
- "Open *Mood* in VolksDB"

Keys and collections are searchable in Spotlight.

### Example: run once per day

1. **Set Value**: `ranToday` to `true` in *Flags*, with *Expires After* `24 hours` and *Only If Missing* on
2. **If** *Was Set* is *false*, **Stop This Shortcut**
3. …do the daily thing

### Example: a queue

- Add jobs: **Append to List** *Items* to `queue` in *Jobs*
- Take the next one: **Pop from List** *First* item from `queue` in *Jobs*

### Example: a mood log

1. **Dictionary**: `mood` = *Ask Each Time*, `energy` = *Ask Each Time*
2. **Add Entry**: *Dictionary* to *Mood*
3. Later: **Find Entries Where** in *Mood* where `energy` *is less than* `3`

### Upgrading from version 1.0

Records from version 1.0 are converted automatically on first launch, and nothing is lost:
- Each record becomes a dictionary entry whose key is its old record ID. You can rename keys in the app or with **Rename Key**.
- Collection names are now unique, so a duplicate name gets a number, like "Mood (2)".
- Old JSON exports can still be imported.

### 🛠 Contribution Guidelines

We welcome all contributions, including feature suggestions, bug reports, and pull requests. To ensure a smooth collaboration, please follow these guidelines:

#### Submitting Issues or Suggestions

- Clearly describe the issue or suggestion, including steps to reproduce or use cases if applicable.
- Include relevant details like screenshots, logs, or environment information.

#### Creating Pull Requests

- Ensure your pull request is clear and self-explanatory.
- Follow the original coding standards and maintain code consistency.
- Provide a concise description of the changes introduced and their purpose.

#### Example Workflow

1. Fork the repository.
2. Create a feature branch:

git checkout -b feature/your-feature-name


3. Make changes and commit them:

`git commit -m "Add feature description like: feat(name): short description"`

4. Push the branch and create a pull request.

## 📄 License

This project is licensed under the MIT License. You are free to use, modify, and distribute the code in this repository, provided that proper attribution is given.

## ❤️ Acknowledgments

Thank you for considering contributing to this project! Your feedback and support help make this datastore more powerful and user-friendly.

For any questions or inquiries, feel free to reach out via the Issues tab. Let’s build something amazing together!
