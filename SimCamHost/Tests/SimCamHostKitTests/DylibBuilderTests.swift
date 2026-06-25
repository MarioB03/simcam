import XCTest
@testable import SimCamHostKit

final class DylibBuilderTests: XCTestCase {
    func test_existingDylib_findsCompiledArtifact() throws {
        let repo = FileManager.default.temporaryDirectory.appendingPathComponent("repo-\(UUID().uuidString)")
        let products = repo.appendingPathComponent("SimCamInject/.build-xcode/Build/Products/Debug-iphonesimulator")
        try FileManager.default.createDirectory(at: products, withIntermediateDirectories: true)
        let dylib = products.appendingPathComponent("SimCamInject.dylib")
        try Data().write(to: dylib)
        defer { try? FileManager.default.removeItem(at: repo) }

        XCTAssertEqual(DylibBuilder.existingDylib(repo: repo.path), dylib.path)
    }

    func test_existingDylib_nilWhenAbsent() {
        let repo = FileManager.default.temporaryDirectory.appendingPathComponent("repo-\(UUID().uuidString)").path
        XCTAssertNil(DylibBuilder.existingDylib(repo: repo))
    }
}
