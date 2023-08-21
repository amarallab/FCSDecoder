import XCTest
@testable import FCSDecoder

final class FCSDecoderHeatMapTests: XCTestCase {
    
    var device: MTLDevice!
    
    public enum TestError: Error {
        case deviceNotFound
        case noChannels
    }
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        guard
            let device = MTLCreateSystemDefaultDevice()
        else {
            throw TestError.deviceNotFound
        }
        self.device = device
    }
    
    func testIntChannels() throws {
        let beginData = Date()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "1 WT_001", withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        let fcs = try FlowCytometry(from: data, using: device)
        let elapsedTime = Date().timeIntervalSince(beginData)
        guard
            let channelX = fcs.channels.first,
            let channelY = fcs.channels.first(where: { $0.n != channelX.n })
        else {
            throw TestError.noChannels
        }
        let unionRange = ChannelDataRange.union(channelX.dataRange, channelY.dataRange)
        _ = try fcs.createHeatMap(device: device, xChannel: channelX, yChannel: channelY, xRange: unionRange, yRange: unionRange, xBinsCount: 10, yBinsCount: 10)
        let heatMapElapsedTime = Date().timeIntervalSince(beginData)
        
        print("Read in \(elapsedTime) seconds")
        print("Channels: \(fcs.channels.count)")
        print("DataRange: \(fcs.data)")
        print("HeatMap: \(heatMapElapsedTime - elapsedTime)")
    }
    
    func testFloatChannels() throws {
        let beginData = Date()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "BD - FACS Aria II - Compensation Controls_B515 Stained Control", withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        let fcs = try FlowCytometry(from: data, using: device)
        let elapsedTime = Date().timeIntervalSince(beginData)

        guard
            let channelX = fcs.channels.first,
            let channelY = fcs.channels.first(where: { $0.n != channelX.n })
        else {
            throw TestError.noChannels
        }
        let heatMap = try fcs.createHeatMap(device: device, useLog10: false, xChannel: channelX, yChannel: channelY, xRange: channelX.dataRange, yRange: channelY.dataRange, xBinsCount: 10, yBinsCount: 1)
        let heatMapElapsedTime = Date().timeIntervalSince(beginData)
        
        repeat {
            let ptr = heatMap.dataBuffer.contents().bindMemory(to: UInt32.self, capacity: 10)
            var values: [UInt32] = []
            for i in 0..<10 {
                let value = ptr[i]
                values.append(value)
            }
            print("HeatMap: \(values), sum: \(values.reduce(0, +))")
        } while false
        
        let histo = try fcs.createHistograms(device: device, useLog10: false) { _ in 10 }
        for channel in fcs.channels {
            guard
                let x = histo.histogram[channel.n.uppercased()]
            else {
                throw TestError.noChannels
            }

            let ptr = histo.dataBuffer.contents().bindMemory(to: UInt32.self, capacity: fcs.channels.count * 10)
            var values: [UInt32] = []
            for i in 0..<10 {
                let value = ptr[i + Int(x.offset)]
                values.append(value)
            }
            print("Histo: \(channel.n): \(values), sum: \(values.reduce(0, +))")
        }
        print("Read in \(elapsedTime) seconds")
        print("HeatMap: \(heatMapElapsedTime - elapsedTime)")
    }

}
