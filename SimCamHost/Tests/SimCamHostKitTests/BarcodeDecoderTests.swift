// SimCamHost/Tests/SimCamHostKitTests/BarcodeDecoderTests.swift
import XCTest
import CoreImage
import CoreVideo
import AVFoundation
@testable import SimCamHostKit

final class BarcodeDecoderTests: XCTestCase {
    /// Genera un código de barras con un CIFilter y lo rasteriza a CVPixelBuffer BGRA.
    private func buffer(filterName: String, message: String, scale: CGFloat = 10) -> CVPixelBuffer {
        let filter = CIFilter(name: filterName)!
        filter.setValue(message.data(using: .ascii), forKey: "inputMessage")
        let img = filter.outputImage!.transformed(by: .init(scaleX: scale, y: scale))
        let w = Int(img.extent.width), h = Int(img.extent.height)
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary, &pb)
        let context = CIContext()
        context.render(img, to: pb!)
        return pb!
    }

    func test_decode_readsQR() {
        let pb = buffer(filterName: "CIQRCodeGenerator", message: "HELLO-QR")
        let codes = BarcodeDecoder().decode(pb)
        XCTAssertEqual(codes.first?.stringValue, "HELLO-QR")
        XCTAssertEqual(codes.first?.type, AVMetadataObject.ObjectType.qr.rawValue)
    }

    func test_decode_readsCode128() {
        let pb = buffer(filterName: "CICode128BarcodeGenerator", message: "ABC123")
        let codes = BarcodeDecoder().decode(pb)
        XCTAssertEqual(codes.first?.stringValue, "ABC123")
        XCTAssertEqual(codes.first?.type, AVMetadataObject.ObjectType.code128.rawValue)
    }
}
