//
//  Date.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/25/21.
//

import Foundation

public struct Date: Decodable {
    public var day: Int
    public var month: String
    public var year: Int
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        let params = value.split(separator: "-")
        guard
            params.count == 3,
            params[1].count == 3
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "")
        }

        switch (params[0].count, params[2].count) {
        case (2, 4):
            guard
                let day = Int(params[0]), (1...31).contains(day),
                months.contains(String(params[1]).uppercased()),
                let year = Int(params[2])
            else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "")
            }
            self.day = day
            self.month = String(params[1])
            self.year = year
        case (4, 2):
            guard
                let year = Int(params[0]),
                months.contains(String(params[1]).uppercased()),
                let day = Int(params[2]), (1...31).contains(day)
            else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "")
            }
            self.day = day
            self.month = String(params[1])
            self.year = year
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "")
        }
    }
}
