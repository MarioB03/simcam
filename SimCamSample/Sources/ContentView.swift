import SwiftUI
import CoreVideo
import Vision
import SimCam

struct ContentView: View {
    @State private var session = SimCamSession()
    @State private var detection = "Apunta a una etiqueta…"
    @State private var status = "—"

    var body: some View {
        ZStack(alignment: .bottom) {
            SimCamPreview(session: session)
                .ignoresSafeArea()
            VStack(spacing: 4) {
                Text(detection).font(.headline)
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.6))
            .foregroundStyle(.white)
        }
        .onAppear {
            session.onStatusChange = { s in
                DispatchQueue.main.async { status = "\(s)" }
            }
            session.addFrameObserver { pb in scan(pb) }
            session.start()
        }
        .onDisappear { session.stop() }
    }

    private func scan(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectBarcodesRequest { req, _ in
            guard let obs = (req.results as? [VNBarcodeObservation])?.first,
                  let payload = obs.payloadStringValue else { return }
            DispatchQueue.main.async { detection = "Código: \(payload)" }
        }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up).perform([request])
    }
}
