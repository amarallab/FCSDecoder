//
//  FlowCytometry.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/23/21.
//

import Combine
import Foundation

public struct FlowCytometry {
    public enum ReadingError: Error {
        case invalidFormat
        case invalidVersion(String)
        case invalidParameter(String)
        case invalidDataSegment
    }
    
    public enum Version {
        case fcs30
        case fcs31
    }

    public enum FlowData {
        case int([UInt32])
        case float([Float])
        case double([Double])
    }
    
    public enum DataRange {
        case int(min: UInt32, max: UInt32)
        case float(min: Float, max: Float)
        case double(min: Double, max: Double)
    }

    public let version: Version
    public let text: TextSegment
    public let data: FlowData
    public let channelDataRanges: [DataRange]

    public init(from data: Data) throws {
        // 1. HEADER
        guard
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
            indexValues.count >= 6
        else {
            throw ReadingError.invalidFormat
        }
        
        let textEndIndex = indexValues[1]
        let dataStartIndex = indexValues[2]
        let dataEndIndex = indexValues[3]
        
        guard
            textStartIndex <= textEndIndex,
            dataStartIndex <= dataEndIndex,
            data.count >= textEndIndex,
            data.count >= dataEndIndex
        else {
            throw ReadingError.invalidFormat
        }
        
        // Text segment
        
        let decoder = SegmentDecoder()
        self.text = try decoder.decode(TextSegment.self, from: data[textStartIndex...textEndIndex])

        // Data segment
        let channelsData: FlowData
        switch (text.dataType, text.byteOrd) {
        case (.float, .bigEndian):
            channelsData = .float(data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                $0.bindMemory(to: Float32.self).map { Float32(bitPattern: $0.bitPattern.bigEndian) }
            })
        case (.float, .littleEndian):
            channelsData = .float(data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                $0.bindMemory(to: Float.self)
            }.map { $0 })
        case (.double, .bigEndian):
            channelsData = .double(data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                $0.bindMemory(to: Double.self).map { Double(bitPattern: $0.bitPattern.bigEndian) }
            })
        case (.double, .littleEndian):
            channelsData = .double(data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                $0.bindMemory(to: Double.self)
            }.map { $0 })
        case (.int, let byteOrder):
            let bitLengths = self.text.channels.map { $0.b }
            let onlyBytes = self.text.channels.map { $0.b.isMultiple(of: 8) }.reduce(true) { $0 && $1 }
            var bitBuffer: BitBuffer = createBitBuffer(data[dataStartIndex...dataEndIndex], byteOrder: byteOrder, onlyBytes: onlyBytes)
            channelsData = .int(Self.transformToInt(bitBuffer: &bitBuffer, bitLengths: bitLengths))
        default:
            throw ReadingError.invalidDataSegment
        }
        
        switch channelsData {
        case .int(let data):
            channelDataRanges = Self.calculateChannelsDataRange(data, channelCount: text.channels.count, buildDataRange: DataRange.int)
        case .float(let data):
            channelDataRanges = Self.calculateChannelsDataRange(data, channelCount: text.channels.count, buildDataRange: DataRange.float)
        case .double(let data):
            channelDataRanges = Self.calculateChannelsDataRange(data, channelCount: text.channels.count, buildDataRange: DataRange.double)
        }
        self.data = channelsData
    }
    
    private static func calculateChannelsDataRange<T: Comparable>(_ data: [T], channelCount: Int, buildDataRange: (T, T) -> DataRange) -> [DataRange] {
        var concurrentMinValues: [T] = Array(data[0..<channelCount])
        var concurrentMaxValues: [T] = Array(data[0..<channelCount])
        let group = DispatchGroup()
        for channel in 0..<channelCount {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                var minValue = data[channel]
                var maxValue = data[channel]
                for i in stride(from: channel, to: data.count, by: channelCount) {
                    minValue = min(minValue, data[i])
                    maxValue = max(maxValue, data[i])
                }
                concurrentMinValues[channel] = minValue
                concurrentMaxValues[channel] = maxValue
                group.leave()
            }
        }
        group.wait()
        
        return zip(concurrentMinValues, concurrentMaxValues).map(buildDataRange)
    }
    
    private static func transformToInt(bitBuffer: inout BitBuffer, bitLengths: [Int]) -> [UInt32] {
        var data: [UInt32] = []
        while !bitBuffer.isEmpty {
            data.append(contentsOf: bitLengths.map { bitBuffer.next($0) })
        }
        return data
    }
}
