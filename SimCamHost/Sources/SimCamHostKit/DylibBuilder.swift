import Foundation

public enum DylibBuilderError: Error, LocalizedError {
    case build(String), notFound(String)
    public var errorDescription: String? {
        switch self {
        case .build(let m): return "Compilación de la dylib falló: \(m)"
        case .notFound(let p): return "No se encontró la dylib tras compilar en \(p)"
        }
    }
}

public enum DylibBuilder {
    static let xcrun = "/usr/bin/xcrun"

    /// Ruta de la dylib EMBEBIDA en el bundle de la app (modo distribuible), o nil si no está.
    /// En la `.app` empaquetada vive en `Contents/Resources/SimCamInject.dylib`; corriendo desde
    /// `swift run` (desarrollo) no existe y se cae al repo. Esto permite compartir la `.app` sin
    /// el repo fuente ni `xcodegen`.
    public static func bundledDylib() -> String? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("SimCamInject.dylib"),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url.path
    }

    static func productsDir(repo: String) -> String {
        "\(repo)/SimCamInject/.build-xcode/Build/Products/Debug-iphonesimulator"
    }

    public static func dylibPath(repo: String) -> String {
        "\(productsDir(repo: repo))/SimCamInject.dylib"
    }

    /// Devuelve la ruta del primer `.dylib` ya compilado, o nil.
    public static func existingDylib(repo: String) -> String? {
        let dir = productsDir(repo: repo)
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        guard let f = entries.first(where: { $0.hasSuffix(".dylib") }) else { return nil }
        return "\(dir)/\(f)"
    }

    /// Devuelve la dylib existente, o la compila (xcodegen + xcodebuild) si falta o `forceRebuild`.
    public static func ensureDylib(repo: String, forceRebuild: Bool) throws -> String {
        // 1. Modo distribuible: dylib embebida en el bundle (no requiere repo ni xcodegen).
        if !forceRebuild, let bundled = bundledDylib() { return bundled }
        // 2. Modo desarrollo: dylib ya compilada en el repo.
        if !forceRebuild, let existing = existingDylib(repo: repo) { return existing }
        // 3. Compilarla desde el repo.
        let injectDir = "\(repo)/SimCamInject"
        // xcodegen (en el directorio del proyecto de la dylib)
        let gen = try ProcessRunner.run("/usr/bin/env", ["sh", "-c", "cd \(shellQuote(injectDir)) && xcodegen"], env: nil)
        guard gen.ok else { throw DylibBuilderError.build("xcodegen: \(gen.stderr)") }
        // xcodebuild de la dylib (slice simulador)
        let build = try ProcessRunner.run(xcrun, [
            "xcodebuild",
            "-project", "\(injectDir)/SimCamInject.xcodeproj",
            "-scheme", "SimCamInject",
            "-sdk", "iphonesimulator",
            "-configuration", "Debug",
            "-destination", "generic/platform=iOS Simulator",
            "-derivedDataPath", "\(injectDir)/.build-xcode",
            "build",
        ], env: nil)
        guard build.ok else { throw DylibBuilderError.build(build.stderr) }
        guard let dylib = existingDylib(repo: repo) else { throw DylibBuilderError.notFound(productsDir(repo: repo)) }
        return dylib
    }

    private static func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}
