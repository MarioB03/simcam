import CoreImage
import CoreVideo

/// Codifica un `CVImageBuffer` (BGRA) a JPEG en sRGB usando Core Image.
public struct JPEGEncoder {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let quality: CGFloat

    public init(quality: CGFloat = 0.7) {
        self.quality = quality
    }

    public func encode(_ imageBuffer: CVImageBuffer) -> Data? {
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        return context.jpegRepresentation(
            of: ciImage,
            colorSpace: colorSpace,
            options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): quality]
        )
    }
}
