import AppKit
import Observation
import SimCamHostKit

/// Mantiene la ventana del launcher pegada a la derecha del Simulador, siguiéndolo en
/// tiempo real (estilo RocketSim). Activación automática: si hay Simulador, se ancla y
/// sube a nivel flotante; si no, deja la ventana quieta a nivel normal.
///
/// El seguimiento es por sondeo de `CGWindowList` (~60 Hz), que no requiere permisos TCC.
@MainActor @Observable
public final class AnchorController {
    /// `windowID` del Simulador objetivo (se sincroniza con el Picker). Si es `nil`, se usa
    /// el primer Simulador detectado.
    public var targetID: CGWindowID?

    /// `true` cuando hay un Simulador y el panel está pegado a él (para feedback en la UI).
    public private(set) var isAnchored = false

    private weak var panelWindow: NSWindow?
    private var timer: Timer?
    private var resolvedID: CGWindowID?
    private var lastSimBounds: CGRect = .null
    /// Última visibilidad conocida del Simulador, para detectar transiciones de minimización.
    private var lastOnscreen: Bool?

    private let gap: CGFloat = 0

    public init() {}

    /// Recibe la `NSWindow` del launcher (vía `WindowAccessor`) y arranca el seguimiento.
    /// Idempotente: ignora la misma ventana repetida.
    public func attach(window: NSWindow) {
        guard panelWindow !== window else { return }
        panelWindow = window
        start()
    }

    private func start() {
        timer?.invalidate()
        // .common para seguir disparando aunque el run loop entre en modos de tracking.
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard let window = panelWindow else { return }

        guard let state = resolveSimulatorState() else {
            // Sin Simulador (ventana cerrada): panel libre, nivel normal. No forzamos
            // minimización (no había Simulador al que acompañar).
            if window.level != .normal { window.level = .normal }
            lastSimBounds = .null
            isAnchored = false
            lastOnscreen = nil
            return
        }

        // Reflejar la minimización del Simulador en el panel (solo en las transiciones, para
        // no pelear con una minimización manual del usuario).
        if let prev = lastOnscreen {
            if prev && !state.isOnscreen, !window.isMiniaturized {
                window.miniaturize(nil)              // Simulador -> minimizado
            } else if !prev && state.isOnscreen, window.isMiniaturized {
                window.deminiaturize(nil)            // Simulador -> restaurado
            }
        } else if !state.isOnscreen, !window.isMiniaturized {
            window.miniaturize(nil)                  // primer tick y ya estaba minimizado
        }
        lastOnscreen = state.isOnscreen

        guard state.isOnscreen else {
            // Minimizado (o en otro Space): no movemos el panel ni tocamos su nivel.
            isAnchored = false
            lastSimBounds = .null
            return
        }
        isAnchored = true
        let sim = state.bounds

        // Recolocar solo si el Simulador se movió/redimensionó (umbral ~1 px) y ya estamos
        // flotando; así no machacamos la ventana 60 veces/seg en reposo.
        let unchanged = !lastSimBounds.isNull
            && abs(sim.minX - lastSimBounds.minX) < 1
            && abs(sim.minY - lastSimBounds.minY) < 1
            && abs(sim.width - lastSimBounds.width) < 1
            && abs(sim.height - lastSimBounds.height) < 1
        if unchanged && window.level == .floating { return }
        lastSimBounds = sim

        let primaryHeight = NSScreen.screens.first?.frame.height ?? sim.height
        let visibleMaxX = (screenContaining(sim) ?? NSScreen.main)?.visibleFrame.maxX
            ?? (sim.maxX + window.frame.width)

        let frame = AnchorGeometry.panelFrame(
            simulatorBoundsCG: sim,
            panelSize: window.frame.size,
            side: .right,
            gap: gap,
            primaryScreenHeight: primaryHeight,
            visibleMaxX: visibleMaxX
        )
        if window.level != .floating { window.level = .floating }
        window.setFrame(frame, display: true, animate: false)
    }

    /// Resuelve el estado del Simulador objetivo: primero el id seleccionado/cacheado (que
    /// se conserva aunque esté minimizado); si falla (cerrado), el primer Simulador on-screen.
    private func resolveSimulatorState() -> SimulatorWindowFinder.WindowState? {
        if let id = targetID ?? resolvedID, let s = SimulatorWindowFinder.state(of: id) {
            resolvedID = id
            return s
        }
        if let id = SimulatorWindowFinder.firstSimulatorWindowID(), let s = SimulatorWindowFinder.state(of: id) {
            resolvedID = id
            return s
        }
        resolvedID = nil
        return nil
    }

    /// Pantalla que contiene al Simulador. El eje X coincide entre CG y AppKit (solo Y se
    /// invierte), así que basta comparar por X.
    private func screenContaining(_ simCG: CGRect) -> NSScreen? {
        let midX = simCG.midX
        return NSScreen.screens.first { $0.frame.minX <= midX && midX < $0.frame.maxX }
    }
}
