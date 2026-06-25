import XCTest
@testable import SimCamHostKit

final class XcodeBuildServiceTests: XCTestCase {
    func test_parseSchemes_fromWorkspaceJSON() throws {
        let json = Data("""
        { "workspace": { "name": "DemoApp", "schemes": ["DemoApp Dev", "DemoApp Pre"] } }
        """.utf8)
        XCTAssertEqual(try XcodeBuildService.parseSchemes(json), ["DemoApp Dev", "DemoApp Pre"])
    }

    func test_parseSchemes_fromProjectJSON() throws {
        let json = Data("""
        { "project": { "name": "App", "schemes": ["App"], "targets": ["App"], "configurations": ["Debug"] } }
        """.utf8)
        XCTAssertEqual(try XcodeBuildService.parseSchemes(json), ["App"])
    }

    func test_projectFlag_workspaceVsProject() {
        XCTAssertEqual(XcodeBuildService.projectFlag(.workspace("/a/b.xcworkspace")), ["-workspace", "/a/b.xcworkspace"])
        XCTAssertEqual(XcodeBuildService.projectFlag(.project("/a/b.xcodeproj")), ["-project", "/a/b.xcodeproj"])
    }

    func test_buildArguments_includesSdkConfigDestinationDerivedData() {
        let args = XcodeBuildService.buildArguments(.workspace("/w.xcworkspace"), scheme: "S", udid: "U1", derivedData: "/dd")
        XCTAssertEqual(args, [
            "xcodebuild", "build",
            "-workspace", "/w.xcworkspace",
            "-scheme", "S",
            "-sdk", "iphonesimulator",
            "-configuration", "Debug",
            "-destination", "id=U1",
            "-derivedDataPath", "/dd",
        ])
    }
}
