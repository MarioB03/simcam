import ScreenCaptureKit
import CoreVideo
import CoreMedia
import AppKit

/// Captura la región del escritorio que tapa la ventana del Simulador, excluyéndola, y
/// **sigue la ventana**: un temporizador (~10 Hz) relee su posición/tamaño y actualiza el
/// recorte en caliente (`updateConfiguration`), incluido el cambio de monitor
/// (`updateContentFilter`). Así, al mover el Simulador, la cámara enfoca lo que tiene detrás.
public final class ScreenCapturer: NSObject, SCStreamOutput {
    private let target: SimulatorWindow
    private let onFrame: (CVImageBuffer) -> Void
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "simcam.capture")
    private let trackQueue = DispatchQueue(label: "simcam.track")
    private var trackTimer: DispatchSourceTimer?

    // Estado mutado solo en trackQueue.
    private var displays: [SCDisplay] = []
    private var currentDisplayID: CGDirectDisplayID = 0
    private var lastSourceRect: CGRect = .null

    public init(target: SimulatorWindow, onFrame: @escaping (CVImageBuffer) -> Void) {
        self.target = target
        self.onFrame = onFrame
    }

    public func start() async throws {
        let content = try await SCShareableContent.current
        displays = content.displays
        currentDisplayID = target.scDisplay.displayID

        let config = makeConfig(display: target.scDisplay,
                                windowFrame: target.scWindow.frame,
                                scale: target.scaleFactor)
        let filter = SCContentFilter(display: target.scDisplay, excludingWindows: [target.scWindow])
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
        startTracking()
    }

    public func stop() async {
        trackTimer?.cancel()
        trackTimer = nil
        try? await stream?.stopCapture()
        stream = nil
    }

    // MARK: - Config

    private func makeConfig(display: SCDisplay, windowFrame: CGRect, scale: CGFloat) -> SCStreamConfiguration {
        let source = CropGeometry.sourceRect(simulatorFrame: windowFrame, displayFrame: display.frame)
        let size = CropGeometry.pixelSize(sourceRect: source, scaleFactor: scale)
        lastSourceRect = source
        let config = SCStreamConfiguration()
        config.sourceRect = source
        config.width = max(size.width, 2)
        config.height = max(size.height, 2)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: 20) // ~20 fps
        config.queueDepth = 5
        config.showsCursor = false
        return config
    }

    // MARK: - Seguimiento de ventana

    private func startTracking() {
        let timer = DispatchSource.makeTimerSource(queue: trackQueue)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        trackTimer = timer
    }

    private func tick() {
        guard let stream, let bounds = SimulatorWindowFinder.bounds(of: target.id) else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard let display = displays.first(where: { $0.frame.contains(center) })
                ?? displays.first(where: { $0.frame.intersects(bounds) }) else { return }

        let source = CropGeometry.sourceRect(simulatorFrame: bounds, displayFrame: display.frame)
        let displayChanged = display.displayID != currentDisplayID
        let moved = abs(source.minX - lastSourceRect.minX) > 1 || abs(source.minY - lastSourceRect.minY) > 1
            || abs(source.width - lastSourceRect.width) > 1 || abs(source.height - lastSourceRect.height) > 1
        guard displayChanged || moved else { return }

        let config = makeConfig(display: display, windowFrame: bounds, scale: Self.scaleFactor(for: display))
        if displayChanged {
            currentDisplayID = display.displayID
            stream.updateContentFilter(SCContentFilter(display: display, excludingWindows: [target.scWindow]))
        }
        stream.updateConfiguration(config)
    }

    static func scaleFactor(for display: SCDisplay) -> CGFloat {
        NSScreen.screens.first {
            ($0.deviceDescription[.init("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
        }?.backingScaleFactor ?? 2
    }

    // MARK: - SCStreamOutput

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusRaw = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: statusRaw) == .complete,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame(imageBuffer)
    }
}
