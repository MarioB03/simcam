import Foundation

public protocol LaunchPipeline {
    func relaunchInstalled(udid: String, bundleId: String, repo: String, log: @escaping @Sendable (String) -> Void) throws
    func compileAndLaunch(proj: XcodeProject, scheme: String, udid: String, repo: String, log: @escaping @Sendable (String) -> Void) throws
}

/// Implementación real: encadena dylib → (build) → install → launch inyectado.
public struct RealLaunchPipeline: LaunchPipeline {
    public init() {}

    public func relaunchInstalled(udid: String, bundleId: String, repo: String, log: @escaping @Sendable (String) -> Void) throws {
        log("==> Localizando dylib…\n")
        let dylib = try DylibBuilder.ensureDylib(repo: repo, forceRebuild: false)
        log("==> Dylib: \(dylib)\n")
        log("==> Lanzando \(bundleId)…\n")
        try SimctlService.launchInjected(udid: udid, bundleId: bundleId, dylib: dylib)
    }

    public func compileAndLaunch(proj: XcodeProject, scheme: String, udid: String, repo: String, log: @escaping @Sendable (String) -> Void) throws {
        log("==> Localizando/compilando dylib…\n")
        let dylib = try DylibBuilder.ensureDylib(repo: repo, forceRebuild: false)
        log("==> Dylib: \(dylib)\n")
        // DerivedData en un directorio neutral (no en el repo) para no depender de repoPath:
        // así el modo "Proyecto Xcode" funciona en cualquier máquina con la .app distribuida.
        let derivedData = NSTemporaryDirectory() + "SimCamLauncherBuild"
        log("==> Compilando \(scheme)…\n")
        try XcodeBuildService.build(proj, scheme: scheme, udid: udid, derivedData: derivedData, onOutput: log)
        let app = try XcodeBuildService.findApp(derivedData: derivedData)
        let bundleId = try AppBundleInspector.bundleId(appPath: app)
        log("==> Instalando…\n")
        try SimctlService.install(udid: udid, appPath: app)
        log("==> Lanzando…\n")
        try SimctlService.launchInjected(udid: udid, bundleId: bundleId, dylib: dylib)
    }
}

/// Doble de test: registra las llamadas sin tocar el sistema.
public final class FakeLaunchPipeline: LaunchPipeline {
    public struct Relaunch: Equatable { public let udid, bundleId, repo: String }
    public struct Compile: Equatable { public let proj: XcodeProject; public let scheme, udid, repo: String }
    public private(set) var relaunches: [Relaunch] = []
    public private(set) var compiles: [Compile] = []
    public var errorToThrow: Error?
    public init() {}

    public func relaunchInstalled(udid: String, bundleId: String, repo: String, log: @escaping @Sendable (String) -> Void) throws {
        if let e = errorToThrow { throw e }
        relaunches.append(.init(udid: udid, bundleId: bundleId, repo: repo))
    }
    public func compileAndLaunch(proj: XcodeProject, scheme: String, udid: String, repo: String, log: @escaping @Sendable (String) -> Void) throws {
        if let e = errorToThrow { throw e }
        compiles.append(.init(proj: proj, scheme: scheme, udid: udid, repo: repo))
    }
}
