import XCTest
@testable import SimCamHostKit

final class MJPEGFramingTests: XCTestCase {
    func test_httpHeader_isMultipart() {
        let header = String(data: MJPEGFraming.httpHeader(boundary: "simcamframe"), encoding: .ascii)!
        XCTAssertTrue(header.hasPrefix("HTTP/1.0 200 OK\r\n"))
        XCTAssertTrue(header.contains("Content-Type: multipart/x-mixed-replace; boundary=simcamframe\r\n"))
        XCTAssertTrue(header.hasSuffix("\r\n\r\n"))
    }

    func test_part_hasBoundaryAndLength() {
        let jpeg = Data([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9])
        let part = MJPEGFraming.part(jpeg: jpeg, boundary: "simcamframe")
        // prefix(62): exact byte length of "--simcamframe\r\nContent-Type: image/jpeg\r\nContent-Length: 6\r\n\r\n"
        // prefix(80) would include non-ASCII JPEG bytes and make String(…encoding:.ascii) return nil
        let text = String(data: part.prefix(62), encoding: .ascii)!
        XCTAssertTrue(text.hasPrefix("--simcamframe\r\nContent-Type: image/jpeg\r\nContent-Length: 6\r\n\r\n"))
        XCTAssertEqual(part.suffix(2), Data([0x0D, 0x0A])) // \r\n final
        XCTAssertTrue(part.range(of: jpeg) != nil)
    }
}
