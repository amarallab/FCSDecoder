import XCTest
@testable import fcsdecoder

final class fcsdecoderTests: XCTestCase {
    func testDecoder() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "3215apc 100004", withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        
        let textSegmentData = data[256...1335]
        let decoder = SegmentDecoder()
        do {
            let v = try decoder.decode(TextSegment.self, from: textSegmentData)
            print("Result: \(v)")
            print(v.channels.count)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
