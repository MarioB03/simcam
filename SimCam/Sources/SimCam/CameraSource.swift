import CoreVideo

/// Fuente de frames de cámara (real o simulada). Interna al paquete.
protocol CameraSource: AnyObject {
    var onPixelBuffer: ((CVPixelBuffer) -> Void)? { get set }
    var onStatus: ((SimCamSession.Status) -> Void)? { get set }
    func start()
    func stop()
}
