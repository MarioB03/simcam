import XCTest
@testable import SimCamHostKit

final class AnchorGeometryTests: XCTestCase {
    // Pantalla principal típica 1440x900.

    func test_pegaPanelALaDerecha_alineadoArriba() {
        // Simulador en coords CG (origen arriba-izquierda).
        let sim = CGRect(x: 200, y: 100, width: 390, height: 844)
        let frame = AnchorGeometry.panelFrame(
            simulatorBoundsCG: sim,
            panelSize: CGSize(width: 460, height: 620),
            side: .right,
            gap: 0,
            primaryScreenHeight: 900,
            visibleMaxX: 1440
        )
        // x = borde derecho del simulador; y(AppKit) = 900 - top(100) - alto(620) = 180.
        XCTAssertEqual(frame, CGRect(x: 590, y: 180, width: 460, height: 620))
    }

    func test_aplicaGap() {
        let sim = CGRect(x: 200, y: 100, width: 390, height: 844)
        let frame = AnchorGeometry.panelFrame(
            simulatorBoundsCG: sim,
            panelSize: CGSize(width: 460, height: 620),
            side: .right,
            gap: 8,
            primaryScreenHeight: 900,
            visibleMaxX: 1440
        )
        XCTAssertEqual(frame.origin.x, 598)
    }

    func test_clamp_cuandoNoCabeALaDerecha() {
        // Simulador pegado al borde derecho del monitor.
        let sim = CGRect(x: 1100, y: 50, width: 300, height: 800)
        let frame = AnchorGeometry.panelFrame(
            simulatorBoundsCG: sim,
            panelSize: CGSize(width: 460, height: 620),
            side: .right,
            gap: 0,
            primaryScreenHeight: 900,
            visibleMaxX: 1440
        )
        // 1400 + 460 = 1860 > 1440  ->  x = 1440 - 460 = 980 (se solapa con el simulador).
        XCTAssertEqual(frame.origin.x, 980)
        XCTAssertEqual(frame.origin.y, 230) // 900 - 50 - 620
    }

    func test_alineacionSuperior_noDependeDeLaAlturaDelSimulador() {
        // Dos simuladores con el mismo borde superior pero distinta altura.
        let alto = CGRect(x: 200, y: 100, width: 390, height: 844)
        let bajo = CGRect(x: 200, y: 100, width: 320, height: 400)
        let panel = CGSize(width: 460, height: 620)
        let fAlto = AnchorGeometry.panelFrame(simulatorBoundsCG: alto, panelSize: panel, side: .right, gap: 0, primaryScreenHeight: 900, visibleMaxX: 1440)
        let fBajo = AnchorGeometry.panelFrame(simulatorBoundsCG: bajo, panelSize: panel, side: .right, gap: 0, primaryScreenHeight: 900, visibleMaxX: 1440)
        XCTAssertEqual(fAlto.origin.y, fBajo.origin.y, "El top del panel solo depende del top del Simulador, no de su altura")
    }

    func test_segundoMonitorALaDerecha() {
        // Monitor secundario 1920 de ancho a la derecha del principal (origen global x=1440).
        let sim = CGRect(x: 1600, y: 100, width: 390, height: 844)
        let frame = AnchorGeometry.panelFrame(
            simulatorBoundsCG: sim,
            panelSize: CGSize(width: 460, height: 620),
            side: .right,
            gap: 0,
            primaryScreenHeight: 900,   // la conversión Y usa SIEMPRE la pantalla principal
            visibleMaxX: 1440 + 1920
        )
        XCTAssertEqual(frame, CGRect(x: 1990, y: 180, width: 460, height: 620))
    }
}
