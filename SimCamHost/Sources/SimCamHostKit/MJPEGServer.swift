import Network
import Foundation

/// Servidor multipart/x-mixed-replace mínimo sobre Network.framework.
public final class MJPEGServer {
    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private var clients: [NWConnection] = []      // MJPEG
    private var sseClients: [NWConnection] = []    // SSE /codes
    private let lock = NSLock()

    public init(port: UInt16 = SimCamProtocol.port) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    public func start() throws {
        let params = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: port)
        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.start(queue: .global())
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        lock.lock(); let snap = clients + sseClients; clients.removeAll(); sseClients.removeAll(); lock.unlock()
        snap.forEach { $0.cancel() }
    }

    public static func requestPath(from data: Data) -> String? {
        guard let line = String(data: data, encoding: .ascii)?
            .components(separatedBy: "\r\n").first else { return nil }
        let parts = line.split(separator: " ")
        return parts.count >= 2 ? String(parts[1]) : nil
    }

    private func accept(_ conn: NWConnection) {
        conn.start(queue: .global())
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self else { conn.cancel(); return }
            let path = data.flatMap { Self.requestPath(from: $0) } ?? SimCamProtocol.path
            if path == SimCamProtocol.codesPath {
                conn.send(content: SSEFraming.httpHeader(), completion: .contentProcessed { _ in })
                self.lock.lock(); self.sseClients.append(conn); self.lock.unlock()
            } else {
                conn.send(content: MJPEGFraming.httpHeader(boundary: SimCamProtocol.boundary),
                          completion: .contentProcessed { _ in })
                self.lock.lock(); self.clients.append(conn); self.lock.unlock()
            }
        }
    }

    public func broadcast(jpeg: Data) {
        let part = MJPEGFraming.part(jpeg: jpeg, boundary: SimCamProtocol.boundary)
        lock.lock(); let snapshot = clients; lock.unlock()
        for conn in snapshot {
            conn.send(content: part, completion: .contentProcessed { [weak self] error in
                if error != nil { self?.remove(conn) }
            })
        }
    }

    public func broadcastCode(_ json: Data) {
        let event = SSEFraming.event(json: json)
        lock.lock(); let snapshot = sseClients; lock.unlock()
        for conn in snapshot {
            conn.send(content: event, completion: .contentProcessed { [weak self] error in
                if error != nil { self?.removeSSE(conn) }
            })
        }
    }

    private func remove(_ conn: NWConnection) {
        conn.cancel()
        lock.lock(); clients.removeAll { $0 === conn }; lock.unlock()
    }

    private func removeSSE(_ conn: NWConnection) {
        conn.cancel()
        lock.lock(); sseClients.removeAll { $0 === conn }; lock.unlock()
    }
}
