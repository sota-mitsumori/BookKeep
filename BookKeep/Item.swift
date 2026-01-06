//
//  Item.swift
//  BookKeep
//
//  Created by Sota Mitsumori on 2026/01/06.
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
