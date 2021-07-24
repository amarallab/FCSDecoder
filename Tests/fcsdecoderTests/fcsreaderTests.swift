import XCTest
@testable import fcsdecoder

final class fcsdecoderTests: XCTestCase {
    func testDecoder() throws {
        let beginData = Date()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "3215apc 100004", withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        let fcs = try FlowCytometry(from: data)
        let elapsedTime = Date().timeIntervalSince(beginData)
        print("Read in \(elapsedTime) seconds")
        print("Channels: \(fcs.text.channels.count)")
        print("Channel 0: \(fcs.channelDataRanges[0]), \(fcs.text.channels[0].r)")
    }
    
    func testBits() throws {
        let d1 = Data([1, 255, 7])
        let bits: [Int] = [7, 9, 8]
        let result = [0, 511, 7]
        
        var bb = BitBufferBigEndian(buffer: d1)
        for (current, result_value) in zip(bits, result) {
            let value = bb.next(current)
            XCTAssert(value == result_value)
        }
    }
    
    func testBytes() throws {
        let d1 = Data([23, 1, 0, 0, 0, 1, 0, 0, 8, 0, 0, 3, 0, 0, 4])
        let d2 = Data([23, 0, 1, 1, 0, 0, 8, 0, 0, 3, 0, 0, 4, 0, 0])
        let bits: [Int] = [8, 16, 24, 24, 24, 24]
        let result = [23, 256, 1, 8, 3, 4]
        
        let totalBits = bits.reduce(0, +)
        if !totalBits.isMultiple(of: 8) {
            fatalError()
        }
        
        var bb1 = BitBufferBigEndian(buffer: d1)
        var bb2 = BitBufferLittleEndian(buffer: d2)
        for (current, result_value) in zip(bits, result) {
            let value1 = bb1.next(current)
            let value2 = bb2.next(current)
            XCTAssert(value1 == result_value)
            XCTAssert(value2 == result_value)
        }
        XCTAssert(bb1.isEmpty)
        XCTAssert(bb2.isEmpty)
    }
    
    func testMultirowBytes() throws {
        let rawData: [UInt8] = [23, 1, 0, 0, 0, 1, 0, 0, 8, 0, 0, 3, 0, 0, 4]
        let d1 = Data((1..<3).flatMap { _ in rawData })
        let bits: [Int] = [8, 16, 24, 24, 24, 24]
        let totalBits = bits.reduce(0, +)
        let totalBytes = totalBits / 8
        let eventCount = d1.count / totalBytes
        let result: [UInt32] = [23, 256, 1, 8, 3, 4, 23, 256, 1, 8, 3, 4]
        
        var bb1 = BitBufferBigEndian(buffer: d1)
        var data: [UInt32] = []
        while !bb1.isEmpty {
            data.append(contentsOf: bits.map { bb1.next($0) })
        }
        XCTAssert(data.count == eventCount * bits.count)
        XCTAssert(data == result)
    }
}
