import Foundation
import AppKit
import SimCamHostKit
import Observation

@MainActor @Observable
public final class CaptureController {
    public enum State: Equatable { case idle, running, error(String) }
    public private(set) var windows: [SimulatorWindow] = []
    public var selectedID: CGWindowID?
    public private(set) var state: State = .idle
    public private(set) var fps: Int = 0
    /// UDID del primer simulador arrancado (limitación MVP: si hay varios simuladores
    /// en ejecución, se usa el primero que devuelve simctl; mapear ventana→UDID de
    /// forma exacta requeriría cruzar el CGWindowID con la info de simctl).
    public private(set) var selectedSimUDID: String?

    private let encoder = JPEGEncoder()
    private let decoder = BarcodeDecoder()
    private var server: MJPEGServer?
    private var capturer: ScreenCapturer?
    private var frameCount = 0
    private var timer: Timer?

    public func refresh() async {
        // El UDID del simulador (que usa el lanzador) NO depende de la captura de pantalla:
        // se resuelve siempre, aunque SCShareableContent falle por permiso de Grabación de Pantalla.
        // Así el lanzador funciona sin necesidad de conceder Grabación de Pantalla.
        selectedSimUDID = (try? SimctlService.listBootedDevices())?.first?.udid
        do {
            windows = try await SimulatorWindowLocator.current()
            if selectedID == nil { selectedID = windows.first?.id }
        } catch { state = .error("\(error)") }
    }

    public func start() async {
        guard let target = windows.first(where: { $0.id == selectedID }) ?? windows.first else {
            state = .error("Sin ventana de Simulador"); return
        }
        do {
            let server = MJPEGServer(); try server.start(); self.server = server
            let encoder = self.encoder
            let decoder = self.decoder
            let capturer = ScreenCapturer(target: target) { [weak self] buffer in
                guard let jpeg = encoder.encode(buffer) else { return }
                server.broadcast(jpeg: jpeg)
                if let code = decoder.decode(buffer).first,
                   let json = try? JSONEncoder().encode(["type": code.type, "stringValue": code.stringValue]) {
                    server.broadcastCode(json)
                }
                Task { @MainActor in self?.frameCount += 1 }
            }
            try await capturer.start(); self.capturer = capturer
            state = .running
            startFPSTimer()
        } catch { state = .error("\(error)") }
    }

    public func stop() async {
        timer?.invalidate(); timer = nil; fps = 0
        await capturer?.stop(); capturer = nil
        server?.stop(); server = nil
        state = .idle
    }

    private func startFPSTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in guard let self else { return }; self.fps = self.frameCount; self.frameCount = 0 }
        }
    }
}
