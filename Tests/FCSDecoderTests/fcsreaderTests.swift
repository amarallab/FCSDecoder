import XCTest
@testable import FCSDecoder

final class FCSDecoderTests: XCTestCase {
    func testSimpleFileDecoder() throws {
        let beginData = Date()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "3215apc 100004", withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        let fcs = try FlowCytometry(from: data)
        let elapsedTime = Date().timeIntervalSince(beginData)
        print("Read in \(elapsedTime) seconds")
        print("Channels: \(fcs.text.channels.count)")
        print("Channel 0: \(fcs.channelDataRanges[0]), \(fcs.text.channels[0].r)")
    }
    
    func testDecoderNoDataEndIndex() throws {
        let beginData = Date()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "1 WT_001", withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        let fcs = try FlowCytometry(from: data)
        let elapsedTime = Date().timeIntervalSince(beginData)

        let minValues = [1282, 0, 2290, 246, 119, 261, 177, 135, 137, 121, 98, 94, 178, 2290, 246, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32768, 66]
        let maxValues = [65528, 65535, 65535, 65535, 64406, 65204, 65535, 64822, 65484, 151, 65535, 65535, 212, 65535, 65535, 64391, 64663, 65535, 64679, 65437, 65266, 65493, 3, 0, 32768, 32768, 65535]
        let finalValues = zip(minValues, maxValues)
        print("Read in \(elapsedTime) seconds")
        print("Channels: \(fcs.text.channels.count)")
        for (i, (valid, current)) in zip(finalValues, fcs.channelDataRanges).enumerated() {
            print("Channel \(i): \(valid) ==? \(current)")
            if i > 4 {
                break
            }
        }
    }
    
    func testAllResourcesDecoder() throws {
        for url in try XCTUnwrap(Bundle.module.urls(forResourcesWithExtension: "fcs", subdirectory: nil)) {
            print("Testing \"\(url.lastPathComponent)\"")
            let beginData = Date()
            let data = try Data(contentsOf: url)
            let fcs = try FlowCytometry(from: data)
            let elapsedTime = Date().timeIntervalSince(beginData)
            print("\tRead in \(elapsedTime) seconds")
            print("\tChannels: \(fcs.text.channels.count)")
            print("\tChannel 0: \(fcs.channelDataRanges[0]), \(fcs.text.channels[0].r)")
        }
    }

}
