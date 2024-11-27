//
//  Item.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 27.11.24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
