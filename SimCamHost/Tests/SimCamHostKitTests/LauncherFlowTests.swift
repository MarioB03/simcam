import XCTest
@testable import SimCamHostKit

final class LauncherFlowTests: XCTestCase {
    func test_fakePipeline_recordsInstalledRelaunch() throws {
        let fake = FakeLaunchPipeline()
        try fake.relaunchInstalled(udid: "U1", bundleId: "com.x.app", repo: "/repo", log: { _ in })
        XCTAssertEqual(fake.relaunches, [FakeLaunchPipeline.Relaunch(udid: "U1", bundleId: "com.x.app", repo: "/repo")])
    }

    func test_fakePipeline_recordsCompileAndLaunch() throws {
        let fake = FakeLaunchPipeline()
        try fake.compileAndLaunch(proj: .workspace("/w.xcworkspace"), scheme: "S", udid: "U1", repo: "/repo", log: { _ in })
        XCTAssertEqual(fake.compiles, [FakeLaunchPipeline.Compile(proj: .workspace("/w.xcworkspace"), scheme: "S", udid: "U1", repo: "/repo")])
    }
}
