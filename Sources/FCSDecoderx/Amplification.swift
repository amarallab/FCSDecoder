//
//  Amplification.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/25/21.
//

import Foundation

public struct Amplification: Decodable {
    public var param1: Float
    public var param2: Float
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let params = value.split(separator: ",")
        guard
            params.count == 2,
            let param1 = Float(params[0]),
            let param2 = Float(params[1])
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data")
        }
        self.param1 = param1
        self.param2 = param2
    }
}
