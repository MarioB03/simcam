import Foundation

/// Construcción de la respuesta multipart MJPEG (ver `SimCamProtocol`).
public enum MJPEGFraming {
    public static func httpHeader(boundary: String) -> Data {
        let header = "HTTP/1.0 200 OK\r\n" +
            "Connection: close\r\n" +
            "Cache-Control: no-store\r\n" +
            "Content-Type: multipart/x-mixed-replace; boundary=\(boundary)\r\n\r\n"
        return Data(header.utf8)
    }

    public static func part(jpeg: Data, boundary: String) -> Data {
        var data = Data()
        let head = "--\(boundary)\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpeg.count)\r\n\r\n"
        data.append(Data(head.utf8))
        data.append(jpeg)
        data.append(Data([0x0D, 0x0A]))
        return data
    }
}
