import Foundation
import Observation
import SimCamHostKit

@MainActor @Observable
public final class LauncherController {
    public enum Mode: String, CaseIterable { case installed = "App instalada", project = "Proyecto Xcode" }

    public var mode: Mode = .installed
    public var apps: [InstalledApp] = []
    public var selectedBundleId: String?
    public var projectPath: String?          // .xcworkspace / .xcodeproj
    public var schemes: [String] = []
    public var selectedScheme: String?
    public var repoPath: String = NSHomeDirectory() + "/Desarrollo/simcam"
    public private(set) var isWorking = false
    public private(set) var lastError: String?
    public private(set) var log: String = ""
    public func appendLog(_ line: String) { log += line + "\n" }
    public func clearLog() { log = "" }

    private let pipeline: any LaunchPipeline
    public init(pipeline: any LaunchPipeline = RealLaunchPipeline()) { self.pipeline = pipeline }

    private func projectRef() -> XcodeProject? {
        guard let p = projectPath else { return nil }
        return p.hasSuffix(".xcworkspace") ? .workspace(p) : .project(p)
    }

    public func refreshApps(udid: String) {
        Task.detached {
            do {
                let result = try SimctlService.listApps(udid: udid)
                await MainActor.run { [weak self] in
                    self?.apps = result
                    if self?.selectedBundleId == nil { self?.selectedBundleId = result.first?.bundleId }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.apps = []
                }
            }
        }
    }

    public func refreshSchemes() {
        guard let proj = projectRef() else { schemes = []; return }
        Task.detached {
            do {
                let result = try XcodeBuildService.listSchemes(proj)
                await MainActor.run { [weak self] in
                    self?.schemes = result
                    if self?.selectedScheme == nil { self?.selectedScheme = result.first }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.schemes = []
                }
            }
        }
    }

    public func launch(udid: String) {
        isWorking = true; lastError = nil
        clearLog()
        let mode = self.mode, repo = self.repoPath
        let bundleId = self.selectedBundleId, proj = self.projectRef(), scheme = self.selectedScheme
        let pipeline = self.pipeline
        let sink: @Sendable (String) -> Void = { [weak self] line in
            Task { @MainActor in self?.appendLog(line) }
        }
        Task.detached {
            do {
                switch mode {
                case .installed:
                    guard let bundleId else { throw NSError(domain: "SimCam", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sin app seleccionada"]) }
                    try pipeline.relaunchInstalled(udid: udid, bundleId: bundleId, repo: repo, log: sink)
                case .project:
                    guard let proj, let scheme else { throw NSError(domain: "SimCam", code: 2, userInfo: [NSLocalizedDescriptionKey: "Sin proyecto/scheme"]) }
                    try pipeline.compileAndLaunch(proj: proj, scheme: scheme, udid: udid, repo: repo, log: sink)
                }
                await MainActor.run { [weak self] in self?.isWorking = false }
            } catch {
                await MainActor.run { [weak self] in self?.lastError = error.localizedDescription; self?.isWorking = false }
            }
        }
    }
}
