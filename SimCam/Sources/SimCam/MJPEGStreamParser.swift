import Foundation

/// Parser incremental de un cuerpo `multipart/x-mixed-replace`.
/// Se alimenta con los bytes del cuerpo (sin cabeceras HTTP) y emite los JPEG completos.
public final class MJPEGStreamParser {
    private let boundaryMarker: Data
    private let headerTerminator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
    private var buffer = Data()

    public init(boundary: String) {
        boundaryMarker = Data("--\(boundary)".utf8)
    }

    public func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var frames: [Data] = []
        while let frame = nextFrame() { frames.append(frame) }
        return frames
    }

    private func nextFrame() -> Data? {
        guard let bRange = buffer.range(of: boundaryMarker) else { return nil }
        guard let hRange = buffer.range(of: headerTerminator, in: bRange.upperBound..<buffer.endIndex) else { return nil }

        let headerSlice = buffer[bRange.upperBound..<hRange.lowerBound]
        guard let length = contentLength(in: headerSlice) else {
            buffer.removeSubrange(buffer.startIndex..<hRange.upperBound) // descarta cabecera corrupta
            return nil
        }

        let bodyStart = hRange.upperBound
        guard let bodyEnd = buffer.index(bodyStart, offsetBy: length, limitedBy: buffer.endIndex),
              bodyEnd <= buffer.endIndex,
              buffer.distance(from: bodyStart, to: buffer.endIndex) >= length else {
            return nil // aún no han llegado todos los bytes del frame
        }

        let frame = Data(buffer[bodyStart..<bodyEnd])
        buffer.removeSubrange(buffer.startIndex..<bodyEnd)
        return frame
    }

    private func contentLength(in header: Data) -> Int? {
        guard let text = String(data: header, encoding: .ascii) else { return nil }
        for line in text.components(separatedBy: "\r\n") where line.lowercased().hasPrefix("content-length:") {
            let value = line.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)
            return Int(value)
        }
        return nil
    }
}
