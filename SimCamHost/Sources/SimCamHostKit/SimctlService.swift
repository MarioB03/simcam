import Foundation

public struct InstalledApp: Identifiable, Equatable, Sendable {
    public let bundleId: String
    public let name: String
    public var id: String { bundleId }
    public init(bundleId: String, name: String) { self.bundleId = bundleId; self.name = name }
}

public struct SimDevice: Identifiable, Equatable, Sendable {
    public let udid: String
    public let name: String
    public var id: String { udid }
    public init(udid: String, name: String) { self.udid = udid; self.name = name }
}

public enum SimctlError: Error, LocalizedError {
    case command(String)
    public var errorDescription: String? { if case .command(let m) = self { return m }; return nil }
}

public enum SimctlService {
    static let xcrun = "/usr/bin/xcrun"

    /// Parsea la salida (formato plist openStep) de `simctl listapps`, quedándose con las apps de usuario.
    public static func parseListApps(_ output: String) throws -> [InstalledApp] {
        guard let data = output.data(using: .utf8),
              let root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return [] }
        return root.compactMap { _, value -> InstalledApp? in
            guard let dict = value as? [String: Any],
                  let bundleId = dict["CFBundleIdentifier"] as? String,
                  (dict["ApplicationType"] as? String) == "User" else { return nil }
            let name = (dict["CFBundleDisplayName"] as? String) ?? bundleId
            return InstalledApp(bundleId: bundleId, name: name)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public static func launchInjectedCommand(udid: String, bundleId: String, dylib: String) -> (env: [String: String], args: [String]) {
        (["SIMCTL_CHILD_DYLD_INSERT_LIBRARIES": dylib],
         ["simctl", "launch", "--terminate-running-process", udid, bundleId])
    }

    public static func listApps(udid: String) throws -> [InstalledApp] {
        let r = try ProcessRunner.run(xcrun, ["simctl", "listapps", udid], env: nil)
        guard r.ok else { throw SimctlError.command("simctl listapps falló: \(r.stderr)") }
        return try parseListApps(r.stdout)
    }

    public static func listBootedDevices() throws -> [SimDevice] {
        let r = try ProcessRunner.run(xcrun, ["simctl", "list", "devices", "booted", "-j"], env: nil)
        guard r.ok, let data = r.stdout.data(using: .utf8) else { throw SimctlError.command("simctl list falló: \(r.stderr)") }
        struct Root: Decodable { let devices: [String: [Device]] }
        struct Device: Decodable { let udid: String; let name: String; let state: String }
        let root = try JSONDecoder().decode(Root.self, from: data)
        return root.devices.values.flatMap { $0 }
            .filter { $0.state == "Booted" }
            .map { SimDevice(udid: $0.udid, name: $0.name) }
    }

    public static func install(udid: String, appPath: String) throws {
        let r = try ProcessRunner.run(xcrun, ["simctl", "install", udid, appPath], env: nil)
        guard r.ok else { throw SimctlError.command("simctl install falló: \(r.stderr)") }
    }

    public static func terminate(udid: String, bundleId: String) {
        _ = try? ProcessRunner.run(xcrun, ["simctl", "terminate", udid, bundleId], env: nil)
    }

    public static func launchInjected(udid: String, bundleId: String, dylib: String) throws {
        terminate(udid: udid, bundleId: bundleId)
        let cmd = launchInjectedCommand(udid: udid, bundleId: bundleId, dylib: dylib)
        let r = try ProcessRunner.run(xcrun, cmd.args, env: cmd.env)
        guard r.ok else { throw SimctlError.command("simctl launch falló: \(r.stderr)") }
    }
}
