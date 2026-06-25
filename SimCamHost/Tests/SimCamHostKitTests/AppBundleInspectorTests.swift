import XCTest
@testable import SimCamHostKit

final class AppBundleInspectorTests: XCTestCase {
    func test_bundleId_readsFromInfoPlist() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Fake-\(UUID().uuidString).app")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let plist = "<?xml version=\"1.0\"?><!DOCTYPE plist><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>com.test.fake</string></dict></plist>"
        try plist.write(to: tmp.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertEqual(try AppBundleInspector.bundleId(appPath: tmp.path), "com.test.fake")
    }

    func test_bundleId_throwsWhenInfoPlistMissing() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Fake-\(UUID().uuidString).app")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertThrowsError(try AppBundleInspector.bundleId(appPath: tmp.path))
    }

    func test_bundleId_throwsWhenBundleIdMissing() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Fake-\(UUID().uuidString).app")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let plist = "<?xml version=\"1.0\"?><!DOCTYPE plist><plist version=\"1.0\"><dict><key>SomeOtherKey</key><string>value</string></dict></plist>"
        try plist.write(to: tmp.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertThrowsError(try AppBundleInspector.bundleId(appPath: tmp.path))
    }
}
