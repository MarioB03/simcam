import XCTest
@testable import SimCamHostKit

final class SimctlServiceTests: XCTestCase {
    func test_parseListApps_keepsOnlyUserAppsWithName() throws {
        let fixture = """
        {
          "com.example.demoapp" =     {
            ApplicationType = User;
            CFBundleDisplayName = "DemoApp";
            CFBundleIdentifier = "com.example.demoapp";
          };
          "com.apple.Maps" =     {
            ApplicationType = System;
            CFBundleDisplayName = "Maps";
            CFBundleIdentifier = "com.apple.Maps";
          };
        }
        """
        let apps = try SimctlService.parseListApps(fixture)
        XCTAssertEqual(apps, [InstalledApp(bundleId: "com.example.demoapp", name: "DemoApp")])
    }

    func test_parseListApps_fallsBackToBundleIdWhenNoDisplayName() throws {
        let fixture = """
        {
          "com.x.app" =     {
            ApplicationType = User;
            CFBundleIdentifier = "com.x.app";
          };
        }
        """
        XCTAssertEqual(try SimctlService.parseListApps(fixture), [InstalledApp(bundleId: "com.x.app", name: "com.x.app")])
    }

    func test_launchInjectedCommand_buildsEnvAndArgs() {
        let cmd = SimctlService.launchInjectedCommand(udid: "UDID-1", bundleId: "com.x.app", dylib: "/tmp/SimCamInject.dylib")
        XCTAssertEqual(cmd.env, ["SIMCTL_CHILD_DYLD_INSERT_LIBRARIES": "/tmp/SimCamInject.dylib"])
        XCTAssertEqual(cmd.args, ["simctl", "launch", "--terminate-running-process", "UDID-1", "com.x.app"])
    }
}
