import SwiftUI
import AppKit

/// Vista invisible que entrega la `NSWindow` que aloja a la `Window` SwiftUI. Es el puente
/// estándar para que el `AnchorController` pueda mover/elevar la ventana real.
struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // En el momento de crear la vista aún no está en la jerarquía; resolvemos al
        // siguiente ciclo, cuando `view.window` ya existe.
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window { onResolve(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window { onResolve(window) }
    }
}
