//
//  ByteOrder.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/15/21.
//

import Foundation

public enum ByteOrder: String, Decodable, Equatable, Hashable {
    case littleEndian = "1,2,3,4"
    case bigEndian = "4,3,2,1"
}
