// SimCamHost/Sources/SimCamHostKit/SSEFraming.swift
import Foundation

/// Construcción de la respuesta Server-Sent Events para el canal `/codes`.
public enum SSEFraming {
    public static func httpHeader() -> Data {
        let header = "HTTP/1.0 200 OK\r\n" +
            "Connection: keep-alive\r\n" +
            "Cache-Control: no-store\r\n" +
            "Content-Type: text/event-stream\r\n\r\n"
        return Data(header.utf8)
    }

    public static func event(json: Data) -> Data {
        var data = Data("data: ".utf8)
        data.append(json)
        data.append(Data("\n\n".utf8))
        return data
    }
}
