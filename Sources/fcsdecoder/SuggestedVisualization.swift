//
//  SuggestedVisualization.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/25/21.
//

import Foundation

public enum SuggestedVisualization: Decodable {
    case linear(lowerBound: Float, upperBound: Float)
    case logarithmic(decades: Float, offset: Float)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let params = value.split(separator: ",")
        guard
            params.count == 3,
            let param1 = Float(params[1]),
            let param2 = Float(params[2])
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data")
        }
        switch params[0] {
        case "Linear": self = .linear(lowerBound: param1, upperBound: param2)
        case "Logarithmic": self = .logarithmic(decades: param1, offset: param2)
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data")
        }
    }
}
