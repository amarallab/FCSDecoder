import XCTest
@testable import FCSDecoder

final class UpdateFinMinMaxTests: XCTestCase {
    
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
    
    func testSimpleFileDecoder() throws {
        let beginData = Date()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "MVa2011-06-30_fcs31", withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        let fcs = try FlowCytometry(from: data, using: device)
        let elapsedTime = Date().timeIntervalSince(beginData)
        print("Read in \(elapsedTime) seconds")
        print("Channels: \(fcs.channels.count)")
        print("Channel 0: \(fcs.channels[0].dataRange), \(fcs.channels[0].r)")
    }
}
