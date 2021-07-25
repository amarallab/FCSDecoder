//
//  Mode.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/15/21.
//

import Foundation

public enum Mode: String, Decodable {
    case list = "L"
    case correlated = "C"
    case uncorrelated = "U"
}
