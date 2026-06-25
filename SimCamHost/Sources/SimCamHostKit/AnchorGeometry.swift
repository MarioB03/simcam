import CoreGraphics

/// Cálculo puro de dónde colocar la ventana del launcher anclada al Simulador.
///
/// `CGWindowList` da coordenadas con origen arriba-izquierda (Y hacia abajo); `NSWindow`
/// usa origen abajo-izquierda (Y hacia arriba). Esta función hace esa conversión y deja
/// el panel pegado al lado del Simulador, alineado por su borde superior. No toca AppKit
/// ni `NSScreen` (recibe la altura de la pantalla como parámetro) para ser testeable.
public enum AnchorGeometry {
    public enum Side { case right /* , left — futuro */ }

    /// - Parameters:
    ///   - simulatorBoundsCG: bounds del Simulador en coords CoreGraphics (origen
    ///     arriba-izquierda, globales).
    ///   - panelSize: tamaño de la ventana del launcher.
    ///   - side: lado al que anclar (de momento `.right`).
    ///   - gap: separación en puntos entre Simulador y panel.
    ///   - primaryScreenHeight: altura de la pantalla principal, referencia del eje Y global.
    ///   - visibleMaxX: borde derecho útil de la pantalla que contiene al Simulador (clamp).
    /// - Returns: frame del panel en coordenadas AppKit (origen abajo-izquierda).
    public static func panelFrame(
        simulatorBoundsCG: CGRect,
        panelSize: CGSize,
        side: Side = .right,
        gap: CGFloat,
        primaryScreenHeight: CGFloat,
        visibleMaxX: CGFloat
    ) -> CGRect {
        var x: CGFloat
        switch side {
        case .right:
            x = simulatorBoundsCG.maxX + gap
        }
        // Clamp: que el panel no se salga por la derecha de la pantalla.
        if x + panelSize.width > visibleMaxX {
            x = visibleMaxX - panelSize.width
        }
        // CG (top-left) -> AppKit (bottom-left), alineando el borde superior del panel
        // con el del Simulador. Solo depende del top del Simulador, no de su altura.
        let y = primaryScreenHeight - simulatorBoundsCG.minY - panelSize.height
        return CGRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
    }
}
