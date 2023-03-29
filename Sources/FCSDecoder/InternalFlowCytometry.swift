//
//  InternalFlowCytometry.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/23/21.
//

import Combine
import Foundation
import MetalKit

extension MTLComputeCommandEncoder {
    func dispatch(numberOfThreads: Int, pipelineState: MTLComputePipelineState) {
        let threadsPerThreadgroup: MTLSize
        let threadgroups: MTLSize
            
        if numberOfThreads < pipelineState.maxTotalThreadsPerThreadgroup {
            threadgroups = MTLSize(width: 1, height: 1, depth: 1)
            threadsPerThreadgroup = MTLSize(width: numberOfThreads, height: 1, depth: 1)
        } else {
            threadgroups = MTLSize(width: 1 + (numberOfThreads / pipelineState.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
            threadsPerThreadgroup = MTLSize(width: pipelineState.maxTotalThreadsPerThreadgroup, height: 1, depth: 1)
        }
        self.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
    }
}

struct InternalFlowCytometry {
    enum ReadingError: Error {
        // Metal issues
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
    
    enum Version {
        case fcs30
        case fcs31
    }

    enum FlowData {
        case int
        case float
    }

    enum DataRange: Equatable, Hashable {
        case int(min: UInt32, max: UInt32)
        case float(min: Float32, max: Float32)
//        case double(min: Double, max: Double)  Maybe in the future
    }

    let version: Version
    let text: TextSegment
    let data: FlowData
    let channelDataRanges: [DataRange]
    let dataBuffer: MTLBuffer
    
    init(from data: Data, using device: MTLDevice) throws {
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
                let dataBuffer = device.makeBuffer(bytes: buffer, length: MemoryLayout<Float32>.size * buffer.count)
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
                    $0.bindMemory(to: Float64.self).map {
                        Float64(bitPattern: $0.bitPattern.bigEndian)
                    }
                }.map { Float32($0) }
            case .littleEndian:
                buffer = data[dataStartIndex...dataEndIndex].withUnsafeBytes {
                    $0.bindMemory(to: Float64.self)
                }.map { Float32($0) }
            }
            guard
                let dataBuffer = device.makeBuffer(bytes: buffer, length: MemoryLayout<Float32>.size * buffer.count)
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
            let eventCount = self.text.tot

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
            var channelCount: UInt32
            var eventCount: UInt32
            var stride: UInt32
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
            channelCount: UInt32(channelCount),
            eventCount: UInt32(eventCount),
            stride: UInt32(stride),
            byteOrd: .int16LittleEndian)

        let uniformsLength = MemoryLayout<Uniforms>.stride
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
            var diff: UInt32
            var channelId: UInt32
            var channelCount: UInt32
            var eventCount: UInt32
        }

        struct MinMaxValues {
            var min: UInt32
            var max: UInt32
        }
                
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

        let uniforms = FindMinMaxUniforms(diff: 1, channelId: 0, channelCount: UInt32(channelCount), eventCount: UInt32(eventCount))

        guard let commandQueue = device.makeCommandQueue() else { fatalError() }
        guard
            let uniformsBuffer = device.makeBuffer(bytes: [uniforms], length: MemoryLayout<FindMinMaxUniforms>.size),
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

        for _ in 0..<channelCount {
            commandEncoder.setComputePipelineState(pipelineInitChannelState)
            commandEncoder.dispatch(numberOfThreads: 1, pipelineState: pipelineInitChannelState)

            commandEncoder.setComputePipelineState(pipelineCopyState)
            commandEncoder.dispatch(numberOfThreads: eventCount, pipelineState: pipelineCopyState)

            let logValue = ceil(log2(Float(eventCount))) - 1
            var numberOfThreads = Int(powf(2, logValue))
            while numberOfThreads > 0 {
                commandEncoder.setComputePipelineState(pipelineStepState)
                commandEncoder.dispatch(numberOfThreads: numberOfThreads, pipelineState: pipelineStepState)
                
                commandEncoder.setComputePipelineState(pipelineAfterStepState)
                commandEncoder.dispatch(numberOfThreads: 1, pipelineState: pipelineAfterStepState)
                
                numberOfThreads /= 2
            }
            commandEncoder.setComputePipelineState(pipelineFinalState)
            commandEncoder.dispatch(numberOfThreads: 1, pipelineState: pipelineFinalState)
        }
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let finalValuesPointer = minMaxValuesBuffer.contents().bindMemory(to: MinMaxValues.self, capacity: channelCount)
        let result = UnsafeBufferPointer(start: finalValuesPointer, count: channelCount).map {
            DataRange.int(min: $0.min, max: $0.max)
        }
        return result
    }

    static func findMinMaxFloat(device: MTLDevice, library: MTLLibrary, buffer: MTLBuffer, channelCount: Int, eventCount: Int) throws -> [DataRange] {
        struct FindMinMaxUniforms {
            var diff: UInt32
            var channelId: UInt32
            var channelCount: UInt32
            var eventCount: UInt32
        }

        struct MinMaxValues {
            var min: Float32
            var max: Float32
        }
                
        guard
            let findMinMaxInitChannelFunction = library.makeFunction(name: "find_min_max_init_channel_float"),
            let findMinMaxCopyFunction = library.makeFunction(name: "find_min_max_copy_float"),
            let findMinMaxStepFunction = library.makeFunction(name: "find_min_max_step_float"),
            let findMinMaxAfterStepFunction = library.makeFunction(name: "find_min_max_after_step_float"),
            let findMinMaxFinalFunction = library.makeFunction(name: "find_min_max_final_float")
        else {
            throw ReadingError.functionError
        }

        let pipelineInitChannelState = try device.makeComputePipelineState(function: findMinMaxInitChannelFunction)
        let pipelineCopyState = try device.makeComputePipelineState(function: findMinMaxCopyFunction)
        let pipelineStepState = try device.makeComputePipelineState(function: findMinMaxStepFunction)
        let pipelineAfterStepState = try device.makeComputePipelineState(function: findMinMaxAfterStepFunction)
        let pipelineFinalState = try device.makeComputePipelineState(function: findMinMaxFinalFunction)

        let uniforms = FindMinMaxUniforms(diff: 1, channelId: 0, channelCount: UInt32(channelCount), eventCount: UInt32(eventCount))

        guard let commandQueue = device.makeCommandQueue() else { fatalError() }
        guard
            let uniformsBuffer = device.makeBuffer(bytes: [uniforms], length: MemoryLayout<FindMinMaxUniforms>.size),
            let minsBuffer = device.makeBuffer(length: MemoryLayout<Float32>.size * eventCount, options: .storageModePrivate),
            let maxsBuffer = device.makeBuffer(length: MemoryLayout<Float32>.size * eventCount, options: .storageModePrivate),
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

        let gridSingleSize = MTLSize(width: 1, height: 1, depth: 1)
        for _ in 0..<channelCount {
            commandEncoder.setComputePipelineState(pipelineInitChannelState)
            commandEncoder.dispatch(numberOfThreads: 1, pipelineState: pipelineInitChannelState)

            commandEncoder.setComputePipelineState(pipelineCopyState)
            commandEncoder.dispatch(numberOfThreads: eventCount, pipelineState: pipelineCopyState)

            let logValue = ceil(log2(Float(eventCount))) - 1
            var numberOfThreads = Int(powf(2, logValue))
            while numberOfThreads > 0 {
                commandEncoder.setComputePipelineState(pipelineStepState)
                commandEncoder.dispatch(numberOfThreads: numberOfThreads, pipelineState: pipelineStepState)

                commandEncoder.setComputePipelineState(pipelineAfterStepState)
                commandEncoder.dispatch(numberOfThreads: 1, pipelineState: pipelineAfterStepState)

                numberOfThreads /= 2
            }
            commandEncoder.setComputePipelineState(pipelineFinalState)
            commandEncoder.dispatch(numberOfThreads: 1, pipelineState: pipelineFinalState)
        }
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let finalValuesPointer = minMaxValuesBuffer.contents().bindMemory(to: MinMaxValues.self, capacity: channelCount)
        let result = UnsafeBufferPointer(start: finalValuesPointer, count: channelCount).map {
            DataRange.float(min: $0.min, max: $0.max)
        }
        return result
    }

}
