//
//  Item.swift
//  Taxman
//
//  Created by Billow on 2026/9/15.
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
