import XCTest
import CoreVideo
@testable import SimCam

private final class FakeSource: CameraSource {
    var onPixelBuffer: ((CVPixelBuffer) -> Void)?
    var onStatus: ((SimCamSession.Status) -> Void)?
    var started = false
    func start() { started = true; onStatus?(.streaming) }
    func stop() { started = false }
    func emit(_ pb: CVPixelBuffer) { onPixelBuffer?(pb) }
}

final class SimCamSessionTests: XCTestCase {
    private func dummyBuffer() -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA, nil, &pb)
        return pb!
    }

    func test_forwardsFramesToOnFrameAndObservers() {
        let source = FakeSource()
        let session = SimCamSession(source: source)
        var viaOnFrame = 0, viaObserver = 0
        session.onFrame = { _ in viaOnFrame += 1 }
        session.addFrameObserver { _ in viaObserver += 1 }
        session.start()
        source.emit(dummyBuffer())
        XCTAssertEqual(viaOnFrame, 1)
        XCTAssertEqual(viaObserver, 1)
        XCTAssertTrue(source.started)
    }

    func test_propagatesStatus() {
        let source = FakeSource()
        let session = SimCamSession(source: source)
        var last: SimCamSession.Status?
        session.onStatusChange = { last = $0 }
        session.start()
        if case .streaming = last { } else { XCTFail("esperaba .streaming, fue \(String(describing: last))") }
    }
}
