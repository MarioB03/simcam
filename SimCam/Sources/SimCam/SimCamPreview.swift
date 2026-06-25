import CoreVideo

#if canImport(UIKit)
import UIKit
import SwiftUI
import CoreImage

/// Vista UIKit que pinta el último `CVPixelBuffer` recibido.
public final class SimCamPreviewView: UIView {
    private let ciContext = CIContext(options: nil)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        layer.contentsGravity = .resizeAspect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) no soportado") }

    public func render(_ pixelBuffer: CVPixelBuffer) {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return }
        DispatchQueue.main.async { [weak self] in self?.layer.contents = cg }
    }
}

/// Envoltura SwiftUI: se suscribe a los frames de la sesión y los pinta.
public struct SimCamPreview: UIViewRepresentable {
    private let session: SimCamSession

    public init(session: SimCamSession) { self.session = session }

    public func makeUIView(context: Context) -> SimCamPreviewView {
        let view = SimCamPreviewView()
        session.addFrameObserver { [weak view] pb in view?.render(pb) }
        return view
    }

    public func updateUIView(_ uiView: SimCamPreviewView, context: Context) {}
}
#endif
