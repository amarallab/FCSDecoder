//
//  File.swift
//  
//
//  Created by Heliodoro Tejedor Navarro on 31/3/23.
//

import Foundation
import MetalKit

extension Comparable {
    func clamp(_ min: Self, _ max: Self) -> Self {
        Swift.max(min, Swift.min(max, self))
    }
}

public struct HistogramChannel: Equatable, Hashable, Identifiable {
    public let binsCount: UInt32
    public let step: Float32
    public let usedLn: Bool
    public let validEventCount: Int
    public let maxValue: Int
    public let offset: UInt32
    
    public var id: Self { self }
}

public struct HistogramData {
    public let dataBuffer: MTLBuffer
    public let totalMaxValue: Int
    public let histogram: [Channel: HistogramChannel]
}

extension HistogramData: Hashable, Equatable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(histogram)
    }
    
    public static func == (lhs: HistogramData, rhs: HistogramData) -> Bool {
        lhs.histogram == rhs.histogram
    }
}

extension FlowCytometry {
    public enum HistogramError: Error {
        case functionError
        case commandError
    }

    public typealias HistogramBinsCount = (ChannelDataRange) -> Int
    
    public func createHistograms(device: MTLDevice, useLn: Bool = false, binsCount: HistogramBinsCount? = nil) throws -> HistogramData {
        let functionName: String
        switch data {
        case .int:
            functionName = "intHistogramAssignBin"
        case .float:
            functionName = "floatHistogramAssignBin"
        }

        let library = try device.makeDefaultLibrary(bundle: .module)
        guard
            let assignBinFunction = library.makeFunction(name: functionName),
            let histogramFunction = library.makeFunction(name: "histogram")
        else {
            throw HistogramError.functionError
        }

        let binsCounts = channels.map { binsCount?($0.dataRange) ?? 1024 }

        struct MainUniforms {
            var channelCount: UInt32
            var eventCount: UInt32
        }
        var mainUniforms = MainUniforms(channelCount: UInt32(channels.count), eventCount: UInt32(eventCount))
        let mainUniformsLength = MemoryLayout<MainUniforms>.stride
        
        struct ChannelInfoUniforms {
            var min: Float32
            var step: Float32
            var offset: UInt32
            var binsCount: UInt32
            var useLn: Bool
            var validEventCount: Int32 = 0
            var maxValue: UInt32 = 0
        }
        
        var channelInfoUniforms: [ChannelInfoUniforms] = []
        var offset: UInt32 = 0
        for (channel, binsCount) in zip(channels, binsCounts) {
            let minValue: Float32
            let maxValue: Float32
            switch channel.dataRange {
            case .int(min: let min, max: let max):
                if useLn {
                    minValue = log(Swift.max(1.0, Float32(min)))
                    maxValue = log(Swift.max(1.0, Float32(max)))
                } else {
                    minValue = Float32(min)
                    maxValue = Float32(max)
                }
            case .float(min: let min, max: let max):
                if useLn {
                    minValue = log(Swift.max(1.0, Float32(min)))
                    maxValue = log(Swift.max(1.0, Float32(max)))
                } else {
                    minValue = Float32(min)
                    maxValue = Float32(max)
                }
            }
            let step = (maxValue - minValue) / Float32(binsCount)
            let channelInfo = ChannelInfoUniforms(
                min: minValue,
                step: step,
                offset: offset,
                binsCount: UInt32(binsCount),
                useLn: useLn
            )
            channelInfoUniforms.append(channelInfo)
            offset += UInt32(binsCount)
        }
        
        let channelInfoUniformsLength = MemoryLayout<ChannelInfoUniforms>.stride
        
        let totalBinsCount = binsCounts.reduce(0, +)
       
        guard
            let commandQueue = device.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let mainUniformsBuffer = device.makeBuffer(bytes: &mainUniforms, length: mainUniformsLength),
            let channelInfoUniformsBuffer = device.makeBuffer(bytes: channelInfoUniforms, length: channelInfoUniformsLength * channels.count),
            let assignedBinBuffer = device.makeBuffer(length: channels.count * eventCount * MemoryLayout<Int32>.size, options: .storageModeShared),
            let histogramBuffer = device.makeBuffer(length: totalBinsCount * MemoryLayout<UInt32>.size, options: .storageModeShared)
        else {
            throw HistogramError.commandError
        }
        
        // First, assign the bins
        let assignBinPipelineState = try device.makeComputePipelineState(function: assignBinFunction)
        guard
            let commandEncoder1 = commandBuffer.makeComputeCommandEncoder()
        else {
            throw HistogramError.commandError
        }
        commandEncoder1.setComputePipelineState(assignBinPipelineState)
        commandEncoder1.setBuffer(dataBuffer, offset: 0, index: 0)
        commandEncoder1.setBuffer(mainUniformsBuffer, offset: 0, index: 1)
        commandEncoder1.setBuffer(channelInfoUniformsBuffer, offset: 0, index: 2)
        commandEncoder1.setBuffer(assignedBinBuffer, offset: 0, index: 3)
        commandEncoder1.dispatchThreads(
            MTLSize(width: channels.count, height: eventCount, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        commandEncoder1.endEncoding()
        
        // Second, create the counts
        let histogramPipelineState = try device.makeComputePipelineState(function: histogramFunction)
        guard
            let commandEncoder2 = commandBuffer.makeComputeCommandEncoder()
        else {
            throw HistogramError.commandError
        }
        commandEncoder2.setComputePipelineState(histogramPipelineState)
        commandEncoder2.setBuffer(mainUniformsBuffer, offset: 0, index: 0)
        commandEncoder2.setBuffer(channelInfoUniformsBuffer, offset: 0, index: 1)
        commandEncoder2.setBuffer(assignedBinBuffer, offset: 0, index: 2)
        commandEncoder2.setBuffer(histogramBuffer, offset: 0, index: 3)
        commandEncoder2.dispatchThreads(
            MTLSize(width: channels.count, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        commandEncoder2.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        
        let finalChannelInfoPointer = channelInfoUniformsBuffer.contents().bindMemory(to: ChannelInfoUniforms.self, capacity: channels.count)
        let result = UnsafeBufferPointer(start: finalChannelInfoPointer, count: channels.count).map { $0 }

        var histogram: [Channel: HistogramChannel] = [:]
        for (channel, current) in zip(channels, result) {
            histogram[channel] = HistogramChannel(
                binsCount: current.binsCount,
                step: current.step,
                usedLn: current.useLn,
                validEventCount: Int(current.validEventCount),
                maxValue: Int(current.maxValue),
                offset: current.offset)
        }
        return HistogramData(
            dataBuffer: histogramBuffer,
            totalMaxValue: Int(result.map { $0.maxValue }.max() ?? 0),
            histogram: histogram)
    }
}
