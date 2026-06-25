import ScreenCaptureKit
import AppKit

public struct SimulatorWindow: Identifiable {
    public let id: CGWindowID
    public let title: String
    public let scWindow: SCWindow
    public let scDisplay: SCDisplay
    public let scaleFactor: CGFloat
}

public enum SimulatorWindowLocator {
    /// Devuelve las ventanas de la app "Simulator" que están on-screen, con su display y escala.
    public static func current() async throws -> [SimulatorWindow] {
        let content = try await SCShareableContent.current
        let displays = content.displays

        func display(for window: SCWindow) -> SCDisplay? {
            displays.first { $0.frame.intersects(window.frame) } ?? displays.first
        }

        func scale(for display: SCDisplay) -> CGFloat {
            NSScreen.screens.first {
                ($0.deviceDescription[.init("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
            }?.backingScaleFactor ?? 2
        }

        return content.windows.compactMap { window -> SimulatorWindow? in
            guard window.owningApplication?.applicationName == "Simulator",
                  window.isOnScreen,
                  window.frame.width > 100, window.frame.height > 100,
                  let disp = display(for: window) else { return nil }
            return SimulatorWindow(
                id: window.windowID,
                title: window.title ?? "Simulator",
                scWindow: window,
                scDisplay: disp,
                scaleFactor: scale(for: disp)
            )
        }
    }
}
