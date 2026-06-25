import Foundation

/// Contrato de red. DEBE coincidir con `SimCamProtocol` del host `SimCamHost`.
public enum SimCamProtocol {
    public static let host = "127.0.0.1"
    public static let port: UInt16 = 8474
    public static let path = "/stream"
    public static let boundary = "simcamframe"
    public static let codesPath = "/codes"
}
