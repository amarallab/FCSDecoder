//
//  Originality.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/15/21.
//

import Foundation

public enum Originality: String, Decodable {
    case original = "Original"
    case appended = "Appended"
    case nonDataModified = "NonDataModified"
    case dataModified = "DataModified"
}
