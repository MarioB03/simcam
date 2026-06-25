import CoreVideo

/// Cámara unificada: real en dispositivo, stream del host en simulador (DEBUG).
public final class SimCamSession {
    public enum Status: Equatable {
        case idle, connecting, streaming, failed(String)
    }

    public var onFrame: ((CVPixelBuffer) -> Void)?
    public var onStatusChange: ((Status) -> Void)?
    public private(set) var status: Status = .idle

    private let source: CameraSource
    private var observers: [(CVPixelBuffer) -> Void] = []

    /// Inicializador de producción: elige la fuente según el entorno.
    public convenience init() {
        #if DEBUG && targetEnvironment(simulator)
        self.init(source: SimulatorCameraClient())
        #else
        self.init(source: DeviceCameraSource())
        #endif
    }

    /// Inicializador inyectable (tests).
    init(source: CameraSource) {
        self.source = source
        self.source.onPixelBuffer = { [weak self] pb in
            guard let self else { return }
            self.onFrame?(pb)
            self.observers.forEach { $0(pb) }
        }
        self.source.onStatus = { [weak self] status in
            guard let self else { return }
            self.status = status
            self.onStatusChange?(status)
        }
    }

    /// Registra un observador de frames.
    ///
    /// - Importante: Debe llamarse **antes** de `start()`. La sesión entrega frames
    ///   desde un hilo de fondo y `observers` no está sincronizado; registrar observadores
    ///   después de `start()` puede provocar una carrera de datos.
    public func addFrameObserver(_ handler: @escaping (CVPixelBuffer) -> Void) {
        observers.append(handler)
    }

    public func start() { source.start() }
    public func stop() { source.stop() }
}
