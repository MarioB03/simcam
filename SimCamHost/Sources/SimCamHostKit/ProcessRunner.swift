import Foundation

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public var ok: Bool { exitCode == 0 }
}

public enum ProcessRunner {
    /// Ejecuta `launchPath args`, esperando a que termine, y captura stdout/stderr.
    /// `env` se fusiona sobre el entorno actual (las claves de `env` ganan).
    ///
    /// Los dos pipes se drenan concurrentemente en colas independientes para evitar
    /// el deadlock cuando el hijo llena el buffer de stderr (~64 KB) mientras stdout
    /// todavía no se ha drenado (p. ej. xcodebuild emitiendo MBs por ambos streams).
    ///
    /// Si se proporciona `onOutput`, se invoca por cada chunk de stdout/stderr según
    /// llega (streaming en vivo). El cierre debe ser `@Sendable` porque se llama desde
    /// colas de fondo.
    public static func run(
        _ launchPath: String,
        _ args: [String],
        env: [String: String]? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) throws -> ProcessResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        if let env {
            proc.environment = ProcessInfo.processInfo.environment.merging(env) { _, new in new }
        }
        let outPipe = Pipe(), errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        // Drenamos stdout y stderr en colas separadas para que ninguno bloquee al otro.
        let group = DispatchGroup()
        let outQueue = DispatchQueue(label: "processrunner.stdout")
        let errQueue = DispatchQueue(label: "processrunner.stderr")
        var outData = Data()
        var errData = Data()

        group.enter()
        outQueue.async {
            let fh = outPipe.fileHandleForReading
            while true {
                let chunk = fh.availableData      // bloquea hasta datos o EOF (vacío = EOF)
                if chunk.isEmpty { break }
                outData.append(chunk)
                if let s = String(data: chunk, encoding: .utf8) { onOutput?(s) }
            }
            group.leave()
        }

        group.enter()
        errQueue.async {
            let fh = errPipe.fileHandleForReading
            while true {
                let chunk = fh.availableData
                if chunk.isEmpty { break }
                errData.append(chunk)
                if let s = String(data: chunk, encoding: .utf8) { onOutput?(s) }
            }
            group.leave()
        }

        try proc.run()
        group.wait()
        proc.waitUntilExit()

        return ProcessResult(
            exitCode: proc.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }
}
