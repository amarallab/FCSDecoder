//
//  DataType.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/15/21.
//

import Foundation

public enum DataType: String, Decodable {
    case ascii = "A"
    case int = "I"
    case float = "F"
    case double = "D"
}
