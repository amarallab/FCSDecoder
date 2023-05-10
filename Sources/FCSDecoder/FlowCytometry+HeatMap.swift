//
//  File.swift
//  
//
//  Created by Heliodoro Tejedor Navarro on 4/4/23.
//

import Foundation
import MetalKit

public struct HeatMapData {
    public let dataBuffer: MTLBuffer
    public let xBinsCount: Int
    public let yBinsCount: Int
    public let totalMaxValue: Int
}

extension HeatMapData: Hashable, Equatable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(xBinsCount)
        hasher.combine(yBinsCount)
        hasher.combine(totalMaxValue)
    }
    
    public static func == (lhs: HeatMapData, rhs: HeatMapData) -> Bool {
        lhs.xBinsCount == rhs.xBinsCount
        && lhs.yBinsCount == rhs.yBinsCount
        && lhs.totalMaxValue == rhs.totalMaxValue
    }
}

extension FlowCytometry {
    public enum HeatMapError: Error {
        case mustBeSameDataBuffer
        case functionError
        case commandError
    }
    
    public func createHeatMap(device: MTLDevice, useLn: Bool = false, xChannel: Channel, yChannel: Channel, xRange: ChannelDataRange, yRange: ChannelDataRange, xBinsCount: Int, yBinsCount: Int) throws -> HeatMapData {
        if xChannel.stride != yChannel.stride {
            throw HeatMapError.mustBeSameDataBuffer
        }
        let functionName: String
        switch data {
        case .int:
            functionName = "intHeatMapAssignBin"
        case .float:
            functionName = "floatHeatMapAssignBin"
        }

        let library = try device.makeDefaultLibrary(bundle: .module)
        guard
            let assignBinFunction = library.makeFunction(name: functionName)
        else {
            throw HeatMapError.functionError
        }
        
        struct MainUniforms {
            var eventCount: UInt32
            var xBinsCount: UInt32
            var yBinsCount: UInt32
            var xOffset: UInt32
            var yOffset: UInt32
            var stride: UInt32
            var xMin: Float32
            var xStep: Float32
            var yMin: Float32
            var yStep: Float32
            var useLn: Bool
        }
        
        let xMinValue: Float32
        let xMaxValue: Float32
        switch xRange {
        case .int(min: let min, max: let max):
            xMinValue = useLn ? log10(Swift.max(1.0, Float32(min))) : Float32(min)
            xMaxValue = useLn ? log10(Swift.max(1.0, Float32(max))) : Float32(max)
        case .float(min: let min, max: let max):
            xMinValue = useLn ? log10(Swift.max(1.0, Float32(min))) : Float32(min)
            xMaxValue = useLn ? log10(Swift.max(1.0, Float32(max))) : Float32(max)
        }
        let xStep = (xMaxValue - xMinValue) / Float32(xBinsCount)
        
        let yMinValue: Float32
        let yMaxValue: Float32
        switch yRange {
        case .int(min: let min, max: let max):
            yMinValue = useLn ? log10(Swift.max(1.0, Float32(min))) : Float32(min)
            yMaxValue = useLn ? log10(Swift.max(1.0, Float32(max))) : Float32(max)
        case .float(min: let min, max: let max):
            yMinValue = useLn ? log10(Swift.max(1.0, Float32(min))) : Float32(min)
            yMaxValue = useLn ? log10(Swift.max(1.0, Float32(max))) : Float32(max)
        }
        let yStep = (yMaxValue - yMinValue) / Float32(yBinsCount)
        
        var mainUniforms = MainUniforms(
            eventCount: UInt32(eventCount),
            xBinsCount: UInt32(xBinsCount),
            yBinsCount: UInt32(yBinsCount),
            xOffset: UInt32(xChannel.offset),
            yOffset: UInt32(yChannel.offset),
            stride: UInt32(xChannel.stride),
            xMin: xMinValue,
            xStep: xStep,
            yMin: yMinValue,
            yStep: yStep,
            useLn: useLn
        )
        let mainUniformsLength = MemoryLayout<MainUniforms>.stride
        
        guard
            let commandQueue = device.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let mainUniformsBuffer = device.makeBuffer(bytes: &mainUniforms, length: mainUniformsLength),
            let assignedBinBuffer = device.makeBuffer(length: 2 * eventCount * MemoryLayout<Int32>.size, options: .storageModeShared)
        else {
            throw HeatMapError.commandError
        }
        
        // First, assign the bins
        let assignBinPipelineState = try device.makeComputePipelineState(function: assignBinFunction)
        guard
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            throw HistogramError.commandError
        }
        commandEncoder.setComputePipelineState(assignBinPipelineState)
        commandEncoder.setBuffer(dataBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(mainUniformsBuffer, offset: 0, index: 1)
        commandEncoder.setBuffer(assignedBinBuffer, offset: 0, index: 2)
        commandEncoder.dispatchThreads(
            MTLSize(width: 2, height: eventCount, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        var binData = Array(repeating: Int32(0), count: xBinsCount * yBinsCount)
        let ptr = assignedBinBuffer.contents().bindMemory(to: Int32.self, capacity: 2 * eventCount)
        for i in 0..<eventCount {
            let x = Int(ptr[i * 2])
            let y = Int(ptr[i * 2 + 1])
            let index = y * xBinsCount + x
            if x != -1 && y != -1 && index >= 0 && index < xBinsCount * yBinsCount {
                binData[index] += 1
            }
        }

        guard
            let heatMapBuffer = device.makeBuffer(bytes: binData, length: xBinsCount * yBinsCount * MemoryLayout<UInt32>.size, options: .storageModeShared)
        else {
            throw HeatMapError.commandError
        }
        
        return .init(dataBuffer: heatMapBuffer, xBinsCount: xBinsCount, yBinsCount: yBinsCount, totalMaxValue: Int(binData.max() ?? 0))
    }
    
}
