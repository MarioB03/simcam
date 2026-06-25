import CoreGraphics
import Foundation

/// Localiza la ventana del Simulador y lee sus bounds vía `CGWindowList`, sin depender de
/// ScreenCaptureKit ni del permiso de Grabación de Pantalla. Las coordenadas son las de
/// CoreGraphics (origen arriba-izquierda, Y hacia abajo, globales).
public enum SimulatorWindowFinder {
    private static let ownerName = "Simulator"

    /// Estado de una ventana: sus bounds y si está visible en pantalla. Una ventana
    /// minimizada al Dock (o en otro Space) deja de estar `onscreen`, pero sigue existiendo.
    public struct WindowState: Equatable {
        public let bounds: CGRect
        public let isOnscreen: Bool
    }

    /// Estado de la ventana con ese id, o `nil` si la ventana ya no existe (cerrada).
    public static func state(of id: CGWindowID) -> WindowState? {
        guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let dict = info.first,
              let b = dict[kCGWindowBounds as String] as? [String: CGFloat],
              let x = b["X"], let y = b["Y"], let w = b["Width"], let h = b["Height"] else { return nil }
        // `kCGWindowIsOnscreen` solo está presente (true) cuando la ventana es visible.
        let onscreen = (dict[kCGWindowIsOnscreen as String] as? Bool) ?? false
        return WindowState(bounds: CGRect(x: x, y: y, width: w, height: h), isOnscreen: onscreen)
    }

    /// Bounds (coords CG) de la ventana con ese id, o `nil` si ya no existe.
    public static func bounds(of id: CGWindowID) -> CGRect? {
        state(of: id)?.bounds
    }

    /// Primer `windowID` on-screen de la app "Simulator" con tamaño de ventana real.
    /// Fallback cuando no hay un Simulador seleccionado explícitamente.
    public static func firstSimulatorWindowID() -> CGWindowID? {
        guard let infos = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for dict in infos {
            guard (dict[kCGWindowOwnerName as String] as? String) == ownerName,
                  let number = (dict[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let b = dict[kCGWindowBounds as String] as? [String: CGFloat],
                  let w = b["Width"], let h = b["Height"],
                  w > 100, h > 100 else { continue }
            return number
        }
        return nil
    }
}
