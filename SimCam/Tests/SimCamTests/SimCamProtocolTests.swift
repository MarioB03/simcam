import XCTest
@testable import SimCam

final class SimCamProtocolTests: XCTestCase {
    func test_defaultsMatchHostContract() {
        XCTAssertEqual(SimCamProtocol.host, "127.0.0.1")
        XCTAssertEqual(SimCamProtocol.port, 8474)
        XCTAssertEqual(SimCamProtocol.path, "/stream")
        XCTAssertEqual(SimCamProtocol.boundary, "simcamframe")
    }
}
