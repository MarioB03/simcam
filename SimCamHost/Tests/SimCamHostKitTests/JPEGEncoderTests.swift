import XCTest
import CoreVideo
@testable import SimCamHostKit

final class JPEGEncoderTests: XCTestCase {
    private func makeBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32BGRA, nil, &pb)
        guard let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 0x7F, CVPixelBufferGetBytesPerRow(buffer) * height)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    func test_encode_producesJPEGMagicBytes() throws {
        let encoder = JPEGEncoder()
        guard let buffer = makeBuffer(width: 32, height: 32) else {
            return XCTFail("CVPixelBufferCreate falló — no se puede continuar el test")
        }
        let data = encoder.encode(buffer)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.prefix(2), Data([0xFF, 0xD8])) // SOI
        XCTAssertEqual(data?.suffix(2), Data([0xFF, 0xD9])) // EOI
    }
}
