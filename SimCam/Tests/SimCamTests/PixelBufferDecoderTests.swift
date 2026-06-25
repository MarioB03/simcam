import XCTest
import CoreVideo
import CoreGraphics
import ImageIO
@testable import SimCam

final class PixelBufferDecoderTests: XCTestCase {
    private func makeJPEG(width: Int, height: Int) -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmap = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs, bitmapInfo: bitmap)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cg = ctx.makeImage()!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    func test_decode_returnsBufferWithRightSize() {
        let jpeg = makeJPEG(width: 24, height: 16)
        let pb = PixelBufferDecoder().decode(jpeg)
        XCTAssertNotNil(pb)
        XCTAssertEqual(CVPixelBufferGetWidth(pb!), 24)
        XCTAssertEqual(CVPixelBufferGetHeight(pb!), 16)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(pb!), kCVPixelFormatType_32BGRA)
    }

    func test_decode_returnsNilForGarbage() {
        XCTAssertNil(PixelBufferDecoder().decode(Data([0x00, 0x01, 0x02])))
    }
}
