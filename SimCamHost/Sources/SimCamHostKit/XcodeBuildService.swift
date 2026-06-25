import Foundation

public enum XcodeProject: Equatable, Sendable {
    case workspace(String)
    case project(String)
}

public enum XcodeBuildError: Error, LocalizedError {
    case command(String), appNotFound(String)
    public var errorDescription: String? {
        switch self {
        case .command(let m): return m
        case .appNotFound(let p): return "No se encontró .app en \(p)"
        }
    }
}

public enum XcodeBuildService {
    static let xcrun = "/usr/bin/xcrun"

    public static func projectFlag(_ proj: XcodeProject) -> [String] {
        switch proj {
        case .workspace(let p): return ["-workspace", p]
        case .project(let p): return ["-project", p]
        }
    }

    public static func parseSchemes(_ json: Data) throws -> [String] {
        struct Container: Decodable { let schemes: [String] }
        struct Root: Decodable { let workspace: Container?; let project: Container? }
        let root = try JSONDecoder().decode(Root.self, from: json)
        return root.workspace?.schemes ?? root.project?.schemes ?? []
    }

    public static func buildArguments(_ proj: XcodeProject, scheme: String, udid: String, derivedData: String) -> [String] {
        ["xcodebuild", "build"] + projectFlag(proj) + [
            "-scheme", scheme,
            "-sdk", "iphonesimulator",
            "-configuration", "Debug",
            "-destination", "id=\(udid)",
            "-derivedDataPath", derivedData,
        ]
    }

    public static func listSchemes(_ proj: XcodeProject) throws -> [String] {
        let r = try ProcessRunner.run(xcrun, ["xcodebuild", "-list", "-json"] + projectFlag(proj), env: nil)
        guard r.ok, let data = r.stdout.data(using: .utf8) else { throw XcodeBuildError.command("xcodebuild -list falló: \(r.stderr)") }
        return try parseSchemes(data)
    }

    public static func build(
        _ proj: XcodeProject,
        scheme: String,
        udid: String,
        derivedData: String,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) throws {
        let r = try ProcessRunner.run(
            xcrun,
            buildArguments(proj, scheme: scheme, udid: udid, derivedData: derivedData),
            env: nil,
            onOutput: onOutput
        )
        guard r.ok else { throw XcodeBuildError.command("xcodebuild build falló: \(r.stderr)") }
    }

    /// Localiza el primer `.app` en `<derivedData>/Build/Products/Debug-iphonesimulator`.
    public static func findApp(derivedData: String) throws -> String {
        let dir = "\(derivedData)/Build/Products/Debug-iphonesimulator"
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        guard let app = entries.first(where: { $0.hasSuffix(".app") }) else { throw XcodeBuildError.appNotFound(dir) }
        return "\(dir)/\(app)"
    }
}
