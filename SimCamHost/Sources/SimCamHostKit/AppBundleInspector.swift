import Foundation

public enum AppBundleInspectorError: Error, LocalizedError {
    case missingInfoPlist(String), missingBundleId(String)
    public var errorDescription: String? {
        switch self {
        case .missingInfoPlist(let p): return "No se encontró Info.plist en \(p)"
        case .missingBundleId(let p): return "Info.plist sin CFBundleIdentifier en \(p)"
        }
    }
}

public enum AppBundleInspector {
    public static func bundleId(appPath: String) throws -> String {
        let plistURL = URL(fileURLWithPath: appPath).appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL) else { throw AppBundleInspectorError.missingInfoPlist(appPath) }
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = obj as? [String: Any], let id = dict["CFBundleIdentifier"] as? String else {
            throw AppBundleInspectorError.missingBundleId(appPath)
        }
        return id
    }
}
