//
//  FCS.swift
//  
//
//  Created by Heliodoro Tejedor Navarro on 20/8/23.
//

import Accelerate
import Foundation

fileprivate extension Optional where Wrapped == Float {
    var removedNan: Self {
        switch self {
        case .none:
            return .none
        case .some(let value):
            return value.isNormal ? .some(value) : .none
        }
    }
}

public struct FCS {
    public enum ReadingError: Error {
        case invalidFormat
        case invalidVersion(String)
        case invalidParameter(String)
        case invalidDataSegment
        case invalidBuffer
    }
    
    public enum Version {
        case fcs30
        case fcs31
    }
    
    public enum Buffer {
        case int(buffer: [UInt32])
        case float(buffer: [Float32])
        case double(buffer: [Double])
        
        public var bufferAsFloat: [Float] {
            switch self {
            case .int(buffer: let buffer): return buffer.map(Float.init)
            case .float(buffer: let buffer): return buffer
            case .double(buffer: let buffer): return buffer.map(Float.init)
            }
        }
    }

    public enum ChannelDataRange: Equatable, Hashable {
        case int(min: UInt32, max: UInt32)
        case float(min: Float32, max: Float32)
        case double(min: Double, max: Double)
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
        private let text: TextSegment
    
    public let version: Version
    public let buffer: Buffer
    public let channels: [Channel]
    public let eventCount: Int
    
    public init(from data: Data) throws {
        guard
            data.count >= 9,
            let versionString = String(bytes: data[0...5], encoding: .ascii)
        else {
            throw ReadingError.invalidFormat
        }

        switch versionString {
        case "FCS3.0": version = .fcs30
        case "FCS3.1": version = .fcs31
        default: throw ReadingError.invalidVersion(versionString)
        }
        
        do {
            var spaces = Set(data[6...9])
            spaces.remove(32)
            if spaces.count > 0 {
                throw ReadingError.invalidFormat
            }
        }

        var indexValues: [Int] = []
        let indexNames = [
            "TEXT start index", "TEXT end index",
            "DATA start index", "DATA end index",
            "ANALYSIS start index", "ANALYSIS end index"
        ]
        
        var index = 10
        var textStartIndex: Int?
        while true {
            let name = indexValues.count < indexNames.count ? indexNames[indexValues.count] : "OTHER index at \(indexValues.count)"
            
            guard
                let stringValue = String(bytes: data[index..<index + 8], encoding: .ascii)
            else {
                throw ReadingError.invalidParameter(name)
            }
            
            let trimmedStringValue = stringValue.trimmingCharacters(in: CharacterSet(charactersIn: " "))
            if trimmedStringValue.count == 0 {
                break
            }
            
            guard
                let intValue = Int(trimmedStringValue)
            else {
                throw ReadingError.invalidParameter(name)
            }
            indexValues.append(intValue)
            index += 8
            
            if indexValues.count > 6
                && indexValues.count.isMultiple(of: 2)
                && indexValues[indexValues.endIndex.advanced(by: -2)...] == [0, 0]
            {
                // Finished
                break
            }

            if let textStartIndex = textStartIndex {
                if index == textStartIndex {
                    // Reach the end
                    break
                }
            } else {
                textStartIndex = intValue // first one is the text start index
            }
        }

        guard
            let textStartIndex = textStartIndex
        else {
            throw ReadingError.invalidFormat
        }
        
        do {
            var spaces = Set(data[index..<textStartIndex])
            spaces.remove(32)
            if spaces.count > 0 {
                throw ReadingError.invalidFormat
            }
        }
        
        guard
            indexValues.count >= 4
        else {
            throw ReadingError.invalidFormat
        }
        
        let textEndIndex = indexValues[1]

        guard
            textStartIndex <= textEndIndex,
            data.count >= textEndIndex
        else {
            throw ReadingError.invalidFormat
        }
        
        // Text segment
        let decoder = SegmentDecoder()
        self.text = try decoder.decode(TextSegment.self, from: data[textStartIndex...textEndIndex])
        let dataStartIndex = indexValues[2] != 0 ? indexValues[2] : self.text.beginData
        var dataEndIndex = indexValues[3] != 0 ? indexValues[3] : self.text.endData

        // Check Data effective size
        let bitLengths = self.text.channels.map { $0.b }
        let eventCount = bitLengths.reduce(0, +) / 8
        let dataEffCount = self.text.tot * eventCount
        
        let effDataEndIndex = dataStartIndex + dataEffCount - 1
        if dataEndIndex > effDataEndIndex + 1 { // Allow one byte difference
            throw ReadingError.invalidFormat
        }
        if dataEndIndex > effDataEndIndex {
            dataEndIndex = effDataEndIndex
        }
        
        guard
            dataStartIndex <= dataEndIndex,
            data.count >= dataEndIndex
        else {
            throw ReadingError.invalidFormat
        }
        
        // Data segment
        let channelsCount = text.channels.count
        switch text.dataType {
        case .int:
            let intBuffer: [UInt32]
            switch text.byteOrd {
            case .littleEndian:
                intBuffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: UInt32.self).map {
                        $0.bigEndian
                    }
                }
            case .bigEndian:
                intBuffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: UInt32.self).map {
                        $0.littleEndian
                    }
                }
            }

            guard intBuffer.count >= channelsCount * text.tot else { throw ReadingError.invalidBuffer }
            
            var channels: [Channel] = []
            for (channelIndex, data) in text.channels.enumerated() {
                let values = (0..<text.tot).map { intBuffer[$0 * channelsCount + channelIndex] }
                let min = values.min() ?? 0
                let max = values.max() ?? 0
                let channel = Channel(
                    dataRange: .int(min: min, max: max),
                    offset: channelIndex,
                    stride: text.channels.count,
                    b: data.b,
                    e: data.e,
                    n: data.n,
                    r: data.r,
                    calibration: data.calibration,
                    d: data.d,
                    f: data.f,
                    g: data.g.removedNan,
                    l: data.l,
                    o: data.o,
                    p: data.p,
                    s: data.s,
                    t: data.t,
                    v: data.v.removedNan)
                channels.append(channel)
            }
            self.buffer = .int(buffer: intBuffer)
            self.channels = channels

        case .float:
            let floatBuffer: [Float32]
            switch text.byteOrd {
            case .bigEndian:
                floatBuffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: Float32.self).map {
                        Float32(bitPattern: $0.bitPattern.bigEndian)
                    }
                }
            case .littleEndian:
                floatBuffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: Float32.self)
                }.map { $0 }
            }
            
            guard floatBuffer.count >= channelsCount * text.tot else { throw ReadingError.invalidBuffer }

            var channels: [Channel] = []
            for (channelIndex, data) in text.channels.enumerated() {
                let values = (0..<text.tot).map { floatBuffer[$0 * channelsCount + channelIndex] }
                let min = values.min() ?? 0
                let max = values.max() ?? 0
                let channel = Channel(
                    dataRange: .float(min: min, max: max),
                    offset: channelIndex,
                    stride: text.channels.count,
                    b: data.b,
                    e: data.e,
                    n: data.n,
                    r: data.r,
                    calibration: data.calibration,
                    d: data.d,
                    f: data.f,
                    g: data.g.removedNan,
                    l: data.l,
                    o: data.o,
                    p: data.p,
                    s: data.s,
                    t: data.t,
                    v: data.v.removedNan)
                channels.append(channel)
            }
            self.buffer = .float(buffer: floatBuffer)
            self.channels = channels
            
        case .double:
            let doubleBuffer: [Double]
            switch text.byteOrd {
            case .bigEndian:
                doubleBuffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: Float64.self).map {
                        Float64(bitPattern: $0.bitPattern.bigEndian)
                    }
                }.map { Double($0) }
            case .littleEndian:
                doubleBuffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: Float64.self)
                }.map { Double($0) }
            }
            
            guard doubleBuffer.count >= channelsCount * text.tot else { throw ReadingError.invalidBuffer }

            var channels: [Channel] = []
            for (channelIndex, data) in text.channels.enumerated() {
                let values = (0..<text.tot).map { doubleBuffer[$0 * channelsCount + channelIndex] }
                let min = values.min() ?? 0
                let max = values.max() ?? 0
                let channel = Channel(
                    dataRange: .double(min: min, max: max),
                    offset: channelIndex,
                    stride: text.channels.count,
                    b: data.b,
                    e: data.e,
                    n: data.n,
                    r: data.r,
                    calibration: data.calibration,
                    d: data.d,
                    f: data.f,
                    g: data.g.removedNan,
                    l: data.l,
                    o: data.o,
                    p: data.p,
                    s: data.s,
                    t: data.t,
                    v: data.v.removedNan)
                channels.append(channel)
            }
            self.buffer = .double(buffer: doubleBuffer)
            self.channels = channels
        default:
            throw ReadingError.invalidDataSegment
        }

        self.eventCount = text.tot
    }
}
