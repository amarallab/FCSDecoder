//
//  ExcitationWaveLengths.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/25/21.
//

import Foundation

public struct ExcitationWaveLengths: Decodable {
    private var values: [Int]
    public var count: Int { values.count }
    
    public subscript(index: Int) -> Int {
        get { values[index] }
        set { values[index] = newValue }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.values = try value.split(separator: ",").map {
            guard
                let current = Int($0)
            else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data")
            }
            return current
        }
    }
}
