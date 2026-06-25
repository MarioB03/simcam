import XCTest
@testable import SimCamHostKit

final class CropGeometryTests: XCTestCase {
    func test_sourceRect_isDisplayRelative() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let sim = CGRect(x: 100, y: 50, width: 390, height: 844)
        let rect = CropGeometry.sourceRect(simulatorFrame: sim, displayFrame: display)
        XCTAssertEqual(rect, CGRect(x: 100, y: 50, width: 390, height: 844))
    }

    func test_sourceRect_offsetBySecondDisplayOrigin() {
        let display = CGRect(x: 1440, y: 0, width: 1440, height: 900)
        let sim = CGRect(x: 1540, y: 50, width: 390, height: 844)
        let rect = CropGeometry.sourceRect(simulatorFrame: sim, displayFrame: display)
        XCTAssertEqual(rect, CGRect(x: 100, y: 50, width: 390, height: 844))
    }

    func test_sourceRect_clampsToDisplayBounds() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let sim = CGRect(x: 1300, y: 800, width: 400, height: 400) // se sale por la derecha/abajo
        let rect = CropGeometry.sourceRect(simulatorFrame: sim, displayFrame: display)
        XCTAssertEqual(rect, CGRect(x: 1300, y: 800, width: 140, height: 100))
    }

    func test_pixelSize_appliesScale() {
        let rect = CGRect(x: 0, y: 0, width: 390, height: 844)
        let size = CropGeometry.pixelSize(sourceRect: rect, scaleFactor: 2)
        XCTAssertEqual(size.width, 780)
        XCTAssertEqual(size.height, 1688)
    }
}
