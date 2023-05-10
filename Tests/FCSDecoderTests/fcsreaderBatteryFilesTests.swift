import XCTest
@testable import FCSDecoder

final class FCSDecoderBatteryFilesTests: XCTestCase {
    
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
    
    private func test(resource: String) throws {
        print("Reading \"\(resource)\"...")
        let beginData = Date()
        let url = try XCTUnwrap(Bundle.module.url(forResource: resource, withExtension: "fcs"))
        let data = try Data(contentsOf: url)
        let _ = try FlowCytometry(from: data, using: device)
        let elapsedTime = Date().timeIntervalSince(beginData)
        print("\tRead in \(elapsedTime) seconds")
    }
    
    func testSimpleFiles() throws {
        for resource in [
            "1 WT_001",
            "3215apc 100004"]
        {
            try test(resource: resource)
        }
    }

    func testAccuri() throws {
        for resource in [
            "Accuri - C6 - A01 H2O",
            "Accuri - C6 - A02 Spherotech 8 Peak Beads",
            "Accuri - C6 - A03 HPB - CD45 PerCP",
            "Accuri - C6"]
        {
            try test(resource: resource)
        }
    }

//    func testAppliedBiosystems() throws {
//        for resource in [
//            "Applied Biosystems - Attune"]
//        {
//            try test(resource: resource)
//        }
//    }

//    func testBD() throws {
//        for resource in [
//            "BD - FACS Aria II - Compensation Controls_B515 Stained Control",
//            "BD - FACS Aria II - Compensation Controls_G560 Stained Control",
//            "BD - FACS Aria II - Compensation Controls_G610 Stained Control",
//            "BD - FACS Aria II - Compensation Controls_G660 Stained Control",
//            "BD - FACS Aria II - Compensation Controls_G710 Stained Control",
//            "BD - FACS Aria II"]
//        {
//            try test(resource: resource)
//        }
//    }
    
//    func testBeckman() throws {
//        for resource in [
//            "Beckman Coulter - Cyan",
//            "Beckman Coulter - MoFlo Astrios - linear settings",
//            "Beckman Coulter - MoFlo Astrios - log settings",
//            "Beckman Coulter - MoFlo XDP"]
//        {
//            try test(resource: resource)
//        }
//    }
    
    func testCytek() throws {
        for resource in [
            "Cytek DxP10 - 6-peak Q&b 11-06-2012 001",
            "Cytek DxP10 - APC COMP BEADS011",
            "Cytek DxP10 - BLANK COMP BEADS007",
            "Cytek DxP10 - FITC COMP BEADS008",
            "Cytek DxP10 - PE COMP BEADS009",
            "Cytek DxP10 - PERCP COMP BEADS010"]
        {
            try test(resource: resource)
        }
    }
    
//    func testMillipore() throws {
//        for resource in [
//            "Millipore - easyCyte 6HT-2L - InCyte"]
//        {
//            try test(resource: resource)
//        }
//    }
    
    func testMiltenyi() throws {
        for resource in [
            "Miltenyi Biotec - MACSQuant Analyzer"]
        {
            try test(resource: resource)
        }
    }

    func testMVaFiles() throws {
        for resource in [
            "MVa2011-06-30_fcs30",
            "MVa2011-06-30_fcs30c",
            "MVa2011-06-30_fcs31"]
        {
            try test(resource: resource)
        }
    }
    
//    func testPartec() throws {
//        for resource in [
//            "Partec - PAS - 8 peak beads"]
//        {
//            try test(resource: resource)
//        }
//    }
    
    func testStratedigm() throws {
        for resource in [
            "Stratedigm - S1400 - 8 Peaks Beads"]
        {
            try test(resource: resource)
        }
    }
    
//    func testVerity() throws {
//        for resource in [
//            "Verity Software House - GemStoneGeneratedData - 500000events"]
//        {
//            try test(resource: resource)
//        }
//    }
}
