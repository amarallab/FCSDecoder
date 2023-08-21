//
//  SuggestedVisualization.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/25/21.
//

import Foundation

public enum SuggestedVisualization: Decodable, Equatable, Hashable {
    case linear(lowerBound: Float, upperBound: Float)
    case logarithmic(decades: Float, offset: Float)
    
    /// Note: The standard requires two parameters, but there are software that does not care.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let params = value.split(separator: ",")
        let param1: Float
        let param2: Float
        switch params.count {
        case 1:
            param1 = 0
            param2 = 1
        case 3:
            guard
                let fparam1 = Float(params[1]),
                let fparam2 = Float(params[2])
            else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data")
            }
            param1 = fparam1
            param2 = fparam2
        default:
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
