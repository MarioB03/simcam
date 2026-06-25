import CoreGraphics

/// Cálculo puro del recorte de captura a partir de coordenadas globales.
///
/// ScreenCaptureKit usa `sourceRect` en puntos relativos al origen del display
/// (top-left), y el tamaño de salida en píxeles.
public struct CropGeometry {
    /// Rect de la ventana del simulador en el sistema de coordenadas del display.
    public static func sourceRect(simulatorFrame: CGRect, displayFrame: CGRect) -> CGRect {
        let relative = simulatorFrame.offsetBy(dx: -displayFrame.origin.x, dy: -displayFrame.origin.y)
        let bounds = CGRect(origin: .zero, size: displayFrame.size)
        return relative.intersection(bounds)
    }

    /// Tamaño en píxeles aplicando el `backingScaleFactor` del display.
    public static func pixelSize(sourceRect: CGRect, scaleFactor: CGFloat) -> (width: Int, height: Int) {
        (Int((sourceRect.width * scaleFactor).rounded()),
         Int((sourceRect.height * scaleFactor).rounded()))
    }
}
