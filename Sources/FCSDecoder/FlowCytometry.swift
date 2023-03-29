//
//  FlowCytometry.swift
//  
//
//  Created by Heliodoro Tejedor Navarro on 25/3/23.
//

import Foundation
import MetalKit

public enum ChannelDataRange: Equatable, Hashable {
    case int(min: UInt32, max: UInt32)
    case float(min: Float32, max: Float32)
}

public struct Channel: Equatable, Hashable {
    public let dataRange: ChannelDataRange
    public let offset: Int
    public let stride: Int
    
    public let b: Int
    public let e: Amplification
    public let n: String
    public let r: Double // TODO: depends on the datatype
    
    public let calibration: String?
    public let d: SuggestedVisualization?
    public let f: String?
    public let g: Float?
    public let l: ExcitationWaveLengths?
    public let o: Int?
    public let p: Int?
    public let s: String?
    public let t: String?
    public let v: Float?
}

public struct FlowCytometry {
    public enum Version {
        case fcs30
        case fcs31
    }
    
    public enum DataType {
        case int
        case float
    }
    
    public let version: Version
    public let data: DataType
    public let channels: [Channel]
    public let eventCount: Int
    public let dataBuffer: MTLBuffer
    
    public init(from data: Data, using device: MTLDevice) throws {
        let read = try InternalFlowCytometry(from: data, using: device)
        switch read.version {
        case .fcs30: self.version = .fcs30
        case .fcs31: self.version = .fcs31
        }
               
        switch read.data {
        case .int: self.data = .int
        case .float: self.data = .float
        }

        if read.channelDataRanges.count != read.text.channels.count {
            throw InternalFlowCytometry.ReadingError.invalidFormat
        }

        var channels: [Channel] = []
        for (index, (dataRange, data)) in zip(read.channelDataRanges, read.text.channels).enumerated() {

            let newDataRange: ChannelDataRange
            switch dataRange {
            case .int(let min, let max): newDataRange = .int(min: min, max: max)
            case .float(let min, let max): newDataRange = .float(min: min, max: max)
            }

            let offset: Int
            let stride: Int
            switch read.data {
            case .int:
                offset = MemoryLayout<Int32>.size * 8 * index
                stride = MemoryLayout<Int32>.size * 8 * read.text.channels.count
            case .float:
                offset = MemoryLayout<Float32>.size * 8 * index
                stride = MemoryLayout<Float32>.size * 8 * read.text.channels.count
            }

            let channel = Channel(dataRange: newDataRange, offset: offset, stride: stride, b: data.b, e: data.e, n: data.n, r: data.r, calibration: data.calibration, d: data.d, f: data.f, g: data.g, l: data.l, o: data.o, p: data.p, s: data.s, t: data.t, v: data.v)
            channels.append(channel)
        }
        self.channels = channels
        self.eventCount = read.text.tot
        self.dataBuffer = read.dataBuffer
    }
}


extension FlowCytometry: Hashable, Equatable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(version)
        hasher.combine(data)
        hasher.combine(channels)
        hasher.combine(eventCount)
        // no dataBuffer
    }

    public static func == (lhs: FlowCytometry, rhs: FlowCytometry) -> Bool {
        lhs.version == rhs.version
            && lhs.data == rhs.data
            && lhs.channels == rhs.channels
            && lhs.eventCount == rhs.eventCount
            // no dataBuffer
    }
}
