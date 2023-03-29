//
//  FullDate.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/25/21.
//

import Foundation

public struct FullDate: Decodable, Equatable, Hashable {
    public var date: FCSDecoder.Date
    public var time: FCSDecoder.Time
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let params = value.split(separator: " ")
        guard params.count == 2 else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
        }
        
        let dateDecoder = InternalSegmentDecoder(codingPath: decoder.codingPath, userInfo: decoder.userInfo, value: String(params[0]))
        self.date = try Date(from: dateDecoder)
        let timeDecoder = InternalSegmentDecoder(codingPath: decoder.codingPath, userInfo: decoder.userInfo, value: String(params[1]))
        self.time = try Time(from: timeDecoder)
    }
}
