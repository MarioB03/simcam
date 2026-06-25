// SimCamHost/Tests/SimCamHostKitTests/SSEFramingTests.swift
import XCTest
@testable import SimCamHostKit

final class SSEFramingTests: XCTestCase {
    func test_event_wrapsJSONAsSSEData() {
        let json = Data(#"{"a":1}"#.utf8)
        let event = SSEFraming.event(json: json)
        XCTAssertEqual(String(data: event, encoding: .utf8), "data: {\"a\":1}\n\n")
    }

    func test_header_declaresEventStream() {
        let header = String(data: SSEFraming.httpHeader(), encoding: .utf8)!
        XCTAssertTrue(header.contains("text/event-stream"))
    }

    func test_requestPath_extractsPath() {
        let req = Data("GET /codes HTTP/1.1\r\nHost: x\r\n\r\n".utf8)
        XCTAssertEqual(MJPEGServer.requestPath(from: req), "/codes")
    }
}
