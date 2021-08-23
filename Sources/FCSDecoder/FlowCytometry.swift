//
//  FlowCytometry.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/23/21.
//

import Combine
import Foundation
import MetalKit

public struct FlowCytometry {
    public enum ReadingError: Error {
        // Metal issues
        case deviceNotFound
        case bufferError
        case sourceDataError
        case functionError
        case commandError

        // File issues
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
        case int
        case float
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
    public let dataBuffer: MTLBuffer
    
    public init(from data: Data) throws {
        // First, initialize Metal
        guard
            let device = MTLCreateSystemDefaultDevice()
        else {
            throw ReadingError.deviceNotFound
        }

        let library = try device.makeDefaultLibrary(bundle: .module)

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
        switch text.dataType {
        case .float:
            let buffer: [Float32]
            switch text.byteOrd {
            case .bigEndian:
                buffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: Float32.self).map {
                        Float32(bitPattern: $0.bitPattern.bigEndian)
                    }
                }
            case .littleEndian:
                buffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: Float32.self)
                }.map { $0 }
            }
            guard
                let dataBuffer = device.makeBuffer(bytes: buffer, length: MemoryLayout<Float32>.size * dataEffCount)
            else {
                throw ReadingError.invalidDataSegment
            }
            self.data = .float
            self.dataBuffer = dataBuffer
            self.channelDataRanges = try Self.findMinMaxFloat(
                device: device,
                library: library,
                buffer: self.dataBuffer,
                channelCount: self.text.channels.count,
                eventCount: self.text.tot)

        case .double:
            let buffer: [Float32]
            switch text.byteOrd {
            case .bigEndian:
                buffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: Double.self).map { Double(bitPattern: $0.bitPattern.bigEndian) }
                }.map { Float32($0) }
            case .littleEndian:
                buffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: Double.self)
                }.map { Float32($0) }
            }
            guard
                let dataBuffer = device.makeBuffer(bytes: buffer, length: MemoryLayout<Float32>.size * dataEffCount)
            else {
                throw ReadingError.invalidDataSegment
            }
            self.data = .float
            self.dataBuffer = dataBuffer
            self.channelDataRanges = try Self.findMinMaxFloat(
                device: device,
                library: library,
                buffer: self.dataBuffer,
                channelCount: self.text.channels.count,
                eventCount: self.text.tot)

        case .int:
            let convertByteOrd: Self.ByteOrd
            switch text.byteOrd {
            case .littleEndian:
                convertByteOrd = .int16LittleEndian
            case .bigEndian:
                convertByteOrd = .int16BigEndian
            }
            self.data = .int
            self.dataBuffer = try Self.convert(
                device: device,
                library: library,
                data: data[dataStartIndex...dataEndIndex],
                bitLengths: bitLengths,
                byteOrd: convertByteOrd,
                channelCount: self.text.channels.count,
                eventCount: self.text.tot)

            let channelCount = self.text.channels.count
            let eventCount = 2000 //self.text.tot

            let bbegin = Foundation.Date()
            let maxs: [UInt16] = data[dataStartIndex...dataEndIndex].withUnsafeBytes { ptr in
                let p = ptr.bindMemory(to: UInt16.self)
                return (0..<channelCount).map { channelId in
                    (0..<eventCount).map { p[$0 * channelCount + channelId] }.max() ?? 0
                }
            }
            let belapsedTime = Foundation.Date().timeIntervalSince(bbegin)
            print(maxs)
            print("ElapsedTime: \(belapsedTime)")

            self.channelDataRanges = try Self.findMinMaxInt(
                device: device,
                library: library,
                buffer: self.dataBuffer,
                channelCount: channelCount,
                eventCount: eventCount)
        default:
            throw ReadingError.invalidDataSegment
        }
    }
    
    
    enum ByteOrd: Int32 {
        case int16BigEndian = 0
        case int16LittleEndian = 1
        case int32BigEndian = 2
        case int32LittleEndian = 3
    }
    
    // Convert bit length based Data to UInt32 data
    static func convert(device: MTLDevice, library: MTLLibrary, data: Data, bitLengths: [Int], byteOrd: ByteOrd, channelCount: Int, eventCount: Int) throws -> MTLBuffer {
        struct Uniforms {
            var channelCount: Int32
            var eventCount: Int32
            var stride: Int32
            var byteOrd: ByteOrd
        }

        let destinationCount = channelCount * eventCount
        let sourceData = [UInt8](data)

        guard
            let converterFunction = library.makeFunction(name: "converter")
        else {
            throw ReadingError.functionError
        }

        guard
            let sourceBuffer = device.makeBuffer(bytes: sourceData, length: sourceData.count, options: .storageModeShared),
            let destinationBuffer = device.makeBuffer(length: destinationCount * MemoryLayout<UInt32>.size, options: .storageModeShared)
        else {
            throw ReadingError.bufferError
        }
        
        let bitLengthsData = bitLengths.map(UInt8.init)
        let stride = bitLengths.reduce(0, +)
        guard
            stride.isMultiple(of: 8)
        else {
            throw ReadingError.sourceDataError
        }
        
        let uniforms = Uniforms(
            channelCount: Int32(channelCount),
            eventCount: Int32(eventCount),
            stride: Int32(stride),
            byteOrd: .int16LittleEndian)

        let uniformsLength = MemoryLayout<Uniforms>.size
        let pipelineState = try device.makeComputePipelineState(function: converterFunction)

        guard
            let commandQueue = device.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
            let uniformsBuffer = device.makeBuffer(bytes: [uniforms], length: uniformsLength),
            let bitLengthsBuffer = device.makeBuffer(bytes: bitLengthsData, length: bitLengthsData.count, options: .storageModeShared)
        else {
            throw ReadingError.commandError
        }
        
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(bitLengthsBuffer, offset: 0, index: 1)
        commandEncoder.setBuffer(sourceBuffer, offset: 0, index: 2)
        commandEncoder.setBuffer(destinationBuffer, offset: 0, index: 3)
        let gridSize = MTLSize(width: channelCount, height: eventCount, depth: 1)
        commandEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))

        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return destinationBuffer
    }
    
    static func findMinMaxInt(device: MTLDevice, library: MTLLibrary, buffer: MTLBuffer, channelCount: Int, eventCount: Int) throws -> [DataRange] {
        struct FindMinMaxUniforms {
            var diff: Int32
            var channelId: Int32
            var channelCount: Int32
            var eventCount: Int32
        }

        struct MinMaxValues {
            var min: UInt32
            var max: UInt32
        }
                
        let begin = Foundation.Date()

        guard
            let findMinMaxInitChannelFunction = library.makeFunction(name: "find_min_max_init_channel_int"),
            let findMinMaxCopyFunction = library.makeFunction(name: "find_min_max_copy_int"),
            let findMinMaxStepFunction = library.makeFunction(name: "find_min_max_step_int"),
            let findMinMaxAfterStepFunction = library.makeFunction(name: "find_min_max_after_step_int"),
            let findMinMaxFinalFunction = library.makeFunction(name: "find_min_max_final_int")
        else {
            throw ReadingError.functionError
        }

        let pipelineInitChannelState = try device.makeComputePipelineState(function: findMinMaxInitChannelFunction)
        let pipelineCopyState = try device.makeComputePipelineState(function: findMinMaxCopyFunction)
        let pipelineStepState = try device.makeComputePipelineState(function: findMinMaxStepFunction)
        let pipelineAfterStepState = try device.makeComputePipelineState(function: findMinMaxAfterStepFunction)
        let pipelineFinalState = try device.makeComputePipelineState(function: findMinMaxFinalFunction)

        var uniforms = FindMinMaxUniforms(diff: 1, channelId: Int32(0), channelCount: Int32(channelCount), eventCount: Int32(eventCount))

        guard let commandQueue = device.makeCommandQueue() else { fatalError() }
        guard
            let uniformsBuffer = device.makeBuffer(bytes: &uniforms, length: MemoryLayout<FindMinMaxUniforms>.size),
            let minsBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size * eventCount, options: .storageModePrivate),
            let maxsBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size * eventCount, options: .storageModePrivate),
            let minMaxValuesBuffer = device.makeBuffer(length: MemoryLayout<MinMaxValues>.size * channelCount, options: .storageModeShared)
        else {
            fatalError()
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { fatalError() }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder(dispatchType: .serial) else { fatalError() }

        commandEncoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(buffer, offset: 0, index: 1)
        commandEncoder.setBuffer(minsBuffer, offset: 0, index: 2)
        commandEncoder.setBuffer(maxsBuffer, offset: 0, index: 3)
        commandEncoder.setBuffer(minMaxValuesBuffer, offset: 0, index: 4)

        let gridSize = MTLSize(width: eventCount, height: 1, depth: 1)
        let gridSingleSize = MTLSize(width: 1, height: 1, depth: 1)
        for _ in 0..<4 { //channelCount {
            commandEncoder.setComputePipelineState(pipelineInitChannelState)
            commandEncoder.dispatchThreads(gridSingleSize, threadsPerThreadgroup: gridSingleSize)
        
            commandEncoder.setComputePipelineState(pipelineCopyState)
            commandEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: gridSingleSize)

            for current in 0..<Int(log2(Double(eventCount))+1) {
                commandEncoder.setComputePipelineState(pipelineStepState)
                let currentGridSize = MTLSize(width: eventCount / (current + 1), height: 1, depth: 1)
                commandEncoder.dispatchThreads(currentGridSize, threadsPerThreadgroup: gridSingleSize)

                commandEncoder.setComputePipelineState(pipelineAfterStepState)
                commandEncoder.dispatchThreads(gridSingleSize, threadsPerThreadgroup: gridSingleSize)
            }
            commandEncoder.setComputePipelineState(pipelineFinalState)
            commandEncoder.dispatchThreads(gridSingleSize, threadsPerThreadgroup: gridSingleSize)
        }
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let elapsedTime = Foundation.Date().timeIntervalSince(begin)
        print("ElapsedTime: \(elapsedTime)")

        let finalValuesPointer = minMaxValuesBuffer.contents().bindMemory(to: MinMaxValues.self, capacity: channelCount)
        let result = UnsafeBufferPointer(start: finalValuesPointer, count: channelCount).map {
            DataRange.int(min: $0.min, max: $0.max)
        }
        return result
    }

    static func findMinMaxFloat(device: MTLDevice, library: MTLLibrary, buffer: MTLBuffer, channelCount: Int, eventCount: Int) throws -> [DataRange] {
        fatalError()
    }

}
