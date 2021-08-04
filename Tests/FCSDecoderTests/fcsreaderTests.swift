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
        print("Read in \(elapsedTime) seconds")
        print("Channels: \(fcs.text.channels.count)")
        print("Channel 0: \(fcs.channelDataRanges[0]), \(fcs.text.channels[0].r)")
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
