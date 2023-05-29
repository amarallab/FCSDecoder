import XCTest
@testable import FCSDecoder

final class FCSDecoderHistogramTests: XCTestCase {
    
    var device: MTLDevice!
    
    public enum TestError: Error {
        case deviceNotFound
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
        _ = try fcs.createHistograms(device: device, useLog10: true) { _ in 1024 }
        let histogramElapsedTime = Date().timeIntervalSince(beginData)
        
        print("Read in \(elapsedTime) seconds")
        print("Channels: \(fcs.channels.count)")
        print("DataRange: \(fcs.data)")
        print("Histogram: \(histogramElapsedTime - elapsedTime)")
    }
    
    func testFloatChannels() throws {
        let beginData = Date()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "BD - FACS Aria II - Compensation Controls_B515 Stained Control", withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        let fcs = try FlowCytometry(from: data, using: device)
        let elapsedTime = Date().timeIntervalSince(beginData)
        let binsCount = 10
        let histo = try fcs.createHistograms(device: device, useLog10: false) { _ in binsCount }
        let histogramElapsedTime = Date().timeIntervalSince(beginData)

        print("Event count: \(fcs.eventCount)")
        let ptr = fcs.dataBuffer.contents().bindMemory(to: Float32.self, capacity: fcs.eventCount * fcs.channels.count)
        for channel in fcs.channels {
            var values: [Float32] = []
            for i in 0..<fcs.eventCount {
                values.append(ptr[i * channel.stride/32 + channel.offset/32])
            }
            let maxValue = values.max() ?? 1
            let minValue = values.min() ?? 0
            let step = Float32(maxValue - minValue) / Float32(binsCount)
            var bins = Array(repeating: 0, count: binsCount)
            for value in values {
                let bin = Int(Float32(value - minValue) / step).clamp(0, binsCount - 1)
                bins[bin] += 1
            }
            let binMaxValue = bins.max() ?? 0
            if let data = histo.histogram[channel.n.uppercased()] {
                let ptr2 = histo.dataBuffer.contents().bindMemory(to: UInt32.self, capacity: binsCount)
                var histValues: [UInt32] = []
                for i in 0..<binsCount {
                    histValues.append(ptr2[Int(data.offset) + i])
                }
                print("Calculated: \(bins), hist: \(histValues), offset: \(data.offset) \(data.step), \(step), \(data.maxValue), \(binMaxValue)")
            }
        }
        let ptr2 = histo.dataBuffer.contents().bindMemory(to: UInt32.self, capacity: binsCount)
        var accum = 0
        for i in 0..<binsCount * fcs.channels.count {
            accum += Int(ptr2[i])
        }
        print("Accum: \(accum)")
        print("Read in \(elapsedTime) seconds")
        print("Channels: \(fcs.channels.count)")
        print("DataRange: \(fcs.data)")
        print("Histogram: \(histogramElapsedTime - elapsedTime)")
    }

}
