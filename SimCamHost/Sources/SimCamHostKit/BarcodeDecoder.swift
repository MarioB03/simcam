// SimCamHost/Sources/SimCamHostKit/BarcodeDecoder.swift
import Vision
import CoreVideo
import AVFoundation

public struct DetectedCode: Equatable {
    public let type: String
    public let stringValue: String
}

public enum BarcodeSymbologyMap {
    /// Solo los 6 tipos que la app soporta; nil para el resto.
    public static func avType(for symbology: VNBarcodeSymbology) -> String? {
        switch symbology {
        case .qr:      return AVMetadataObject.ObjectType.qr.rawValue
        case .code128: return AVMetadataObject.ObjectType.code128.rawValue
        case .ean8:    return AVMetadataObject.ObjectType.ean8.rawValue
        case .ean13:   return AVMetadataObject.ObjectType.ean13.rawValue
        case .upce:    return AVMetadataObject.ObjectType.upce.rawValue
        case .code39:  return AVMetadataObject.ObjectType.code39.rawValue
        default:       return nil
        }
    }
}

public struct BarcodeDecoder {
    private let symbologies: [VNBarcodeSymbology] = [.qr, .code128, .ean8, .ean13, .upce, .code39]

    public init() {}

    public func decode(_ buffer: CVPixelBuffer) -> [DetectedCode] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = symbologies
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
        do { try handler.perform([request]) } catch { return [] }
        guard let results = request.results else { return [] }
        return results.compactMap { obs in
            guard let value = obs.payloadStringValue,
                  let type = BarcodeSymbologyMap.avType(for: obs.symbology) else { return nil }
            return DetectedCode(type: type, stringValue: value)
        }
    }
}
