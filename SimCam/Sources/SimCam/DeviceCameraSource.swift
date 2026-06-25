import CoreVideo

#if !targetEnvironment(simulator) && canImport(AVFoundation)
import AVFoundation

/// Cámara real del dispositivo. Entrega frames BGRA por `onPixelBuffer`.
final class DeviceCameraSource: NSObject, CameraSource, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onPixelBuffer: ((CVPixelBuffer) -> Void)?
    var onStatus: ((SimCamSession.Status) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "simcam.device.camera")

    func start() {
        queue.async { [weak self] in self?.configureAndRun() }
    }

    func stop() {
        queue.async { [weak self] in self?.session.stopRunning() }
    }

    private func configureAndRun() {
        session.beginConfiguration()
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        session.startRunning()
        onStatus?(.streaming)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pb = CMSampleBufferGetImageBuffer(sampleBuffer) { onPixelBuffer?(pb) }
    }
}

#else

/// Stub para simulador/macOS: nunca se usa (en simulador+DEBUG se usa `SimulatorCameraClient`).
final class DeviceCameraSource: CameraSource {
    var onPixelBuffer: ((CVPixelBuffer) -> Void)?
    var onStatus: ((SimCamSession.Status) -> Void)?
    func start() { onStatus?(.failed("Sin cámara en este entorno")) }
    func stop() {}
}

#endif
