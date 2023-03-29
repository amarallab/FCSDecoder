//
//  DataType.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/15/21.
//

import Foundation

enum DataType: String, Decodable, Equatable, Hashable {
    case ascii = "A"
    case int = "I"
    case float = "F"
    case double = "D"
}
