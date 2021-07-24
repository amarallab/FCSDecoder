//
//  KeyValueTypes.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/15/21.
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

public enum ByteOrder: String, Decodable {
    case littleEndian = "1,2,3,4"
    case bigEndian = "4,3,2,1"
}

public enum DataType: String, Decodable {
    case ascii = "A"
    case int = "I"
    case float = "F"
    case double = "D"
}

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
            params[0].count == 2,
            params[1].count == 3,
            params[2].count == 4,
            let day = Int(params[0]), (1...31).contains(day),
            months.contains(String(params[1])),
            let year = Int(params[2])
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "")
        }
        
        self.day = day
        self.month = String(params[1])
        self.year = year
    }
}

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

public struct FullDate: Decodable {
    public var date: fcsdecoder.Date
    public var time: fcsdecoder.Time
    
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

public enum Mode: String, Decodable {
    case list = "L"
    case correlated = "C"
    case uncorrelated = "U"
}

public enum Originality: String, Decodable {
    case original = "Original"
    case appended = "Appended"
    case nonDataModified = "NonDataModified"
    case dataModified = "DataModified"
}

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

public struct Time: Decodable {
    public var hour: Int
    public var minute: Int
    public var second: Int
    public var fractionalSecond: Int?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        let params = value.split(separator: ":")
        guard
            params.count == 3,
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
    }
}
