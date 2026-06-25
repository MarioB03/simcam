import XCTest
@testable import SimCam

final class MJPEGStreamParserTests: XCTestCase {
    private func part(_ jpeg: Data) -> Data {
        var d = Data("--simcamframe\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpeg.count)\r\n\r\n".utf8)
        d.append(jpeg); d.append(Data([0x0D, 0x0A]))
        return d
    }

    func test_parsesSingleFrame() {
        let parser = MJPEGStreamParser(boundary: "simcamframe")
        let jpeg = Data([0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9])
        let frames = parser.append(part(jpeg))
        XCTAssertEqual(frames, [jpeg])
    }

    func test_parsesTwoConcatenatedFrames() {
        let parser = MJPEGStreamParser(boundary: "simcamframe")
        let a = Data(repeating: 0x11, count: 4)
        let b = Data(repeating: 0x22, count: 6)
        var stream = part(a); stream.append(part(b))
        XCTAssertEqual(parser.append(stream), [a, b])
    }

    func test_handlesSplitChunks() {
        let parser = MJPEGStreamParser(boundary: "simcamframe")
        let jpeg = Data(repeating: 0xAB, count: 10)
        let full = part(jpeg)
        let mid = full.count / 2
        XCTAssertEqual(parser.append(full.prefix(mid)), [])
        XCTAssertEqual(parser.append(full.suffix(from: mid)), [jpeg])
    }

    func test_waitsWhenBodyIncomplete() {
        let parser = MJPEGStreamParser(boundary: "simcamframe")
        let header = Data("--simcamframe\r\nContent-Type: image/jpeg\r\nContent-Length: 5\r\n\r\n".utf8)
        XCTAssertEqual(parser.append(header), [])
        XCTAssertEqual(parser.append(Data([1, 2, 3])), [])      // solo 3 de 5
        XCTAssertEqual(parser.append(Data([4, 5])), [Data([1, 2, 3, 4, 5])])
    }
}
