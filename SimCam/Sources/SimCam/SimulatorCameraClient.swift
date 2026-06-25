import Foundation
import CoreVideo

/// Recibe el MJPEG del host por `localhost` y emite `CVPixelBuffer`. Reintenta si cae.
/// Compila en todas las plataformas (solo Foundation); solo se instancia en simulador+DEBUG.
///
/// `URLSession` descodifica de forma nativa el `multipart/x-mixed-replace`: entrega cada
/// parte como una respuesta independiente (`image/jpeg`) seguida de los bytes crudos de ese
/// JPEG, sin el framing del boundary. Por eso acumulamos los bytes de la parte en curso y la
/// decodificamos cuando llega la respuesta de la siguiente parte (frontera de parte).
final class SimulatorCameraClient: NSObject, CameraSource, URLSessionDataDelegate {
    var onPixelBuffer: ((CVPixelBuffer) -> Void)?
    var onStatus: ((SimCamSession.Status) -> Void)?

    private let decoder = PixelBufferDecoder()
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    private var task: URLSessionDataTask?
    private var stopped = true
    private var partBuffer = Data()

    func start() {
        stopped = false
        connect()
    }

    func stop() {
        stopped = true
        task?.cancel()
        task = nil
        partBuffer.removeAll(keepingCapacity: false)
    }

    private func connect() {
        guard !stopped else { return }
        let url = URL(string: "http://\(SimCamProtocol.host):\(SimCamProtocol.port)\(SimCamProtocol.path)")!
        onStatus?(.connecting)
        partBuffer.removeAll(keepingCapacity: false)
        let task = session.dataTask(with: url)
        self.task = task
        task.resume()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Nueva parte: cierra y decodifica la parte anterior (si la hay).
        flushPart()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        partBuffer.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        partBuffer.removeAll(keepingCapacity: false)
        guard !stopped else { return }
        onStatus?(.failed(error?.localizedDescription ?? "host no conectado"))
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in self?.connect() }
    }

    private func flushPart() {
        guard !partBuffer.isEmpty else { return }
        let jpeg = partBuffer
        partBuffer.removeAll(keepingCapacity: true)
        guard let pixelBuffer = decoder.decode(jpeg) else { return }
        onStatus?(.streaming)
        onPixelBuffer?(pixelBuffer)
    }
}
