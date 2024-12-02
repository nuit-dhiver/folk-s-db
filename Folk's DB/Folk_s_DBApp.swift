//
//  Folk_s_DBApp.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 27.11.24.
//

import SwiftUI
import SwiftData

@main

struct KeyValueStoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Collection.self, KeyValueData.self])
        }
    }
}
