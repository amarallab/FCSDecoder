import XCTest
@testable import FCSDecoder

final class UpdateFinMinMaxTests: XCTestCase {
    func testSimpleFileDecoder() throws {
        let beginData = Date()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "MVa2011-06-30_fcs31", withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        let fcs = try FCS(from: data)
        let elapsedTime = Date().timeIntervalSince(beginData)
        print("Read in \(elapsedTime) seconds")
        print("Channels: \(fcs.channels.count)")
        print("Channel 0: \(fcs.channels[0].dataRange), \(fcs.channels[0].r)")
    }
}
