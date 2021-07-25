//
//  Time.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/25/21.
//

import Foundation

public struct Time: Decodable {
    public var hour: Int
    public var minute: Int
    public var second: Int
    public var fractionalSecond: Int?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        let params = value.split(separator: ":")
        switch params.count {
        case 3:
            guard
                params[0].count == 2 && params[1].count == 2,
                let hour = Int(params[0]),
                let minute = Int(params[1])
            else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data")
            }
            let secParams = params[2].split(separator: ".")
            guard
                secParams.count == 1 || secParams.count == 2,
                secParams[0].count == 2,
                secParams.count == 1 || secParams[1].count == 2,
                let second = Int(secParams[0])
            else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data")
            }
            self.hour = hour
            self.minute = minute
            self.second = second
            self.fractionalSecond = secParams.count == 2 ? Int(secParams[1]) : nil
            
        case 4:
            guard
                params[0].count == 2 && params[1].count == 2 && params[2].count == 2,
                let hour = Int(params[0]),
                let minute = Int(params[1]),
                let second = Int(params[2]),
                let fractionalSecond = Int(params[3])
            else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data")
            }
            self.hour = hour
            self.minute = minute
            self.second = second
            self.fractionalSecond = fractionalSecond
        
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data")
        }
    }
}
